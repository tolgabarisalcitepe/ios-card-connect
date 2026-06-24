# DOMAIN_MODEL.md — Card Connect Domain Model

## Core Entities

### Contact (domain/model/Contact.kt)

The central entity. Represents a scanned or manually entered business contact.

| Field | Kotlin Type | DB Column | Nullable | Notes |
|-------|-------------|-----------|----------|-------|
| id | String (UUID) | TEXT PK | No | UUID.randomUUID().toString() at creation |
| firstName | String | TEXT | No | Default "". Required for save (UI gate: isBlank check) |
| lastName | String | TEXT | No | Default "" |
| company | String | TEXT | No | Default "" |
| title | String | TEXT | No | Job title / unvan. Default "" |
| phones | List\<String\> | TEXT (JSON array) | No | Up to 3 phones extracted by OCR; normalized (parentheses/dots/dashes removed) |
| emails | List\<String\> | TEXT (JSON array) | No | Lowercased. RFC-compliant from parser |
| address | String | TEXT | No | Single combined address string. Default "" |
| notes | String | TEXT | No | Free-text notes. May contain auto-appended event context |
| eventId | String? | TEXT | Yes | Calendar event ID (string from CalendarContract) |
| eventName | String? | TEXT | Yes | Calendar event display name |
| photoPaths | List\<String\> | TEXT (JSON array) | No | Absolute file paths to photos stored in app internal storage (filesDir/photos/) |
| linkedin | String | TEXT | No | Normalized LinkedIn URL (https://linkedin.com/in/handle). Default "". Added in schema v3 |
| deviceContactId | String? | TEXT | Yes | RawContact ID from ContactsContract (string). Null if not yet synced to phonebook |
| createdAt | Long | INTEGER | No | Unix epoch milliseconds |
| updatedAt | Long | INTEGER | No | Unix epoch milliseconds |

**Computed properties:**
- `fullName: String` → `"$firstName $lastName".trim()`

**Persistence:** JSON serialization of list fields via org.json.JSONArray. No TypeConverters; raw JSON strings in DB.

**Ordering:** getAll() and search() both order by `updatedAt DESC`.

---

### ParsedCard (domain/model/ParsedCard.kt)

Transient data class. Represents OCR or vCard parse output before the user confirms. Never persisted to DB directly.

| Field | Kotlin Type | Notes |
|-------|-------------|-------|
| firstName | String | Default "" |
| lastName | String | Default "" |
| company | String | Default "" |
| title | String | Default "" |
| phones | List\<String\> | Capped at 3 by CardParser |
| emails | List\<String\> | Lowercased |
| address | String | Default "" |
| linkedin | String | Normalized URL or "" |
| notes | String | Default "" (not populated by OCR; user-editable on ConfirmScreen) |

---

### EmailTemplate (domain/model/EmailTemplate.kt)

Represents a reusable email template with Turkish variable tokens.

| Field | Kotlin Type | DB Column | Nullable | Notes |
|-------|-------------|-----------|----------|-------|
| id | String (UUID) | TEXT PK | No | "default_1" through "default_5" for built-ins; UUID for user templates |
| name | String | TEXT | No | Display name shown in template list |
| iconName | String | TEXT | No | One of: "waving_hand", "work", "help", "reply", "calendar_today". Maps to Material Icons |
| subject | String | TEXT | No | Subject line with [Variable] tokens |
| body | String | TEXT | No | Multi-line body with [Variable] tokens |
| isDefault | Boolean (INTEGER 0/1) | INTEGER | No | True for the 5 seeded defaults. Swipe-left resets instead of deletes |
| sortOrder | Int | INTEGER | No | Display order in list |

**Template Variable Tokens (TemplateVars object):**
| Token | Resolves To |
|-------|-------------|
| `[Ad]` | Contact's first name |
| `[Tam Ad]` | Contact's full name (first + last) |
| `[Etkinlik]` | Event name the contact was met at |
| `[Benim Adım]` | User's own full name (from UserProfile) |
| `[Ünvanım]` | User's own title |
| `[Şirketim]` | User's own company |

**Resolution rules:**
- When `[Etkinlik]` is in template but eventName is blank: entire clause/sentence containing the token is stripped from body; token and surrounding dashes stripped from subject
- Missing variable detection: warns user if token is present but value is empty (except [Etkinlik] which is handled silently)

---

### Event (domain/model/Event.kt)

Read-only projection from Android CalendarContract. Never persisted to app DB.

| Field | Kotlin Type | Source |
|-------|-------------|--------|
| id | String | CalendarContract.Events._ID |
| name | String | CalendarContract.Events.TITLE |
| startTime | Long | DTSTART (epoch ms) |
| endTime | Long | DTEND (epoch ms) |
| sourceCalendarId | Long | CALENDAR_ID |

**Computed:** `isActiveAt(timeMs: Long): Boolean` → checks if timeMs falls within startTime..endTime (inclusive).

---

### UserProfile (data/prefs/PreferencesRepository.kt)

Own-contact data for template resolution and QR generation. Stored in EncryptedSharedPreferences, not in Room.

| Field | Pref Key | Notes |
|-------|----------|-------|
| firstName | profile_first_name | Required for QR generation (fullName must be non-empty) |
| lastName | profile_last_name | |
| company | profile_company | Maps to [Şirketim] |
| title | profile_title | Maps to [Ünvanım] |
| phone | profile_phone | Single phone number |
| email | profile_email | Used as ORGANIZER email in .ics |
| linkedin | profile_linkedin | |
| website | profile_website | |
| avatarPath | profile_avatar_path | Absolute path to image in filesDir |
| frontCardPath | profile_front_card | Own business card front photo |
| backCardPath | profile_back_card | Own business card back photo |

**Computed:** `fullName: String` → `"$firstName $lastName".trim()`; `initials: String` → up to 2 uppercase chars from name or "?"

---

## Relationships

```
UserProfile (1) ──── resolves variables in ──── EmailTemplate (many)
UserProfile (1) ──── provides organizer for ──── ICS files

Contact (many) ──── optionally linked to ──── Event (1) [by eventId + eventName]
Contact (1) ──── has many ──── photoPaths (string paths)
Contact (1) ──── optionally mirrored in ──── Device Contacts [by deviceContactId]

ParsedCard ──── transient intermediate ──── Contact (created from ParsedCard at confirm)

EmailTemplate (many) ──── selected in ──── MailComposeScreen (1 at a time)
MailComposeScreen ──── targets ──── Contact (1)
MailComposeScreen ──── optionally attaches ──── IcsGenerator output (1 .ics file)
```

---

## Business Rules and Invariants

### Contact Invariants
1. `id` is never null; assigned at creation; never changes after insert
2. `firstName` must be non-blank to save from edit screen (UI enforces this; DB does not)
3. `phones` list contains at most 3 entries when created from OCR (CardParser enforces `.take(3)`)
4. `emails` are normalized to lowercase by both OCR parser and vCard parsers
5. `photoPaths` point to files inside `filesDir/photos/`; paths become stale if app data is cleared
6. `deviceContactId` is a string representation of the RawContact ID from ContactsContract
7. `updatedAt` must be set to `System.currentTimeMillis()` on every update
8. `eventId` and `eventName` are always set or cleared together (no partial state)
9. When `eventName` is set, an event-context sentence is appended to `notes` ("X etkinliğinde tanıştınız — D Ay Y")
10. Photos are deleted from disk when a contact is deleted (ContactsViewModel.delete)
11. The corresponding .ics file (`filesDir/ics/invite_{id}.ics`) is also deleted on contact delete

### Duplicate Detection Rules (LocalContactRepository.findDuplicate)
Evaluated in order; first match wins:
1. `firstName` AND `lastName` AND `company` all match (requires all three non-empty)
2. Any phone in the incoming card matches any phone in an existing contact (exact JSON string match via LIKE)
3. Any email in the incoming card (lowercased) matches any email in an existing contact

The newly-saved contact itself is excluded from duplicate results.

### Merge Rules (DuplicateViewModel.mergeIntoExisting)
- firstName, lastName, company, title, address, linkedin: new value wins if non-empty; existing value kept otherwise
- phones: new list wins if non-empty; existing list kept otherwise
- emails: union of both lists, deduplicated
- photoPaths: union of both lists, deduplicated
- notes: both concatenated with `\n`, distinct entries, duplicate lines removed
- updatedAt: set to current time
- The newly-saved contact is deleted after merge; existing contact updated

### EmailTemplate Invariants
1. Default templates (isDefault=true) are reset to original content on swipe; not deleted
2. Custom templates are permanently deleted on swipe
3. Seeds happen once: `seedDefaultsIfEmpty()` checks `COUNT(*) > 0` before inserting
4. sortOrder determines display order; assigned sequentially from 0

### Photo Storage Invariants
1. Photos are stored as JPG files named `{timestamp}.jpg` in `filesDir/photos/`
2. Photo files are NOT backed up to Android Backup (excluded in backup_rules.xml)
3. Camera captures go through `PhotoStorage.newPhotoFile()` to get the destination path
4. Gallery picks are copied from content URI into app-private storage before use
5. Temp files during profile setup go to `cacheDir/profile_temp/`

### vCard Parsing Invariants
- File size limit: 16,384 bytes (domain/vcf/VCardParser)
- Field length limits: general 300 chars, phone 30 chars, email 254 chars
- Line unfolding per RFC 6350 §3.2 (CRLF + whitespace = fold)
- LinkedIn extracted only from URL property containing "linkedin.com"
- When FN is present but N is absent/empty, FN is split on first space

### ICS Generation Invariants
- ORGANIZER line only emitted when organizer email is non-empty and passes `Patterns.EMAIL_ADDRESS` validation
- ATTENDEE line only emitted when contact's first email passes same validation
- Lines folded at 75 octets per RFC 5545 §3.1
- RFC 5545 TEXT escaping applied to SUMMARY, ORGANIZER CN, ATTENDEE CN, DESCRIPTION fields
- UID: `{contact.id}-{startMs}@cardconnect`
- Default meeting: next calendar day at 10:00 local time, 1 hour duration

---

## Validation Rules per Field

### Contact / ParsedCard Fields

| Field | Min | Max | Format | Notes |
|-------|-----|-----|--------|-------|
| firstName | 0 (optional from OCR) | Unconstrained in DB | Text | Required non-blank to save from edit UI |
| lastName | 0 | Unconstrained in DB | Text | Optional |
| company | 0 | Unconstrained in DB | Text | |
| title | 0 | Unconstrained in DB | Text | |
| phone (each) | 7 digits (filter) | 30 chars (vCard), 15 digits (OCR) | Numeric with spaces/dashes | OCR: phone.filter{isDigit()}.length in 7..15; vCard: length <= 30 |
| email (each) | — | 254 chars (RFC 5321) | Must contain @ | Lowercased on insert |
| address | 0 | 300 chars (vCard parser) | Text | |
| linkedin | 0 | Unconstrained in DB | https://linkedin.com/in/... or https://linkedin.com/company/... | URL scheme validated (http/https) before opening |
| notes | 0 | Unconstrained in DB | Text | |

### vCard File Constraints
- File max size: 16,384 bytes
- Any field value: max 300 chars (general), 30 (phone), 254 (email)

### OCR Input Constraints
- Full text capped at 8,192 characters before parsing (`fullText.take(8_192)`)

### UserProfile Fields (no hard length limits in code; EncryptedSharedPreferences)
- email: used as ORGANIZER in ICS; validated against `Patterns.EMAIL_ADDRESS`
- linkedin: normalized to https:// on QR generation if not already prefixed
- website: normalized to https:// on QR generation if not already prefixed

### Template Content
- No length limits enforced in code
- Template variables must exactly match token strings (case-sensitive bracket notation)
