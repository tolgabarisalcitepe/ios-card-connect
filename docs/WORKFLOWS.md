# WORKFLOWS.md — Card Connect User Workflows

## 1. Card Scanning (OCR Flow)

### Entry Points
- FAB (center button) in bottom navigation bar → navigates to Routes.CAMERA
- "Kartvizit Tara" button on HomeScreen hero banner
- "Kartvizit Tara" button on empty ContactsScreen

### Step-by-Step Flow

**CameraScreen:**
1. Camera permission check on launch via `ContextCompat.checkSelfPermission`
2. If not granted: `permLauncher.launch(CAMERA)` immediately in LaunchedEffect
3. If permanently denied: `PermissionRationale` composable shown with deep link to app settings
4. On grant: CameraX `ProcessCameraProvider` bound with `Preview` + `ImageCapture` use cases
5. Mode toggle (Kartvizit / QR Tara) shown at top center
6. Frame overlay rendered (card-shaped aspect ratio 1.6:1 for card mode, 220dp square for QR)
7. Bottom controls: gallery icon (left), shutter button (center, 72dp circle), spacer (right)
8. User taps shutter → `imageCapture.takePicture()` → file saved to `PhotoStorage.newPhotoFile()`
9. On success: `frontPhotoPath` saved, `showBackSideDialog = true`
10. Back-side dialog: "Arka yüzü de var mı?" — two options:
    - "Evet, çek": dialog dismissed, user takes second photo; both paths sent to `vm.storePhotoPaths(listOf(front, back))`
    - "Hayır, devam et": `vm.storePhotoPaths(listOf(front))` → `onPhotosTaken()` → navigate to Routes.CONFIRM

**Alternative — Gallery:**
1. User taps gallery icon → `galleryLauncher.launch("image/*")`
2. URI returned → copied to `PhotoStorage.newPhotoFile()` via ContentResolver
3. `frontPhotoPath` set, `isGalleryFlow = true`, back-side dialog shown
4. If back side also wanted: `galleryBackLauncher.launch("image/*")`

**CameraViewModel:**
- `storePhotoPaths()` writes paths to `container.pendingPhotoPaths` AND to `SavedStateHandle["pendingPaths"]` for process-death recovery
- `storeQrVCard()` writes .vcf path to same locations with `isFromQr = true`

**ConfirmScreen / ConfirmViewModel:**
1. `init` calls `runOcr()` immediately on ViewModel creation
2. Reads `container.pendingPhotoPaths`; falls back to `SavedStateHandle["pendingPaths"]` if empty (process death)
3. Checks if any path ends with `.vcf`: if yes, routes to `VCardParser.parseVCardFile(path)`
4. If image paths: calls `MlKitOcrService.recognizeFromFile()` for each image → suspendCancellableCoroutine wrapping ML Kit Task API
5. Multiple image texts merged: `MlKitOcrService.mergeTexts(*texts.toTypedArray())` — joined with "\n---\n"
6. `CardParser.parseCardText(merged)` produces `ParsedCard`
7. `container.pendingParsedCard = parsed`
8. State → `ConfirmUiState.Ready(card, imagePaths)`
9. User sees editable form pre-filled with parsed data; photo preview at top
10. User edits fields as needed (add/remove phone rows, email rows)
11. Taps "Onayla ve Kaydet":
    - `isSaving = true`
    - If `writeGranted`: immediately calls `vm.saveContact(card, true) { id -> onConfirmed(id) }`
    - If not granted: `onRequestWritePerm(card)` → checks `shouldShowRequestPermissionRationale`
      - Show rationale dialog → user taps "İzin Ver" → permission launcher fired
      - Or directly launch permission without rationale
      - On grant/deny: `vm.saveContact(card, granted) { id -> onConfirmed(id) }`
12. `saveContact()` in ViewModel:
    - Creates `Contact` from `ParsedCard` + pendingPhotoPaths (excluding .vcf files)
    - `container.localContactRepo.insert(contact)` → Room DB
    - `container.prefsRepo.incrementContactSavedCount()`
    - If `writeGranted`: `container.deviceContactsRepo.addContact(...)` → ContentProviderOperation batch to ContactsContract
    - `container.pendingContactId = contact.id`
    - Calls `onSaved(contact.id)`
13. Navigate to `Routes.duplicate(contactId)` — back stack clears Camera
14. `onCleared()` in ConfirmViewModel: if `!saved`, temp photo files are deleted from disk

**Error flow:**
- OCR failure: `ConfirmUiState.Error` shown with "Retry" and "Retake" buttons
- `retry()` resets state to Loading and calls `runOcr()` again

---

## 2. QR Scan (vCard via Camera)

### Flow

1. User taps "QR Tara" tab in CameraScreen
2. CameraX rebinds with `ImageAnalysis` use case (barcode analyser) instead of `ImageCapture`
3. Background executor processes frames via `BarcodeScanning.getClient()`
4. On barcode detected: `qrResult` state set (only first result taken, guard `if qrResult == null`)
5. `LaunchedEffect(qrResult)`:
   - If raw value starts with "BEGIN:VCARD" (case-insensitive): save raw text to `.vcf` file in photos dir, call `vm.storeQrVCard(vcfPath)`, then `onPhotosTaken()`
   - Otherwise: show Snackbar "Bu QR kodu bir kartvizit (vCard) içermiyor"; reset `qrResult`
6. Flow continues same as OCR flow from ConfirmScreen onwards
7. ConfirmScreen detects `.vcf` extension → `VCardParser.parse(vCardText)` (in-memory string parser)
8. QR warning banner shown in EditForm

---

## 3. .vcf File Import (Intent Handling)

### Flow

1. User opens a `.vcf` file from email attachment, files app, etc. → Android fires ACTION_VIEW with MIME text/x-vcard or text/vcard
2. `SplashActivity` intercepts (registered in Manifest with both MIME types)
3. `isVCard = intent.action == ACTION_VIEW && type.contains("vcard")`
4. If vCard:
   - `contentResolver.openInputStream(uri)?.bufferedReader()?.readText()` on IO dispatcher
   - Text stored in `(application as CardConnectApp).container.pendingIncomingVCard`
   - Immediately starts `MainActivity` (no 3-second splash delay)
5. `MainActivity.onCreate()`:
   - Reads `container.pendingIncomingVCard`
   - If non-null and onboarding done:
     - Writes text to `filesDir/vcf/incoming.vcf`
     - Adds path to `container.pendingPhotoPaths`
     - Sets `startDestination = Routes.CONFIRM`
   - NavGraph starts directly at ConfirmScreen
6. ConfirmScreen processes `.vcf` path → `VCardParser.parseVCardFile(path)` (file-based parser with RFC 6350 unfolding)
7. Normal confirm/save flow continues

**Error handling:** If writing to filesDir fails → `startDestination = Routes.HOME`

---

## 4. Contact List View

### Flow

1. User navigates to Contacts tab (bottom nav)
2. `ContactsViewModel` uses `flatMapLatest` on `query` StateFlow (debounced 200ms):
   - Empty query → `repo.getAll()` (ORDER BY updatedAt DESC)
   - Non-empty query → `repo.search(q)` (SQL LIKE on firstName+lastName, company, title, eventName)
3. `contacts` exposed as `StateFlow` via `stateIn(WhileSubscribed(5000))`
4. `ContactsScreen` observes with `collectAsStateWithLifecycle()`

**Search:**
- OutlinedTextField at top; clear button when non-empty
- Debounced 200ms before DB query fires
- Search covers: name composite, company, title, eventName
- No search → empty state with "Scan a card" CTA

**Swipe actions:**
- First-launch swipe hint: first item animates left 60dp then returns (Animatable)
- `SwipeToDismissBox` on each item:
  - Swipe left (EndToStart): red background with delete icon → `contactToDelete` set → AlertDialog shown → `vm.delete(contact)` on confirm
  - Swipe right (StartToEnd):
    - Has LinkedIn → blue (#0077B5) background → open LinkedIn URL (scheme validated)
    - No LinkedIn → darker blue (#1565C0) → `onSendMail(contact.id)`
  - `dismissState.reset()` after action (item snaps back)

**Delete flow (ContactsViewModel.delete):**
- Launches on Dispatchers.IO
- Deletes photo files from disk
- Deletes `.ics` file for contact if present
- `repo.delete(contact)` → Room DB
- If `deviceContactId` non-null: `deviceContactsRepo.deleteContact(id)` → ContentContract delete

---

## 5. Contact Detail View

### Flow

1. Tap any contact in list or home screen → `DetailViewModel.load(contactId)` called in `LaunchedEffect`
2. ViewModel uses `_contactId` StateFlow + `flatMapLatest` → `repo.observeById(id)` → live Room Flow
3. Contact updates (e.g., from edit) propagate automatically
4. `DetailScreen` renders:
   - Header with name, company, title (primaryContainer background)
   - "Rehbere Ekle" button if `deviceContactId == null`
   - Phone list (tap → ACTION_DIAL)
   - Email list (tap → ACTION_SENDTO)
   - Address (tap → geo: URI → maps app)
   - LinkedIn (tap → ACTION_VIEW with scheme validation)
   - Notes
   - Event name badge
   - Photo pager (horizontal swipe, dot indicators if multiple photos)
5. Top bar actions: Share (generates vCard 3.0, FileProvider URI, ACTION_SEND chooser), Edit (navigate to ContactEdit), Send Mail, Delete
6. "Add to phonebook" permission flow: same rationale-dialog pattern, then `DetailViewModel.addToDeviceContacts()`
7. Snackbar messages from ViewModel (save success/failure, already in phonebook, etc.)
8. Delete confirmation dialog → `vm.deleteContact(contact, onBack)` → Room delete + optional phonebook delete → navigate back

---

## 6. Contact Edit

### Flow

1. `ContactEditViewModel.load(contactId)` → `repo.getById(contactId)` (one-shot, not observed)
2. Form pre-filled from loaded contact; each field in local Compose `remember` state
3. "Ad" field validates non-blank (isError + canSave gate)
4. Dynamic phone/email rows work same as ConfirmScreen
5. Tap "Kaydet" in top bar → `vm.save(draft.copy(...))`:
   - `repo.update(draft.copy(updatedAt = now))`
   - If `deviceContactId != null` and WRITE_CONTACTS granted (checked silently from ContextCompat) → `deviceContactsRepo.updateContact()` (delete-then-reinsert all managed MIME types)
   - Emits `saveResult: SharedFlow<Boolean>` → `true` → `onBack()`
   - On exception: emits `false` → Snackbar "Kaydedilemedi"

---

## 7. Mail Compose with Templates

### Flow

**Entry via contact:**
1. Navigate to `Routes.mailCompose(contactId)`
2. `MailComposeViewModel.loadContact(contactId)` → one-shot `repo.getById(contactId)`
3. Screen renders with pre-selected recipient

**Entry via "Mail Gönder" tab (no contact):**
1. Navigate to `Routes.MAIL_SEND`
2. `contactId = null` → `ContactPickerScreen` shown
3. User taps contact → `vm.selectContact(contact)` → main compose form shown

**Template selection:**
1. Templates loaded from Room via Flow → `stateIn`
2. FilterChip row (horizontal scroll); tap to select/deselect
3. `LaunchedEffect(selectedTemplate, contact)`:
   - Calls `resolveTemplate(tmpl.subject, ...)` and `resolveTemplate(tmpl.body, ...)`
   - Sets `subject` and `body` state vars
   - Calls `findMissingVars(...)` → warning banner populated

**Meeting invitation:**
1. Toggle switch "Toplantı Daveti Ekle"
2. If READ_CALENDAR not granted: launches permission request (with rationale dialog if applicable)
3. On enable: date picker then time picker dialogs appear
4. `LaunchedEffect(meetingStartMs)` → `vm.loadCalendarEvents(dayStart, dayEnd)` → reads calendar on IO dispatcher
5. Conflicting events shown in red warning card
6. That day's events listed in grey

**Send:**
1. Taps "Gönder" button
2. If `includeMeeting`: `IcsGenerator.generate(context, contact, organizer, startMs, endMs, body)` → writes .ics to `filesDir/ics/`, returns FileProvider URI
   - Intent: ACTION_SEND_MULTIPLE, type "message/rfc822", EXTRA_STREAM = arrayListOf(icsUri)
3. Otherwise: Intent ACTION_SEND, type "message/rfc822"
4. `mailLauncher.launch(Intent.createChooser(intent, "Gönder"))`
5. On return from launcher: `vm.onMailIntentReturned()` → logs analytics, emits `mailSentEvent` → Snackbar "Mail gönderildi" → `onBack()`
6. If no mail app: `ActivityNotFoundException` caught → Snackbar "Mail uygulaması bulunamadı"

---

## 8. Calendar Event Matching

### Entry
- Automatically entered after DuplicateScreen resolves (always, not optional)
- Route: `Routes.eventMatch(contactId)`

### Flow

1. `LaunchedEffect(Unit)` checks READ_CALENDAR permission
2. If granted: `vm.loadEvents()`
3. If not granted: checks `shouldShowRequestPermissionRationale`
   - Show rationale dialog first if applicable
   - Otherwise: `calendarPermLauncher.launch(READ_CALENDAR)`
4. On deny: Snackbar "Takvim erişimi reddedildi — etkinlik eşleştirmesi atlandı" → `onDone()`
5. `vm.loadEvents()` on IO dispatcher:
   - Queries `CalendarContract.Events` for today's events (DTSTART in dayStart..dayEnd)
   - Finds first event that `isActiveAt(now)` → `EventMatchUiState.ActiveEvent`
   - No active event but events exist → `EventMatchUiState.TodayEvents`
   - No events → `EventMatchUiState.NoEvents`
6. UI states:
   - **ActiveEvent**: single event card + "Evet, bu etkinlikte tanıştım" button + "Diğer etkinlik" + "Hayır" skip
   - **TodayEvents**: list of event cards, "Daha fazla" pagination, skip button
   - **NoEvents**: "Bugün için takvimde etkinlik bulunamadı" + skip button
7. "Load more": `vm.loadMoreEvents()` → `calendarRepo.getEventsBefore(extraBeforeMs, 20)` in reverse chronological order
8. **Selecting an event:**
   - WRITE_CONTACTS permission checked/requested (same rationale pattern)
   - `vm.selectEvent(contactId, event, writeGranted)`:
     - Updates contact: `eventId`, `eventName`, `notes` (appends "X etkinliğinde tanıştınız — D Ay Y")
     - If writeGranted and `deviceContactId == null`: calls `deviceContactsRepo.addContact()` → stores returned ID back to contact
     - Emits `SaveOutcome(done=true, snackbar=...)`
9. After outcome: triggers in-app review if `contactSavedCount == 1` → then `onDone()` → navigate to HOME (clearing entire back stack)

---

## 9. Duplicate Detection / Merge

### Flow

1. `DuplicateScreen` launched with `contactId` of the newly saved contact
2. `LaunchedEffect(contactId)` → `vm.checkDuplicate(contactId)`:
   - Reads `container.pendingParsedCard` (set during ConfirmViewModel.saveContact)
   - If null → immediately `DuplicateUiState.NoDuplicate`
   - Calls `repo.findDuplicate(parsedCard)`:
     1. Name+company match (findByNameAndCompany SQL)
     2. Phone match for each phone (findByPhoneExact LIKE SQL)
     3. Email match for each email (findByEmailExact LIKE SQL)
   - Excludes newly saved contact from results (id comparison)
   - If found: `DuplicateUiState.Found(existing, newContact)`
   - If not: `DuplicateUiState.NoDuplicate`
3. **NoDuplicate**: `LaunchedEffect(Unit)` calls `onContinue(contactId)` → automatically advances to EventMatch
4. **Found**: diff card shown with field-by-field comparison (only differing/non-empty incoming fields shown)
5. User chooses:
   - "Mevcut kaydı güncelle" → `vm.mergeIntoExisting(existingId, newId)`:
     - Merges fields per merge rules
     - Updates existing in Room
     - Deletes new contact from Room
     - `container.pendingContactId = existingId`
     - `onContinue(existingId)`
   - "Yeni kayıt oluştur" → `vm.keepNew(newId)` → `onContinue(newId)` (no DB operation)

---

## 10. Profile Setup (Own Contact)

### First-Launch Entry
- Onboarding page 3 button "Profili Kur" → `Routes.PROFILE_SETUP`
- (Skip available on any onboarding page)

### Later Entry
- Home screen avatar tap → `Routes.PROFILE` (view/edit existing profile)

### ProfileSetupScreen Flow

1. Draft `UserProfile` initialized from saved profile (or empty defaults)
2. **OCR from own card:**
   - "Ön Yüz" and "Arka Yüz" slot buttons (gallery or camera via dialog)
   - Camera uses FileProvider URI via TakePicture contract; temp files in `cacheDir/profile_temp/`
   - "Bilgilerimi Oku" button appears when frontCardPath non-empty
   - `vm.ocrAndFill(frontPath, backPath) { filled -> draft = filled }`:
     - Runs ML Kit OCR on paths
     - Calls `CardParser.parseCardText(merged)`
     - Merges parsed fields into current draft (only fills if parsed field is non-empty)
   - OcrState: Idle / Loading / Done / Error
3. **Manual entry:** OutlinedTextField rows for all fields
4. **Avatar:** gallery or camera; copied to `filesDir/avatar_setup.jpg`
5. "Profili Kur" → `vm.save(draft)` → `prefs.saveUserProfile(profile)` → EncryptedSharedPreferences
6. `onDone()` → navigate to HOME (popUpTo PROFILE_SETUP inclusive)

---

## 11. Privacy / Settings

### Flow

1. Settings icon in HomeScreen top bar → `Routes.SETTINGS`
2. SettingsScreen shows:
   - "Gizlilik Politikası" → `Routes.PRIVACY_POLICY` (PrivacyPolicyScreen)
   - "KVKK Aydınlatma Metni" → same route
   - "Arkadaşına Öner" → ACTION_SEND intent with Play Store URL text
3. PrivacyPolicyScreen: composable with scrollable policy text

---

## 12. Onboarding / Permissions Flow

### First-Launch Detection
- `MainActivity`: reads `prefsRepo.onboardingDone.first()` in lifecycleScope before setContent
- If false: `startDestination = Routes.ONBOARDING`
- `ready` flag gates NavGraph from rendering until async check completes

### OnboardingScreen Flow
1. HorizontalPager with 3 pages (swipeable + Next button)
2. Page 1: "Kartvizit Tara" feature overview
3. Page 2: "Şablonla Mail Gönder" feature overview
4. Page 3: "Bağlantılarını Yönet" + KVKK/privacy consent checkbox (required before proceeding)
5. "Atla" button on pages 1-2 skips directly (calls `vm.markDone(onDone)` without consent)
6. "Profili Kur" on page 3 requires `privacyAccepted == true`
7. `vm.markDone()`:
   - `prefs.setOnboardingDone()` → sets "onboarding_done" = true
   - `prefs.setPrivacyAccepted()` → sets "privacy_accepted" = true
   - Logs `ONBOARDING_COMPLETED` analytics event
   - `onDone()` → navigate to `Routes.PROFILE_SETUP`

### Permission Patterns (consistent across all screens)
All runtime permission requests follow this pattern:
1. Check with `ContextCompat.checkSelfPermission`
2. If granted: proceed directly
3. If not granted:
   a. Check `shouldShowRequestPermissionRationale(activity, permission)`
   b. If true: show AlertDialog explaining WHY, then on confirm launch the permission request
   c. If false (first time or permanently denied): launch permission request directly
4. On result:
   - Granted: proceed with action
   - Denied: show informational Snackbar and gracefully skip (or show permanent-denial UI with Settings deep link for Camera)

**Camera permission:** permanent denial → Settings deep link button (`Settings.ACTION_APPLICATION_DETAILS_SETTINGS`)
**WRITE_CONTACTS:** graceful skip (contact saved to app DB without phonebook sync)
**READ_CALENDAR:** graceful skip (event matching step skipped entirely)

### Security Check (CardConnectApp.onCreate)
- `SecurityUtils.isRooted() || SecurityUtils.isEmulator()` evaluated only in release builds
- Result stored as `deviceIntegrityFailed` on Application
- If true: non-dismissable AlertDialog shown in MainActivity with "Devam Et" (stay) or "Çıkış" (finish) options
- App continues to function if user chooses "Devam Et"
