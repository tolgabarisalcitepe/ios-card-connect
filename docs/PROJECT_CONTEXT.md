# PROJECT_CONTEXT.md — Card Connect Android App

## App Purpose

Card Connect is a Turkish-language Android application for digitizing physical business cards and managing professional contacts. The core value proposition is scanning a business card with the phone camera, having ML Kit OCR extract the contact information, confirming and optionally correcting the extracted data, and saving it to a local encrypted database — with optional sync to the device phonebook. The app targets Turkish professionals who attend conferences, trade shows, and B2B meetings.

## Target Users

- Turkish-speaking business professionals
- Frequent conference and event attendees
- Anyone who accumulates physical business cards and wants them digitized quickly
- Users who want to send follow-up emails with pre-built Turkish templates immediately after meeting someone

## Full Feature List (as implemented)

### Card Scanning
- Live camera preview (CameraX) with card-shaped frame overlay
- Two-phase capture: front photo, optional back photo ("is there a back side?")
- Gallery image picker as alternative to camera
- ML Kit on-device OCR text recognition (Latin script; no internet required)
- Dual-image merging: front and back OCR text merged with "---" separator before parsing
- Input capped at 8,192 characters before parsing
- CardParser: rule-based field extraction for name, company, title, phone (up to 3), email, address, LinkedIn URL
- Turkish and international business card formats supported
- Turkish company suffixes (A.Ş., Ltd., Tic., San., Şti., etc.) and title keywords (CEO, Müdür, Mühendis, etc.)
- Reverse name format detection (SOYAD Ad)
- Fax and extension number exclusion
- Label prefix stripping (Tel:, E-mail:, GSM:, etc.)

### QR Code Scanning
- Toggle between Card and QR scan modes in the same camera screen
- ML Kit barcode scanner (ImageAnalysis pipeline)
- vCard-format QR codes decoded and routed through the same Confirm flow
- Non-vCard QR codes rejected with a Snackbar message

### .vcf File Import
- SplashActivity intercepts ACTION_VIEW intents with MIME types text/x-vcard and text/vcard
- File content read via ContentResolver, stored as pendingIncomingVCard on AppContainer
- MainActivity detects pending vCard and routes directly to ConfirmScreen (skipping camera)
- VCardParser (domain/vcf) handles RFC 6350 line-unfolding, property parsing (FN, N, ORG, TITLE, TEL, EMAIL, ADR, URL/LinkedIn)
- Field length limits: general 300 chars, phone 30 chars, email 254 chars; file limit 16,384 bytes
- Separate VCardParser (domain/vcard) for in-memory vCard strings from QR codes

### Contact Confirm & Edit Screen
- Displays captured photos (front / back tabs)
- Pre-filled editable form: Ad, Soyad, Şirket, Ünvan, Telefon(lar), E-posta(lar), Adres, LinkedIn, Not
- Dynamic phone/email rows: add and remove rows
- QR source warning banner shown when data came from a QR scan
- "Yeniden Çek" (retake) button returns to camera
- WRITE_CONTACTS permission requested here with rationale dialog before saving
- Saves to Room DB (local) + optionally to device Contacts

### Duplicate Detection & Merge
- After save, DuplicateViewModel checks for existing contacts matching on: (firstName + lastName + company), or phone, or email
- If duplicate found: side-by-side diff view showing changed fields
- Two options: "Update existing record" (merge) or "Create new record"
- Merge strategy: new non-empty fields overwrite existing; emails are union-deduplicated; photoPaths are union-deduplicated; notes are concatenated with newline

### Event Matching
- After duplicate check, EventMatchScreen reads today's calendar events (READ_CALENDAR permission)
- Three states: active event now, multiple today events (list), no events
- "Load more" loads past events in batches of 20
- Selecting an event stores eventId + eventName on the contact and appends event context to notes field
- WRITE_CONTACTS permission requested again here if not already granted
- After first contact saved, Google Play In-App Review is triggered

### Contact List
- Full list with SwipeToDismiss: swipe left → delete (with confirmation dialog), swipe right → open LinkedIn (if present) or compose mail
- Swipe hint animation on first launch (bounces first item left)
- Search bar with 200ms debounce across name, company, title, eventName columns (SQL LIKE query)
- Empty state with "Scan a card" CTA
- Each row shows: initials avatar, full name, company · title, event name badge

### Contact Detail View
- Tappable phone (ACTION_DIAL), email (ACTION_SENDTO), address (geo: URI), LinkedIn (ACTION_VIEW with URL scheme validation)
- Horizontal photo pager (front/back) with dot indicators
- "Add to phonebook" button visible when deviceContactId is null
- Share as .vcf via FileProvider (vCard 3.0 built in-memory, escapes RFC 6350 special chars)
- Edit and Delete actions in top bar
- Observes contact via Flow so live updates propagate

### Contact Edit Screen
- Same form as Confirm; pre-populated from existing contact
- Saves to Room DB; if deviceContactId is set and WRITE_CONTACTS is granted, also updates device phonebook (delete-then-reinsert strategy)
- "Ad" field required (canSave gate)

### Email Templates
- 5 default Turkish templates: Tanışma Sonrası, İş Birliği Teklifi, Bilgi Talebi, Takip Maili, Toplantı Daveti
- Template variables: [Ad], [Tam Ad], [Etkinlik], [Benim Adım], [Ünvanım], [Şirketim]
- Variables rendered as colored chips in list preview using AnnotatedString
- Swipe-to-delete or swipe-to-reset (default templates reset to original content)
- Custom templates can be created
- Templates stored in Room (email_templates table)

### Mail Compose
- Template chip selector (horizontal scroll)
- Template variables resolved against contact data + user profile
- Missing variable warning banner (e.g., warns if [Şirketim] is empty in profile)
- [Etkinlik] token: when event name is blank, the entire clause containing the token is stripped from body; dashes stripped from subject
- "Meeting Invitation" toggle: generates RFC 5545 compliant .ics file via IcsGenerator
- IcsGenerator: line folding at 75 octets, RFC 5545 TEXT escaping, email validation before ORGANIZER/ATTENDEE fields
- Calendar conflict detection: loads same-day events and highlights overlapping events in red
- Date/time picker for meeting time
- Opens system mail app via ACTION_SEND / ACTION_SEND_MULTIPLE intent with FileProvider URI for .ics
- If no contact pre-selected, shows contact picker screen

### User Profile
- Own contact card: firstName, lastName, company, title, phone, email, linkedin, website, avatarPath, frontCardPath, backCardPath
- Profile data used to populate [Benim Adım], [Ünvanım], [Şirketim] template variables
- OCR self-scan: user can photograph their own business card to fill profile fields
- Avatar: gallery or camera
- QR code generation (ZXing): user's profile as vCard 3.0 QR, displayable and shareable
- Stored in EncryptedSharedPreferences (AES256-GCM)

### Onboarding
- 3-page horizontal pager with dot indicators and animated progress dots
- Privacy policy / KVKK consent checkbox required on last page before proceeding
- "Skip" button available on pages 1 and 2
- Accepting consent sets both onboarding_done and privacy_accepted flags

### Settings
- Gizlilik Politikası (Privacy Policy) link → PrivacyPolicyScreen
- KVKK Aydınlatma Metni link
- "Share with a friend" action (Play Store link)

## Tech Stack

| Layer | Technology | Version |
|-------|-----------|---------|
| Language | Kotlin | 2.2.10 |
| UI | Jetpack Compose + Material 3 | BOM 2026.02.01 |
| Navigation | Navigation Compose | 2.9.0 |
| Database | Room + SQLCipher | Room 2.7.1, SQLCipher 4.5.4 |
| Camera | CameraX | 1.4.2 |
| OCR | ML Kit Text Recognition (on-device) | 16.0.1 |
| Barcode | ML Kit Barcode Scanning | 17.3.0 |
| QR generation | ZXing Core | 3.5.3 |
| Image loading | Coil | 2.7.0 |
| Async | Kotlin Coroutines + Flow | 1.10.2 |
| Preferences | EncryptedSharedPreferences (security-crypto) | 1.1.0-alpha06 |
| DI | Manual (AppContainer pattern) | — |
| Architecture | MVVM + Repository + AppContainer | — |
| Security | SQLCipher, EncryptedSharedPreferences, FLAG_SECURE, root/emulator detection | — |
| In-App Review | Google Play Review KTX | 2.0.1 |
| Min SDK | 26 (Android 8.0) | — |
| Target SDK | 37 | — |
| Compile SDK | 37 | — |

## Build & Deployment Notes

- Package name: `com.veilion.cardconnect`
- Version: 1.0 (versionCode 1)
- Release build: minification + resource shrinking enabled (ProGuard)
- Signing: keystore.properties or env vars (STORE_PASSWORD, KEY_PASSWORD)
- Schema export: Room schemas exported to `app/schemas/` (version 3 is current)
- KSP used for Room annotation processing
- Database migrations: v1→v2 (email_templates table), v2→v3 (linkedin column)
- No Firebase, no remote analytics (NoOpAnalyticsService stub present for future swap)
- No internet required (all ML Kit models are on-device)
- Network security config: cleartext traffic blocked globally
- Backup rules: database and photos excluded from Android backup; settings allowed
- FLAG_SECURE set on MainActivity window (prevents screenshots/recents thumbnails)
- Root/emulator detection runs only in release builds
- One-time plaintext-to-SQLCipher migration: on first encrypted open, old plaintext DB is deleted
- FileProvider authorities: `${applicationId}.fileprovider` exposes photos/, ics/, vcf/, and cache-path profile_temp/
- SplashActivity is the launcher Activity (exported=true); MainActivity is not exported
