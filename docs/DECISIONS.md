# DECISIONS.md — Architecture Decisions & Bug Analysis

## Architectural Decisions

### 1. Manual DI via AppContainer (No Hilt/Koin)
- **Decision:** Single `AppContainer` class instantiated in `Application.onCreate()`, held as `lateinit var container` on the Application class. All ViewModels receive it via `(app as CardConnectApp).container`.
- **Rationale:** Reduces dependency on annotation processing frameworks; keeps the project simple; no compile-time DI graph validation needed at this project scale.
- **Consequence:** AppContainer is a god object holding all repositories. Transient scan state (`pendingPhotoPaths`, `pendingParsedCard`, `pendingContactId`, `pendingIncomingVCard`) is stored directly on AppContainer as mutable fields — this is process-scoped mutable shared state, which can produce race conditions in edge cases.
- **Known Risk:** `pendingPhotoPaths` is a `MutableList<String>` on AppContainer mutated from multiple ViewModels. No synchronization. If two coroutines concurrently read and write this list, there is no guarantee of consistency.

### 2. SQLCipher for Database Encryption
- **Decision:** Room database wrapped with `SupportOpenHelperFactory(passphrase)` from `net.zetetic:sqlcipher-android:4.5.4`.
- **Rationale:** Contact data is sensitive personal information; encryption at rest required.
- **Key management:** 32-byte random passphrase generated via `SecureRandom`, stored in `EncryptedSharedPreferences` (AES256-GCM, Android Keystore-backed).
- **Migration path:** On first run after update, a boolean flag `"encrypted"` in a plain `SharedPreferences` ("db_enc_meta") gates one-time deletion of the old plaintext database before the encrypted one is created. This means all existing unencrypted data is **permanently lost** on the migration run.
- **Keystore corruption recovery:** If `MasterKey.Builder` throws (e.g., after device restore with new keystore), the encrypted preferences are wiped and the DB is deleted. Same data loss behavior.
- **Consequence:** No migration of existing user data from plaintext to ciphertext — clean slate only. Acceptable for the initial ship.

### 3. JSON String Columns for List Fields
- **Decision:** `phones`, `emails`, and `photoPaths` are stored as JSON array strings in TEXT columns rather than using Room `TypeConverters` or related tables.
- **Rationale:** Simpler Room entity definitions; avoids join queries.
- **Consequence:** SQL duplicate detection queries use LIKE with embedded quotes: `WHERE phones LIKE '%"' || :phone || '"%'`. This is brittle if phone strings themselves contain double quotes. Also, JSON is parsed via `org.json.JSONArray` in mapping functions — any malformed JSON silently returns an empty list (caught exception).

### 4. MVVM with AndroidViewModel (Not Plain ViewModel)
- **Decision:** All ViewModels extend `AndroidViewModel` to access the `Application` for `AppContainer`.
- **Rationale:** Required because `AppContainer` is attached to the Application.
- **Consequence:** ViewModels are harder to unit test (require Application mock). The standard recommendation is to inject dependencies into ViewModel via factories.

### 5. Compose Navigation with String Routes
- **Decision:** `NavHost` + `NavController` with string route constants in an `object Routes`. Arguments embedded in route strings (e.g., `"duplicate/{contactId}"`).
- **Rationale:** Standard Navigation Compose approach at the time of writing.
- **Consequence:** Type safety is not enforced. Route strings must be manually kept in sync with `navArgument` declarations. A typo in a route string produces a runtime crash, not a compile error.

### 6. EncryptedSharedPreferences for UserProfile
- **Decision:** All user profile data stored in `EncryptedSharedPreferences` (AES256-GCM, AES256-SIV key encryption). Not in Room.
- **Rationale:** Profile is user's own PII (phone, email, name); keeping it separate from contact DB and encrypted separately provides defense in depth. Simpler than adding a profile table to Room.
- **Consequence:** No migration support (SharedPreferences has no schema versioning). Profile data is exposed as a Flow via a `callbackFlow` wrapping `OnSharedPreferenceChangeListener` — this will deliver updates on whatever thread the listener fires on (typically main thread).

### 7. No Firebase / Remote Analytics (NoOp Stub)
- **Decision:** `AnalyticsService` interface with `NoOpAnalyticsService` implementation. Firebase not configured.
- **Rationale:** Privacy-first approach for Turkish market (KVKK compliance). Analytics can be added later by swapping implementation once `google-services.json` is present.
- **Consequence:** No production analytics data currently collected.

### 8. Two Separate VCardParsers
- **Decision:** There are two distinct VCardParser implementations: `domain/vcf/VCardParser.kt` (file-based, RFC 6350 line unfolding) and `domain/vcard/VCardParser.kt` (in-memory string, no line unfolding).
- **Rationale:** The file-based parser was added for .vcf file import (needs RFC 6350 unfolding); the in-memory parser was added earlier for QR code content.
- **Known Issue:** Code duplication; the in-memory parser does NOT handle RFC 6350 folded lines, so multi-line vCard content from QR codes will fail to parse correctly if folded. The file-based parser is strictly more correct.

### 9. Process-State Sharing via AppContainer
- **Decision:** Scan state (pendingPhotoPaths, pendingParsedCard, pendingContactId, pendingIncomingVCard) is stored as mutable fields on `AppContainer` rather than in a ViewModel, NavigationArgs, or a dedicated state holder.
- **Rationale:** Simplifies passing data between Camera→Confirm→Duplicate→EventMatch without repeating database lookups.
- **Consequences:**
  1. Process death mid-flow causes this state to be lost. Partial recovery via `SavedStateHandle` in CameraViewModel and ConfirmViewModel, but DuplicateViewModel and EventMatchViewModel have no SavedStateHandle recovery.
  2. The pendingParsedCard is not cleared after DuplicateViewModel reads it. If the user navigates back and rescans, stale pendingParsedCard could leak from a previous scan into duplicate check.
  3. Not thread-safe.

### 10. FLAG_SECURE on MainActivity
- **Decision:** `window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)` set in `MainActivity.onCreate()`.
- **Rationale:** Prevents the app content from appearing in screenshots, screen recordings, and the recents thumbnail — protects contact data from casual exposure.
- **Consequence:** Users cannot take screenshots of the app (intentional).

### 11. Backup Rules
- **Decision:** Database and photos directory excluded from Android Auto Backup; EncryptedSharedPreferences (settings) are allowed to back up.
- **Rationale:** Contact data is personal; backing it up to Google Drive without explicit user consent is inappropriate under KVKK/GDPR principles.
- **Consequence:** Users who switch devices lose all scanned contacts and photos. Profile data (name, company, etc.) may restore from cloud backup.

---

## Bug Categories Found

### Category 1: Shared Mutable State Race Conditions (Severity: Medium)

**Root cause:** `AppContainer.pendingPhotoPaths` is a `MutableList<String>` (not thread-safe `CopyOnWriteArrayList`, not `ConcurrentLinkedQueue`) accessed from coroutines dispatched on both `Dispatchers.IO` and `Dispatchers.Main`.

**Specific instance in CameraViewModel:**
```kotlin
container.pendingPhotoPaths.clear()
container.pendingPhotoPaths.addAll(paths)
```
These two operations are not atomic. If ConfirmViewModel's `runOcr()` reads `container.pendingPhotoPaths.toList()` between `clear()` and `addAll()`, it sees an empty list and falls back to SavedStateHandle — but SavedStateHandle is also set separately, creating a TOCTOU window.

**Why this happens in Android:** Android ViewModels run coroutines in `viewModelScope` which defaults to `Dispatchers.Main.immediate`, but `Dispatchers.IO` coroutines can race against each other and against the main thread when they mutate shared state.

### Category 2: Stale Pending State (Severity: Low-Medium)

**Root cause:** `container.pendingParsedCard` is set in `ConfirmViewModel.saveContact()` but never cleared. After a full scan→confirm→duplicate→event flow, it retains the last scanned card.

**Scenario:** User scans card A (no duplicate found), then scans card B. If the user navigates back to DuplicateScreen from a deep link or back-press and DuplicateViewModel.checkDuplicate() runs again, it reads the stale card B's parsed data, not the card being checked.

**Why this happens:** Android's back stack does not guarantee ViewModel recreation; the `pendingParsedCard` field on `AppContainer` (which is process-scoped) is never reset.

### Category 3: Process Death Recovery Gaps (Severity: Medium)

**Root cause:** Only CameraViewModel and ConfirmViewModel use `SavedStateHandle` for recovery. `DuplicateViewModel` and `EventMatchViewModel` do not. If the OS kills the process while the user is on DuplicateScreen or EventMatchScreen:
- DuplicateViewModel reads `container.pendingParsedCard` which is null → `NoDuplicate` state, skipping to EventMatch
- EventMatchViewModel reads `container.localContactRepo.getById(contactId)` from Room which works fine since data is persisted, but the contactId itself comes from the route argument which NavController restores from SavedStateHandle — so this actually works, but the event is loaded fresh.

**Net effect:** Process death mid-flow does not crash but silently skips the duplicate check.

### Category 4: URI Injection / Open Redirect via LinkedIn URLs (Severity: Low)

**Root cause:** LinkedIn URLs from OCR'd business cards or vCard files are opened via `Intent(Intent.ACTION_VIEW, uri)` without validation beyond scheme checking.

**Current mitigation in ContactsScreen and DetailScreen:**
```kotlin
val uri = normalized?.let { Uri.parse(it) }
if (uri != null && uri.scheme?.lowercase() in listOf("http", "https")) {
    context.startActivity(Intent(Intent.ACTION_VIEW, uri))
}
```

**Remaining gap:** The `linkedin` field from `CardParser` uses a regex that extracts a handle and rebuilds the URL as `https://linkedin.com/in/{handle}`. However, the in-memory vCard parser (`domain/vcard/VCardParser`) takes the raw URL string and stores it directly, only prepending "https://" if it does not start with "http". A maliciously crafted vCard with `URL:intent://...` would fail the http/https scheme check, so it would not open. But a vCard with `URL:https://evil.com/redirect/linkedin` would pass the scheme check and open the external URL — the only guard is that it must contain "linkedin.com" (checked in the file-based parser only).

**Why this happens:** The file-based VCardParser validates `value.contains("linkedin.com")` before storing, but the in-memory vCard parser only stores the URL value if linkedin field is currently empty — no domain check.

### Category 5: SQL LIKE Injection via Phone/Email Search (Severity: Low)

**Root cause:** The duplicate detection SQL queries use string interpolation inside LIKE patterns:
```sql
WHERE phones LIKE '%"' || :phone || '"%'
```
Room passes `:phone` as a bound parameter, so SQL injection is prevented by Room's parameterized query binding. However, LIKE metacharacters (`%`, `_`) within the phone or email values are NOT escaped before being passed as the bound parameter. A phone string containing `%` would match more records than expected.

**Example:** A phone value of `%` would match every contact (WHERE phones LIKE '%"' || '%' || '"%' = WHERE phones LIKE '%"%%"').

**Why this happens:** Standard LIKE queries in SQLite use `%` and `_` as wildcards in the bound parameter value. Room does not auto-escape them.

### Category 6: Missing Input Sanitization on Free-Text Fields (Severity: Low)

**Root cause:** The `notes`, `address`, `company`, and `title` fields accept arbitrary text with no length limits enforced in the Room entity or in the UI. Very long strings could cause:
- Overflow in OCR text passed to CardParser (mitigated: OCR text capped at 8,192 chars)
- Excessive memory usage if a user pastes a very large text into a notes field
- ICS line generation: `IcsGenerator.foldLine()` handles arbitrarily long lines, but a note of e.g. 1 MB would produce a very large .ics file

**Why this happens:** Trust of user-edited data without server-side validation (offline-only app).

### Category 7: Permission Loop Risk (Severity: Low, Fixed Pattern Present)

**Root cause:** The pattern of checking `shouldShowRequestPermissionRationale()` and then requesting the permission could theoretically loop if poorly implemented. However, the implementation correctly checks the result callback and does NOT re-request automatically on denial. On first-time denial, the user is shown a Snackbar and the action is skipped. Only permanent denial of Camera permission triggers a Settings deep link.

**Remaining gap:** WRITE_CONTACTS permanent denial is handled inconsistently:
- ConfirmScreen: if permanently denied, `writeContactsPermLauncher.launch()` fires (Android returns immediately with DENIED, no dialog shown) — this is the silent path; the app saves to Room without phonebook sync
- EventMatchScreen: same pattern; silent denial handled with Snackbar
- DetailScreen: silent denial handled with Snackbar from `vm.onWritePermDenied()`

None of these show a Settings deep link for WRITE_CONTACTS permanent denial. This is a UX gap — users who permanently denied the permission have no way to re-enable it from within the app.

### Category 8: Thread Safety of EncryptedSharedPreferences (Severity: Low)

**Root cause:** `EncryptedSharedPreferences.edit().apply()` is used for non-critical saves (profile, flags), but `commit()` is used in some database-passphrase paths. The `callbackFlow` wrapping `OnSharedPreferenceChangeListener` does not enforce main thread delivery — the listener callback can fire on any thread, and `trySend()` is called directly from the listener. If the channel is full, events can be silently dropped.

**Why this happens:** `SharedPreferences.OnSharedPreferenceChangeListener` is not thread-safe by contract; Android recommends registering and handling on the main thread, but the code does not enforce this.

### Category 9: Dead Code — Duplicate VCardParser (Severity: Minor)

`domain/vcard/VCardParser` (in-memory) and `domain/vcf/VCardParser` (file-based) are both present. The in-memory one is missing RFC 6350 line-unfolding logic. The file-based one is strictly superior. The in-memory one should be removed and replaced with the file-based one (by first reading file contents into memory, or by extracting a common parsing function).

### Category 10: ICS MIME Type for Meeting Invitations (Severity: Minor)

`MailComposeScreen` sends the .ics file as `EXTRA_STREAM` with `ACTION_SEND_MULTIPLE` and type `"message/rfc822"`. The .ics attachment is not assigned a specific MIME type in the intent — the receiving mail client must infer it from the file extension. Some mail clients may not recognize it. The correct approach is to set the .ics part's MIME type to `text/calendar` in the stream, but `ACTION_SEND_MULTIPLE` does not support per-attachment MIME types in Android's standard intent model.

---

## Security Decisions Summary

| Decision | Implementation | Strength |
|----------|---------------|----------|
| DB encryption | SQLCipher 4.5.4 with 32-byte random key | Strong |
| Key storage | EncryptedSharedPreferences + Android Keystore AES256-GCM | Strong |
| Preferences encryption | EncryptedSharedPreferences (AES256-SIV keys, AES256-GCM values) | Strong |
| No cleartext network | network_security_config.xml: cleartextTrafficPermitted="false" | Strong |
| Screenshot prevention | FLAG_SECURE on MainActivity | Strong |
| Root/emulator detection | File existence checks + Build.TAGS, Build fields | Moderate (bypassable) |
| URL scheme validation | Whitelist http/https before Intent.ACTION_VIEW | Adequate |
| Backup exclusion | Database and photos excluded from Android Backup | Strong |
| FileProvider | All file sharing via FileProvider (no file:// URIs in intents) | Strong |
| SplashActivity exported | Only SplashActivity has exported=true; MainActivity is not | Correct |
| Input size limits | OCR: 8192 chars; vCard: 16384 bytes; phone: 30; email: 254; field: 300 | Adequate |
| ICS escaping | RFC 5545 TEXT escaping + line folding | Strong |
| vCard escaping | RFC 6350 escaping in DetailViewModel.buildVCard() | Strong |
