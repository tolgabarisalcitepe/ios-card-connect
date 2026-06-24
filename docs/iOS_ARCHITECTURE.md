# iOS_ARCHITECTURE.md — Card Connect iOS

> **Scope:** Production-ready iOS architecture for a Turkish-language business card digitisation app.  
> All decisions are grounded in lessons from the Android implementation (see DECISIONS.md).  
> Hand this document to an iOS developer as a complete spec — it contains code snippets for every non-obvious pattern.

---

## Table of Contents

1. [Bug Prevention Matrix](#1-bug-prevention-matrix)
2. [Tech Stack](#2-tech-stack)
3. [Project Structure](#3-project-structure)
4. [Domain Layer](#4-domain-layer)
5. [Data Layer](#5-data-layer)
6. [UI Layer — Screen Map](#6-ui-layer--screen-map)
7. [Security Layer](#7-security-layer)
8. [Navigation Architecture](#8-navigation-architecture)
9. [Permission Handling](#9-permission-handling)
10. [Testing Strategy](#10-testing-strategy)
11. [Anti-Patterns Explicitly Avoided](#11-anti-patterns-explicitly-avoided)

---

## 1. Bug Prevention Matrix

Every bug category from the Android implementation maps to a specific iOS pattern that structurally prevents it.

| Android Bug | Root Cause | iOS Prevention |
|---|---|---|
| **Cat-1: Shared mutable state race** | `MutableList` on `AppContainer` mutated across coroutines | Swift actors — `ScanFlowActor` owns all transient scan state; no external mutation allowed |
| **Cat-2: Stale pending state** | `pendingParsedCard` never cleared after flow completes | Actor state is reset atomically in `ScanFlowActor.reset()` called at flow completion/cancellation |
| **Cat-3: Process death recovery** | `DuplicateViewModel` / `EventMatchVM` had no `SavedStateHandle` | All ViewModels use `@SceneStorage` / `ScenePhase` observation; transient flow state encoded in navigation path |
| **Cat-4: URI injection / open redirect** | In-memory VCardParser stored raw URL without domain check | Single `URLValidator` struct used by both parsers; host must be `linkedin.com` or `www.linkedin.com` |
| **Cat-5: SQL LIKE wildcard injection** | `%` in phone/email matched all rows | SwiftData predicate uses `==` not `LIKE`; duplicate detection uses exact-match `#Predicate` |
| **Cat-6: Missing field length limits** | No `maxLength` in Room entity | `Contact` struct enforces limits in its memberwise init via `@clamped` property wrapper |
| **Cat-7: Permission loop** | `shouldShowRequestPermissionRationale()` pattern re-requests on denial | `PermissionCoordinator` tracks denial count in `UserDefaults`; on second denial routes to `UIApplication.openSettingsURLString` |
| **Cat-8: Thread safety of prefs** | `OnSharedPreferenceChangeListener` fires on any thread | `@AppStorage` / Keychain access wrapped in `MainActor`; no raw callbacks |
| **Cat-9: Duplicate VCardParser** | Two implementations diverge over time | Single `VCardParser` with `ParseSource` enum (`.file(URL)` / `.string(String)`); unfolding always applied |
| **Cat-10: ICS MIME type** | Android can't set per-attachment MIME | `UIActivityViewController` with `ICSActivityItemSource` setting `activityType` MIME correctly via `UTType.calendarEvent` |
| **Dead code / unused permissions** | `READ_CONTACTS` declared but unused | `Info.plist` permission strings only present when the feature using them is compiled in; audited via CI lint rule |
| **Destructive DB migration** | SQLCipher migration deleted all data | SwiftData `ModelConfiguration` with versioned `Schema`; explicit `MigrationStage.custom` with data transformation |
| **String route type unsafety** | Typos in route strings crash at runtime | `NavigationPath` with `Hashable` typed values; no string routes |
| **AppContainer god object** | All dependencies on one mutable singleton | `@Environment` + `DependencyContainer` protocol; each screen only receives what it needs |

---

## 2. Tech Stack

| Concern | Choice | Version / Notes |
|---|---|---|
| Language | Swift | 5.10+ (Swift 6 concurrency strict mode enabled) |
| UI | SwiftUI | iOS 17+ deployment target |
| Persistence | SwiftData | Replaces Core Data for new projects; versioned schema migration |
| Secure storage | Keychain (via `KeychainAccess` wrapper) | DB key, profile PII |
| Settings / flags | `@AppStorage` (UserDefaults) | Non-sensitive flags only (onboarding_done, swipe_hint_shown) |
| Async | Swift Concurrency (`async/await`, `AsyncStream`, actors) | No Combine; actors own all mutable state |
| Navigation | `NavigationStack` + `NavigationPath` | Typed routes, no strings |
| Camera / OCR | `DataScannerViewController` (iOS 16+) for QR; `AVFoundation` + `VisionKit` for card photos | `VNRecognizeTextRequest` replaces ML Kit |
| Contacts | `CNContactStore` + `ContactsUI` framework | `CNSaveRequest` for write |
| Calendar | `EventKit` (`EKEventStore`) | `EKEvent` for calendar matching |
| Mail / ICS | `MFMailComposeViewController` + `UIActivityViewController` | ICS attachment via `UTType.calendarEvent` |
| Image loading | `AsyncImage` (SwiftUI native) | No Kingfisher/SDWebImage needed |
| QR generation | `CoreImage.CIFilter.qrCodeGenerator` | On-device, no dependency |
| Security | `CryptoKit` (AES-GCM), Keychain, `LocalAuthentication` | |
| Jailbreak detection | Custom `JailbreakDetector` | File-existence + dyld checks |
| DI | `@Environment` + protocol-based `DependencyContainer` | No Swinject/Factory |
| Testing | XCTest + Swift Testing framework | Unit + UI tests |
| Linting | SwiftLint | Enforced in CI |

**Why SwiftData over Core Data:**  
SwiftData provides value-type-friendly `@Model` macro, Swift Concurrency integration out of the box (`ModelActor` for background work), and versioned migration via `VersionedSchema`. The Android bugs around Room migration and JSON column handling are structurally prevented by SwiftData's typed relationships.

**Why no Combine:**  
Swift Concurrency (`async/await` + `AsyncStream`) covers every use case previously needing Combine (`StateFlow` → `@Published` + `AsyncStream`). Actors replace `Dispatchers.IO`. This matches the team's modern Swift direction.

---

## 3. Project Structure

```
CardConnect/
├── App/
│   ├── CardConnectApp.swift          # @main, DI container wiring
│   ├── AppDelegate.swift             # Scene lifecycle, FLAG_SECURE equivalent (.allowScreenshot = false)
│   └── DependencyContainer.swift     # Protocol + live implementation
│
├── Domain/
│   ├── Model/
│   │   ├── Contact.swift             # Struct with validation; NOT @Model
│   │   ├── ParsedCard.swift          # Transient scan result
│   │   ├── EmailTemplate.swift       # Value type
│   │   ├── Event.swift               # Calendar event value type
│   │   └── UserProfile.swift         # Value type; stored in Keychain
│   ├── OCR/
│   │   ├── CardParser.swift          # Pure function — parseCardText(_ text: String) -> ParsedCard
│   │   └── VisionOCRService.swift    # Wraps VNRecognizeTextRequest
│   ├── VCard/
│   │   └── VCardParser.swift         # Single parser with ParseSource enum
│   ├── ICS/
│   │   └── ICSGenerator.swift        # RFC 5545, UTType.calendarEvent
│   ├── Duplicate/
│   │   └── DuplicateDetector.swift   # Pure function; no DB dependency
│   └── Validation/
│       ├── FieldLimits.swift         # Constants: maxPhone, maxEmail, maxField, maxVCard
│       └── URLValidator.swift        # linkedin.com domain whitelist
│
├── Data/
│   ├── Persistence/
│   │   ├── Schema/
│   │   │   ├── SchemaV1.swift
│   │   │   └── SchemaV2.swift        # Migration stage defined here
│   │   ├── ContactStore.swift        # @ModelActor; all DB ops
│   │   ├── ContactStoreProtocol.swift
│   │   └── ScanFlowActor.swift       # Swift actor; owns transient scan state
│   ├── Keychain/
│   │   ├── KeychainStore.swift       # Generic CRUD over Security framework
│   │   └── UserProfileStore.swift    # Reads/writes UserProfile via Keychain
│   ├── Contacts/
│   │   └── DeviceContactsService.swift  # CNContactStore wrapper
│   ├── Calendar/
│   │   └── CalendarService.swift     # EKEventStore wrapper
│   └── Photo/
│       └── PhotoStorage.swift        # File I/O to app's Documents/photos/
│
├── UI/
│   ├── Navigation/
│   │   ├── AppRoute.swift            # enum AppRoute: Hashable
│   │   └── RootNavigationView.swift  # NavigationStack<AppRoute>
│   ├── Onboarding/
│   │   └── OnboardingView.swift
│   ├── ProfileSetup/
│   │   └── ProfileSetupView.swift
│   ├── Home/
│   │   ├── HomeView.swift
│   │   └── HomeViewModel.swift
│   ├── Contacts/
│   │   ├── ContactsView.swift
│   │   └── ContactsViewModel.swift
│   ├── Camera/
│   │   ├── CameraView.swift
│   │   ├── CameraViewModel.swift
│   │   └── DataScannerView.swift     # QR mode via DataScannerViewController
│   ├── Confirm/
│   │   ├── ConfirmView.swift
│   │   └── ConfirmViewModel.swift
│   ├── Duplicate/
│   │   ├── DuplicateView.swift
│   │   └── DuplicateViewModel.swift
│   ├── EventMatch/
│   │   ├── EventMatchView.swift
│   │   └── EventMatchViewModel.swift
│   ├── Detail/
│   │   ├── DetailView.swift
│   │   └── DetailViewModel.swift
│   ├── Edit/
│   │   ├── ContactEditView.swift
│   │   └── ContactEditViewModel.swift
│   ├── Templates/
│   │   ├── TemplatesView.swift
│   │   ├── TemplatesViewModel.swift
│   │   ├── TemplateEditView.swift
│   │   └── TemplateEditViewModel.swift
│   ├── Mail/
│   │   ├── MailComposeView.swift
│   │   └── MailComposeViewModel.swift
│   ├── Profile/
│   │   ├── ProfileView.swift
│   │   └── ProfileViewModel.swift
│   ├── Settings/
│   │   ├── SettingsView.swift
│   │   └── PrivacyPolicyView.swift
│   └── Components/
│       ├── InitialsAvatarView.swift
│       ├── PhoneEmailRowView.swift
│       ├── TemplateVariableChipView.swift
│       └── PermissionRationaleSheet.swift
│
├── Security/
│   ├── JailbreakDetector.swift
│   └── ScreenshotProtection.swift
│
└── Tests/
    ├── Unit/
    │   ├── CardParserTests.swift
    │   ├── VCardParserTests.swift
    │   ├── ContactMergeTests.swift
    │   ├── ICSGeneratorTests.swift
    │   ├── URLValidatorTests.swift
    │   └── DuplicateDetectorTests.swift
    └── UI/
        ├── OnboardingUITests.swift
        └── ScanFlowUITests.swift
```

---

## 4. Domain Layer

### 4.1 Contact (Value Type)

```swift
// Domain/Model/Contact.swift
struct Contact: Identifiable, Hashable, Codable {
    let id: UUID
    var firstName:  String
    var lastName:   String
    var company:    String
    var title:      String
    var phones:     [String]       // max 3 entries; each max 30 chars
    var emails:     [String]       // each max 254 chars
    var address:    String         // max 300 chars
    var notes:      String         // max 2000 chars
    var linkedin:   String         // validated https://linkedin.com/in/... or empty
    var eventID:    String?
    var eventName:  String?
    var photoURLs:  [URL]          // file:// URLs in Documents/photos/
    var deviceContactID: String?
    let createdAt:  Date
    var updatedAt:  Date

    var fullName: String { "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces) }

    init(
        id: UUID = UUID(),
        firstName: String = "", lastName: String = "",
        company: String = "", title: String = "",
        phones: [String] = [], emails: [String] = [],
        address: String = "", notes: String = "",
        linkedin: String = "",
        eventID: String? = nil, eventName: String? = nil,
        photoURLs: [URL] = [], deviceContactID: String? = nil,
        createdAt: Date = .now, updatedAt: Date = .now
    ) {
        self.id            = id
        self.firstName     = String(firstName.prefix(FieldLimits.maxNameField))
        self.lastName      = String(lastName.prefix(FieldLimits.maxNameField))
        self.company       = String(company.prefix(FieldLimits.maxField))
        self.title         = String(title.prefix(FieldLimits.maxField))
        self.phones        = Array(phones.map { String($0.prefix(FieldLimits.maxPhone)) }.prefix(3))
        self.emails        = emails.map { String($0.prefix(FieldLimits.maxEmail)) }
        self.address       = String(address.prefix(FieldLimits.maxField))
        self.notes         = String(notes.prefix(FieldLimits.maxNotes))
        self.linkedin      = URLValidator.validateLinkedIn(linkedin) ? linkedin : ""
        self.eventID       = eventID
        self.eventName     = eventName
        self.photoURLs     = photoURLs
        self.deviceContactID = deviceContactID
        self.createdAt     = createdAt
        self.updatedAt     = updatedAt
    }
}
```

### 4.2 ParsedCard (Transient Scan Result)

```swift
// Domain/Model/ParsedCard.swift
struct ParsedCard: Equatable {
    var firstName: String = ""
    var lastName:  String = ""
    var company:   String = ""
    var title:     String = ""
    var phones:    [String] = []
    var emails:    [String] = []
    var address:   String = ""
    var linkedin:  String = ""
    var notes:     String = ""
}
```

### 4.3 Field Limits

```swift
// Domain/Validation/FieldLimits.swift
enum FieldLimits {
    static let maxNameField = 100
    static let maxField     = 300
    static let maxPhone     = 30
    static let maxEmail     = 254
    static let maxNotes     = 2_000
    static let maxVCard     = 16_384   // bytes
    static let maxOCRInput  = 8_192    // characters
}
```

### 4.4 URL Validator

```swift
// Domain/Validation/URLValidator.swift
enum URLValidator {
    static let allowedLinkedInHosts: Set<String> = ["linkedin.com", "www.linkedin.com"]

    static func validateLinkedIn(_ raw: String) -> Bool {
        guard !raw.isEmpty,
              let url = URL(string: raw),
              let host = url.host?.lowercased(),
              allowedLinkedInHosts.contains(host),
              url.scheme == "https"
        else { return false }
        return true
    }

    static func normalizeLinkedIn(_ raw: String) -> String? {
        // Extract /in/<handle> or /company/<handle> from any linkedin.com URL
        let pattern = #"(?:https?://)?(?:www\.)?linkedin\.com/(in|company)/([\w\-]+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: raw, range: NSRange(raw.startIndex..., in: raw))
        else { return nil }
        let type   = String(raw[Range(match.range(at: 1), in: raw)!])
        let handle = String(raw[Range(match.range(at: 2), in: raw)!])
        return "https://linkedin.com/\(type)/\(handle)"
    }
}
```

### 4.5 VCardParser (Single Implementation)

```swift
// Domain/VCard/VCardParser.swift
enum ParseSource {
    case file(URL)
    case string(String)
}

struct VCardParser {
    static func parse(_ source: ParseSource) throws -> ParsedCard {
        let raw: String
        switch source {
        case .file(let url):
            let data = try Data(contentsOf: url)
            guard data.count <= FieldLimits.maxVCard else {
                throw VCardError.tooLarge
            }
            raw = String(decoding: data, as: UTF8.self)
        case .string(let s):
            guard s.utf8.count <= FieldLimits.maxVCard else {
                throw VCardError.tooLarge
            }
            raw = s
        }
        return parseUnfolded(unfold(raw))
    }

    // RFC 6350 §3.2 line unfolding — always applied regardless of source
    private static func unfold(_ text: String) -> [String] {
        var lines: [String] = []
        for raw in text.components(separatedBy: "\n") {
            let trimmed = raw.hasSuffix("\r") ? String(raw.dropLast()) : raw
            if (trimmed.hasPrefix(" ") || trimmed.hasPrefix("\t")), !lines.isEmpty {
                lines[lines.endIndex - 1] += trimmed.dropFirst()
            } else {
                lines.append(trimmed)
            }
        }
        return lines
    }

    private static func parseUnfolded(_ lines: [String]) -> ParsedCard {
        var card = ParsedCard()
        var fnValue = ""
        for line in lines {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let prop  = String(line[..<colon]).uppercased()
            let value = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
            guard !value.isEmpty else { continue }
            let propName = prop.components(separatedBy: ";").first ?? prop
            switch propName {
            case "FN":    fnValue = String(value.prefix(FieldLimits.maxField))
            case "N":
                let parts = value.components(separatedBy: ";")
                card.lastName  = String((parts[safe: 0] ?? "").trimmingCharacters(in: .whitespaces).prefix(FieldLimits.maxNameField))
                card.firstName = String((parts[safe: 1] ?? "").trimmingCharacters(in: .whitespaces).prefix(FieldLimits.maxNameField))
            case "ORG":
                card.company = String((value.components(separatedBy: ";").first ?? value).prefix(FieldLimits.maxField))
            case "TITLE": card.title = String(value.prefix(FieldLimits.maxField))
            case "TEL":
                let phone = value.trimmingCharacters(in: .whitespaces)
                if !phone.isEmpty && phone.count <= FieldLimits.maxPhone {
                    card.phones.append(phone)
                }
            case "EMAIL":
                let email = value.trimmingCharacters(in: .whitespaces).lowercased()
                if !email.isEmpty && email.count <= FieldLimits.maxEmail {
                    card.emails.append(email)
                }
            case "ADR":
                if card.address.isEmpty {
                    let parts = value.components(separatedBy: ";")
                    card.address = [parts[safe:2], parts[safe:3], parts[safe:4], parts[safe:5], parts[safe:6]]
                        .compactMap { $0?.trimmingCharacters(in: .whitespaces) }
                        .filter { !$0.isEmpty }
                        .joined(separator: ", ")
                        .prefix(FieldLimits.maxField)
                        .description
                }
            case "URL":
                if card.linkedin.isEmpty,
                   value.lowercased().contains("linkedin.com"),
                   let normalized = URLValidator.normalizeLinkedIn(value) {
                    card.linkedin = normalized
                }
            default: break
            }
        }
        if card.firstName.isEmpty && card.lastName.isEmpty && !fnValue.isEmpty {
            let parts = fnValue.split(separator: " ", maxSplits: 1)
            card.firstName = String(parts[safe: 0] ?? "")
            card.lastName  = String(parts[safe: 1] ?? "")
        }
        return card
    }
}

enum VCardError: Error { case tooLarge }
```

### 4.6 CardParser (OCR → ParsedCard)

The `CardParser.parseCardText(_ text: String) -> ParsedCard` function is a direct Swift port of the Kotlin implementation with the following changes:

- `NSRegularExpression` replaces Kotlin `Regex`
- All Turkish character handling uses Swift's Unicode-aware `String` methods
- Input clamped at `FieldLimits.maxOCRInput` characters
- Phone cap: 3 per Android rule
- Returns a `ParsedCard` value type (no mutable state)
- Implemented as a `struct CardParser` with `static func parseCardText`

### 4.7 DuplicateDetector (Pure Function)

```swift
// Domain/Duplicate/DuplicateDetector.swift
struct DuplicateDetector {
    /// Returns the first matching Contact from candidates, or nil.
    /// No DB access — caller fetches candidates and passes them in.
    static func findDuplicate(for card: ParsedCard, in contacts: [Contact]) -> Contact? {
        // 1. Exact name + company match
        if !card.firstName.isEmpty && !card.lastName.isEmpty && !card.company.isEmpty {
            if let match = contacts.first(where: {
                $0.firstName.lowercased() == card.firstName.lowercased() &&
                $0.lastName.lowercased()  == card.lastName.lowercased()  &&
                $0.company.lowercased()   == card.company.lowercased()
            }) { return match }
        }
        // 2. Phone exact match
        for phone in card.phones {
            if let match = contacts.first(where: { $0.phones.contains(phone) }) { return match }
        }
        // 3. Email exact match
        for email in card.emails {
            if let match = contacts.first(where: { $0.emails.contains(email.lowercased()) }) { return match }
        }
        return nil
    }

    static func merge(existing: Contact, incoming: Contact) -> Contact {
        let mergedNotes = [existing.notes, incoming.notes]
            .filter { !$0.isEmpty }
            .uniqued()
            .joined(separator: "\n")
        return Contact(
            id:             existing.id,
            firstName:      incoming.firstName.isEmpty  ? existing.firstName  : incoming.firstName,
            lastName:       incoming.lastName.isEmpty   ? existing.lastName   : incoming.lastName,
            company:        incoming.company.isEmpty    ? existing.company    : incoming.company,
            title:          incoming.title.isEmpty      ? existing.title      : incoming.title,
            phones:         incoming.phones.isEmpty     ? existing.phones     : incoming.phones,
            emails:         Array((existing.emails + incoming.emails).uniqued()),
            address:        incoming.address.isEmpty    ? existing.address    : incoming.address,
            notes:          mergedNotes,
            linkedin:       incoming.linkedin.isEmpty   ? existing.linkedin   : incoming.linkedin,
            eventID:        existing.eventID ?? incoming.eventID,
            eventName:      existing.eventName ?? incoming.eventName,
            photoURLs:      Array((existing.photoURLs + incoming.photoURLs).uniqued()),
            deviceContactID: existing.deviceContactID,
            createdAt:      existing.createdAt,
            updatedAt:      .now
        )
    }
}
```

---

## 5. Data Layer

### 5.1 SwiftData Schema & Persistence

```swift
// Data/Persistence/Schema/SchemaV1.swift
enum SchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] = [ContactModel.self, EmailTemplateModel.self]

    @Model final class ContactModel {
        @Attribute(.unique) var id: UUID
        var firstName:  String
        var lastName:   String
        var company:    String
        var title:      String
        var phonesJSON: String          // JSON array; mirrors Android approach for initial port
        var emailsJSON: String
        var address:    String
        var notes:      String
        var linkedin:   String
        var eventID:    String?
        var eventName:  String?
        var photoURLsJSON: String       // JSON array of file paths
        var deviceContactID: String?
        var createdAt:  Date
        var updatedAt:  Date
        // ...
    }
}

// SchemaV2 would move phones/emails to proper @Relationship if needed.
// MigrationStage.custom handles data transformation.
```

```swift
// Data/Persistence/ContactStore.swift
@ModelActor
actor ContactStore: ContactStoreProtocol {
    func insert(_ contact: Contact) throws {
        let model = contact.toModel()
        modelContext.insert(model)
        try modelContext.save()
    }

    func update(_ contact: Contact) throws {
        guard let model = try modelContext.fetch(
            FetchDescriptor<SchemaV1.ContactModel>(
                predicate: #Predicate { $0.id == contact.id }
            )
        ).first else { return }
        model.update(from: contact)
        try modelContext.save()
    }

    func delete(id: UUID) throws {
        guard let model = try modelContext.fetch(
            FetchDescriptor<SchemaV1.ContactModel>(
                predicate: #Predicate { $0.id == id }
            )
        ).first else { return }
        modelContext.delete(model)
        try modelContext.save()
    }

    func fetchAll() throws -> [Contact] {
        let descriptor = FetchDescriptor<SchemaV1.ContactModel>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).map { $0.toDomain() }
    }

    func fetchById(_ id: UUID) throws -> Contact? {
        try modelContext.fetch(
            FetchDescriptor<SchemaV1.ContactModel>(predicate: #Predicate { $0.id == id })
        ).first?.toDomain()
    }

    /// Exact-match search — no LIKE wildcards, no injection risk.
    func findDuplicate(firstName: String, lastName: String, company: String, phones: [String], emails: [String]) throws -> Contact? {
        // Name+company
        if !firstName.isEmpty && !lastName.isEmpty && !company.isEmpty {
            let fn = firstName.lowercased(); let ln = lastName.lowercased(); let co = company.lowercased()
            if let m = try modelContext.fetch(
                FetchDescriptor<SchemaV1.ContactModel>(
                    predicate: #Predicate { $0.firstName.lowercased() == fn && $0.lastName.lowercased() == ln && $0.company.lowercased() == co }
                )
            ).first { return m.toDomain() }
        }
        // Phone / email: fetch all, filter in Swift to avoid LIKE wildcard risk
        let all = try fetchAll()
        for phone in phones {
            if let m = all.first(where: { $0.phones.contains(phone) }) { return m }
        }
        for email in emails {
            if let m = all.first(where: { $0.emails.contains(email.lowercased()) }) { return m }
        }
        return nil
    }

    func search(query: String) throws -> [Contact] {
        let q = query.lowercased()
        let all = try fetchAll()
        return all.filter {
            $0.fullName.lowercased().contains(q) ||
            $0.company.lowercased().contains(q) ||
            $0.title.lowercased().contains(q) ||
            ($0.eventName?.lowercased().contains(q) ?? false)
        }
    }
}
```

### 5.2 ScanFlowActor (Replaces AppContainer Mutable State)

```swift
// Data/Persistence/ScanFlowActor.swift

/// Owns ALL transient state for the Camera → Confirm → Duplicate → EventMatch flow.
/// Swift actor guarantees serial, race-free access.
actor ScanFlowActor {
    private(set) var photoPaths:  [URL]       = []
    private(set) var parsedCard:  ParsedCard? = nil
    private(set) var contactID:   UUID?       = nil
    private(set) var incomingVCard: String?   = nil

    func setPhotoPaths(_ paths: [URL]) {
        photoPaths = paths
    }

    func setParsedCard(_ card: ParsedCard) {
        parsedCard = card
    }

    func setContactID(_ id: UUID) {
        contactID = id
    }

    func setIncomingVCard(_ text: String) {
        incomingVCard = text
    }

    /// Called when the flow completes (success or cancel). Clears all state.
    func reset() {
        photoPaths   = []
        parsedCard   = nil
        contactID    = nil
        incomingVCard = nil
    }
}
```

**Usage in ConfirmViewModel:**
```swift
@MainActor
final class ConfirmViewModel: ObservableObject {
    private let scanFlow: ScanFlowActor  // injected

    func runOCR() async {
        let paths = await scanFlow.photoPaths
        // ...
        let parsed = CardParser.parseCardText(merged)
        await scanFlow.setParsedCard(parsed)
    }
}
```

### 5.3 Keychain — DB Key & UserProfile

```swift
// Data/Keychain/KeychainStore.swift
struct KeychainStore {
    static func save(key: String, data: Data) throws {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String:   data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.saveFailed(status) }
    }

    static func load(key: String) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String:            kSecClassGenericPassword,
            kSecAttrAccount as String:      key,
            kSecReturnData as String:       true,
            kSecMatchLimit as String:       kSecMatchLimitOne,
            kSecAttrAccessible as String:   kSecAttrAccessibleWhenUnlocked
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            throw KeychainError.loadFailed(status)
        }
        return data
    }
}
```

SwiftData encryption key: a 32-byte random key generated on first launch, stored in Keychain. Passed to `ModelConfiguration` via `url` pointing to the encrypted store. SwiftData supports SQLite-level encryption via a custom `NSPersistentStoreCoordinator` option — set `NSSQLitePragmasOption` with `PRAGMA key`.

```swift
// AppContainer setup
let key = try KeychainStore.loadOrCreate(key: "swiftdata.db.key", length: 32)
let config = ModelConfiguration(
    url: dbURL,
    cloudKitDatabase: .none  // no CloudKit — privacy
)
// Pass key via SQLite pragma before container opens:
// SQLite.execute("PRAGMA key = '\(key.hexString)'")
```

### 5.4 UserProfile Storage

UserProfile is stored in Keychain (not UserDefaults) since it contains PII (email, phone). JSON-encoded.

```swift
// Data/Keychain/UserProfileStore.swift
actor UserProfileStore {
    private let keychainKey = "com.cardconnect.userprofile"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    func load() async -> UserProfile {
        guard let data = try? KeychainStore.load(key: keychainKey),
              let profile = try? decoder.decode(UserProfile.self, from: data)
        else { return UserProfile() }
        return profile
    }

    func save(_ profile: UserProfile) async throws {
        let data = try encoder.encode(profile)
        try KeychainStore.save(key: keychainKey, data: data)
    }
}
```

Non-sensitive flags (`onboarding_done`, `privacy_accepted`, `swipe_hint_shown`, `contact_saved_count`) remain in `@AppStorage` (UserDefaults).

---

## 6. UI Layer — Screen Map

### State Management Pattern

Every screen follows this structure:

```swift
@MainActor
final class FooViewModel: ObservableObject {
    @Published private(set) var state: FooState = .loading
    private let dep: SomeDependencyProtocol  // injected via init

    func load() async { ... }
}

enum FooState {
    case loading
    case ready(SomeData)
    case error(String)
}
```

No `AndroidViewModel(app)` pattern. Dependencies injected via `init`, not cast from Application. Protocols make each ViewModel unit-testable without the full dependency graph.

### Screen Inventory

| Screen | State Type | Key Differences from Android |
|---|---|---|
| `OnboardingView` | `TabView` with `PageTabViewStyle` | Same 3-page flow; privacy checkbox gates advance |
| `ProfileSetupView` | `ProfileSetupViewModel` | OCR self-scan uses `VisionOCRService`; profile saved to Keychain actor |
| `HomeView` | `HomeViewModel` | QR sheet uses `CoreImage`; recent contacts from SwiftData stream |
| `ContactsView` | `ContactsViewModel` | List with swipe actions; `searchable` modifier for search |
| `CameraView` | `CameraViewModel` | `AVCaptureSession` for card photos; `DataScannerViewController` for QR |
| `ConfirmView` | `ConfirmViewModel` | `TabView` for photo pager; editable form with dynamic phone/email rows |
| `DuplicateView` | `DuplicateViewModel` | Diff view; merge uses pure `DuplicateDetector.merge()` |
| `EventMatchView` | `EventMatchViewModel` | `EKEventStore` queries; pagination with load-more button |
| `DetailView` | `DetailViewModel` | `AsyncImage` for photos; share sheet via `UIActivityViewController` |
| `ContactEditView` | `ContactEditViewModel` | Same form as Confirm; `CNSaveRequest` for device sync |
| `TemplatesView` | `TemplatesViewModel` | SwiftData list with swipe-to-delete and reset |
| `TemplateEditView` | `TemplateEditViewModel` | `AttributedString` for token chips |
| `MailComposeView` | `MailComposeViewModel` | `MFMailComposeViewController` wrapper; ICS via `UIActivityViewController` |
| `ProfileView` | `ProfileViewModel` | Avatar picker; QR code display |
| `SettingsView` | — (stateless) | Links to PrivacyPolicyView |

### CameraView Detail

```swift
// UI/Camera/CameraView.swift
struct CameraView: View {
    @StateObject private var vm: CameraViewModel
    @State private var mode: CaptureMode = .card

    enum CaptureMode { case card, qr }

    var body: some View {
        ZStack {
            if mode == .card {
                CardCaptureView(onPhotosTaken: vm.storePhotoPaths)
            } else {
                DataScannerRepresentable(onQRDetected: vm.handleQRCode)
            }
            // Overlay: mode toggle, capture button, back button
        }
        .task { await vm.requestCameraPermission() }
    }
}
```

`DataScannerViewController` (iOS 16+) handles QR decoding natively — no ML Kit dependency needed on iOS.

### MailComposeView — ICS Attachment

```swift
// UI/Mail/MailComposeViewModel.swift
func sendWithICS(contact: Contact, template: EmailTemplate, startDate: Date, endDate: Date) async throws {
    let icsURL = try await ICSGenerator.generate(
        contact: contact,
        organizer: userProfile,
        start: startDate,
        end: endDate
    )
    // Share via UIActivityViewController so the ICS is offered to Calendar + Mail
    let item = ICSActivityItemSource(fileURL: icsURL, contact: contact)
    await MainActor.run {
        let vc = UIActivityViewController(activityItems: [item], applicationActivities: nil)
        UIApplication.shared.topViewController?.present(vc, animated: true)
    }
}
```

```swift
// Domain/ICS/ICSGenerator.swift — UTType.calendarEvent for correct MIME
func generate(...) async throws -> URL {
    let content = buildICSContent(...)
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("invite_\(contact.id).ics")
    try content.write(to: url, atomically: true, encoding: .utf8)
    return url
}
```

---

## 7. Security Layer

### 7.1 Jailbreak Detection

```swift
// Security/JailbreakDetector.swift
struct JailbreakDetector {
    static var isJailbroken: Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        return hasSuspiciousFiles() || canWriteOutsideSandbox() || hasJailbreakDylibs()
        #endif
    }

    private static func hasSuspiciousFiles() -> Bool {
        let paths = [
            "/Applications/Cydia.app", "/Library/MobileSubstrate/MobileSubstrate.dylib",
            "/bin/bash", "/usr/sbin/sshd", "/etc/apt", "/private/var/lib/apt/",
            "/usr/bin/ssh", "/private/var/lib/cydia"
        ]
        return paths.contains { FileManager.default.fileExists(atPath: $0) }
    }

    private static func canWriteOutsideSandbox() -> Bool {
        let testPath = "/private/jailbreak_test_\(UUID().uuidString)"
        do {
            try "test".write(toFile: testPath, atomically: true, encoding: .utf8)
            try FileManager.default.removeItem(atPath: testPath)
            return true
        } catch { return false }
    }

    private static func hasJailbreakDylibs() -> Bool {
        // Check loaded dylibs for known substrate libs
        for i in 0..<_dyld_image_count() {
            if let name = _dyld_get_image_name(i) {
                let path = String(cString: name)
                if path.contains("MobileSubstrate") || path.contains("substitute") {
                    return true
                }
            }
        }
        return false
    }
}
```

Warning dialog shown on app launch (non-blocking — user can continue or quit, same as Android).

### 7.2 Screenshot Protection

```swift
// Security/ScreenshotProtection.swift
// iOS does not have FLAG_SECURE equivalent for the app window.
// Use UITextField's isSecureTextEntry on sensitive fields,
// and overlay a blur when app goes to background.

struct ScreenshotProtectionModifier: ViewModifier {
    @Environment(\.scenePhase) private var phase

    func body(content: Content) -> some View {
        content.overlay {
            if phase == .inactive {
                Color.black.ignoresSafeArea()
            }
        }
    }
}
```

Apply `.modifier(ScreenshotProtectionModifier())` to `RootNavigationView`.

### 7.3 Network Policy

`Info.plist`: `NSAppTransportSecurity` → `NSAllowsArbitraryLoads = false`. No domains whitelisted. The app makes zero network requests (all ML on-device via Vision framework).

### 7.4 FileProvider Equivalent

On iOS, files are shared via `UIActivityViewController` with a `URL` item. Temporary files go to `FileManager.default.temporaryDirectory`; permanent photos go to the app's Documents directory. The app never exposes `file://` URIs to other apps — all sharing via activity sheet.

### 7.5 Input Security Summary

| Field | Max Length | Enforcement Point |
|---|---|---|
| firstName / lastName | 100 chars | `Contact.init` |
| company / title / address | 300 chars | `Contact.init` |
| phone | 30 chars | `Contact.init` + `VCardParser` |
| email | 254 chars (RFC 5321) | `Contact.init` + `VCardParser` |
| notes | 2,000 chars | `Contact.init` |
| OCR input | 8,192 chars | `CardParser.parseCardText` |
| vCard file | 16,384 bytes | `VCardParser.parse` |
| LinkedIn URL | Must be https://linkedin.com/\* | `URLValidator.validateLinkedIn` |

---

## 8. Navigation Architecture

### 8.1 Typed Routes (No String Routes)

```swift
// UI/Navigation/AppRoute.swift
enum AppRoute: Hashable {
    case onboarding
    case profileSetup
    case home
    case contacts
    case camera
    case confirm
    case duplicate(contactID: UUID)
    case eventMatch(contactID: UUID)
    case detail(contactID: UUID)
    case contactEdit(contactID: UUID)
    case templates
    case templateEdit(templateID: UUID)
    case templateNew
    case mailCompose(contactID: UUID?)
    case mailSend
    case profile
    case settings
    case privacyPolicy
}
```

No string parsing. A typo in `AppRoute` is a compile error.

### 8.2 NavigationStack

```swift
// UI/Navigation/RootNavigationView.swift
struct RootNavigationView: View {
    @State private var path = NavigationPath()
    @State private var selectedTab: Tab = .home
    @EnvironmentObject private var scanFlow: ScanFlowActor  // reference type OK here

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack(path: $path) {
                HomeView()
                    .navigationDestination(for: AppRoute.self) { route in
                        switch route {
                        case .contacts:          ContactsView()
                        case .camera:            CameraView(onComplete: { path.append(.confirm) })
                        case .confirm:           ConfirmView(onConfirmed: { id in path.append(.duplicate(contactID: id)) })
                        case .duplicate(let id): DuplicateView(contactID: id, onContinue: { rid in path.append(.eventMatch(contactID: rid)) })
                        case .eventMatch(let id): EventMatchView(contactID: id, onDone: { path.removeLast(path.count) })
                        case .detail(let id):    DetailView(contactID: id)
                        case .contactEdit(let id): ContactEditView(contactID: id)
                        case .mailCompose(let id): MailComposeView(contactID: id)
                        // ... etc
                        default: EmptyView()
                        }
                    }
            }
            .tabItem { Label("Ana Sayfa", systemImage: "house") }
            .tag(Tab.home)
            // ... other tabs
        }
    }
}
```

### 8.3 .vcf File Import (Intent Equivalent)

```swift
// App/CardConnectApp.swift
@main
struct CardConnectApp: App {
    @StateObject private var scanFlow = ScanFlowActor()

    var body: some Scene {
        WindowGroup {
            RootNavigationView()
                .environmentObject(scanFlow)
                .onOpenURL { url in
                    handleIncomingVCF(url: url)
                }
        }
    }

    private func handleIncomingVCF(url: URL) {
        guard url.pathExtension.lowercased() == "vcf" else { return }
        Task {
            do {
                let parsed = try VCardParser.parse(.file(url))
                await scanFlow.setParsedCard(parsed)
                // Navigate to Confirm — done via environment NavigationPath injection
            } catch { /* show error */ }
        }
    }
}
```

`Info.plist` UTI registration:
```xml
<key>CFBundleDocumentTypes</key>
<array>
    <dict>
        <key>CFBundleTypeName</key><string>vCard</string>
        <key>LSItemContentTypes</key>
        <array>
            <string>public.vcard</string>
            <string>public.x-vcard</string>
        </array>
        <key>LSHandlerRank</key><string>Alternate</string>
    </dict>
</array>
```

---

## 9. Permission Handling

### 9.1 PermissionCoordinator

```swift
// Centralises permission state; no loops; routes to Settings on permanent denial.
@MainActor
final class PermissionCoordinator: ObservableObject {

    enum PermResult { case granted, denied, permanentlyDenied }

    // Camera
    func requestCamera() async -> PermResult {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return .granted
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            return granted ? .granted : .denied
        case .denied, .restricted:
            return .permanentlyDenied
        @unknown default: return .denied
        }
    }

    // Contacts
    func requestContacts() async -> PermResult {
        let store = CNContactStore()
        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .authorized: return .granted
        case .notDetermined:
            do {
                let granted = try await store.requestAccess(for: .contacts)
                return granted ? .granted : .denied
            } catch { return .denied }
        case .denied, .restricted:
            return .permanentlyDenied
        @unknown default: return .denied
        }
    }

    // Calendar (read-only)
    func requestCalendar() async -> PermResult {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess: return .granted
        case .notDetermined:
            let store = EKEventStore()
            do {
                let granted = try await store.requestFullAccessToEvents()
                return granted ? .granted : .denied
            } catch { return .denied }
        case .denied, .restricted, .writeOnly:
            return .permanentlyDenied
        @unknown default: return .denied
        }
    }

    func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
```

### 9.2 Rationale Sheet Pattern

```swift
// UI/Components/PermissionRationaleSheet.swift
struct PermissionRationaleSheet: View {
    let permission: PermissionType
    let onRequest: () async -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: permission.icon).font(.system(size: 48))
            Text(permission.title).font(.headline)
            Text(permission.rationale).multilineTextAlignment(.center)
            Button("İzin Ver") { Task { await onRequest() } }
                .buttonStyle(.borderedProminent)
            Button("Şimdi Değil", action: onSkip).foregroundStyle(.secondary)
        }
        .padding()
    }
}
```

**Rule: Never re-request after `.permanentlyDenied`.** Show a "Ayarlara Git" button instead — routes to `UIApplication.openSettingsURLString`. Track permanent denial count in `@AppStorage` to detect it correctly on the first launch where `authorizationStatus` is `.denied` (which means denied, not notDetermined).

### 9.3 No Permission Loops

Android Bug Cat-7 is prevented by:
1. Checking current status before requesting — never call `requestAccess` if already `.denied`
2. After `.denied` result, showing Snackbar equivalent (`.alert` or `.toast`) once and moving on
3. Permanent denial → Settings route shown; no automatic retry

---

## 10. Testing Strategy

Mirrors and improves on the 46 Android unit tests. Target: 60+ unit tests, 10+ UI tests.

### 10.1 Unit Tests

```swift
// Tests/Unit/CardParserTests.swift
final class CardParserTests: XCTestCase {

    func test_standardNameExtracted() {
        let result = CardParser.parseCardText("Ali Veli\nCEO\nTech A.Ş.\nali@tech.com")
        XCTAssertEqual(result.firstName, "Ali")
        XCTAssertEqual(result.lastName,  "Veli")
    }

    func test_inputClampedAt8192Chars() {
        let long = "Ali Veli\n" + String(repeating: "x", count: 9000)
        let result = CardParser.parseCardText(long)
        XCTAssertEqual(result.firstName, "Ali")
    }

    func test_phoneCappedAtThree() {
        let text = "Ali Veli\n+90 555 001 0001\n+90 555 002 0002\n+90 555 003 0003\n+90 555 004 0004"
        XCTAssertLessThanOrEqual(CardParser.parseCardText(text).phones.count, 3)
    }

    func test_faxExcluded() {
        let text = "Ali Veli\nTel: +90 555 111 2222\n📠 +90 555 111 3333"
        let phones = CardParser.parseCardText(text).phones
        XCTAssertFalse(phones.contains(where: { $0.contains("3333") }))
    }

    func test_emailNormalizedToLowercase() {
        let result = CardParser.parseCardText("Ali Veli\nAli.VELI@Tech.COM")
        XCTAssertEqual(result.emails.first, "ali.veli@tech.com")
    }

    func test_reversedNameFormat() {
        let result = CardParser.parseCardText("YILMAZ Ahmet\nSoftware Engineer")
        XCTAssertEqual(result.lastName,  "Yilmaz")
        XCTAssertEqual(result.firstName, "Ahmet")
    }
}
```

```swift
// Tests/Unit/VCardParserTests.swift
final class VCardParserTests: XCTestCase {

    func test_rfcLineUnfoldingApplied() throws {
        let folded = "BEGIN:VCARD\r\nVERSION:3.0\r\nFN:Ali\r\n  Veli\r\nEND:VCARD"
        let result = try VCardParser.parse(.string(folded))
        XCTAssertEqual(result.firstName, "Ali")
        XCTAssertEqual(result.lastName,  "Veli")
    }

    func test_tooLargeVCardThrows() {
        let large = String(repeating: "X", count: FieldLimits.maxVCard + 1)
        XCTAssertThrowsError(try VCardParser.parse(.string(large)))
    }

    func test_linkedInDomainValidated() throws {
        let evil = "BEGIN:VCARD\r\nVERSION:3.0\r\nFN:Ali Veli\r\nURL:https://evil.com/linkedin\r\nEND:VCARD"
        let result = try VCardParser.parse(.string(evil))
        XCTAssertTrue(result.linkedin.isEmpty)
    }

    func test_linkedInExtractedCorrectly() throws {
        let vcf = "BEGIN:VCARD\r\nVERSION:3.0\r\nFN:Ali Veli\r\nURL:https://linkedin.com/in/aliveli\r\nEND:VCARD"
        let result = try VCardParser.parse(.string(vcf))
        XCTAssertEqual(result.linkedin, "https://linkedin.com/in/aliveli")
    }
}
```

```swift
// Tests/Unit/ContactMergeTests.swift  — mirrors Android ContactMergeTest exactly
final class ContactMergeTests: XCTestCase {

    func test_incomingFirstNameWins() {
        let existing = Contact(firstName: "Eski", lastName: "Kişi")
        let incoming = Contact(firstName: "Yeni", lastName: "Kişi")
        XCTAssertEqual(DuplicateDetector.merge(existing: existing, incoming: incoming).firstName, "Yeni")
    }

    func test_existingPreservedWhenIncomingEmpty() {
        let existing = Contact(firstName: "Korunan", lastName: "Kişi")
        let incoming = Contact(firstName: "", lastName: "Kişi")
        XCTAssertEqual(DuplicateDetector.merge(existing: existing, incoming: incoming).firstName, "Korunan")
    }

    func test_emailsUnionDeduped() {
        let existing = Contact(emails: ["a@x.com", "b@x.com"])
        let incoming = Contact(emails: ["b@x.com", "c@x.com"])
        let merged = DuplicateDetector.merge(existing: existing, incoming: incoming).emails
        XCTAssertEqual(merged.count, 3)
        XCTAssertTrue(merged.contains("a@x.com"))
        XCTAssertTrue(merged.contains("c@x.com"))
    }

    func test_identicalNotesNotDuplicated() {
        let existing = Contact(notes: "Aynı not")
        let incoming = Contact(notes: "Aynı not")
        XCTAssertEqual(DuplicateDetector.merge(existing: existing, incoming: incoming).notes, "Aynı not")
    }

    func test_existingIDRetained() {
        let existing = Contact(id: UUID())
        let incoming = Contact(id: UUID())
        XCTAssertEqual(DuplicateDetector.merge(existing: existing, incoming: incoming).id, existing.id)
    }
}
```

Additional unit test files to implement:

- `ICSGeneratorTests` — RFC 5545 escaping, line folding at 75 octets, email validation, UTC date format
- `URLValidatorTests` — evil.com, intent:// scheme, http vs https, domain subpath variants
- `DuplicateDetectorTests` — name+company match, phone match, email match, no match, self-exclusion
- `FieldLimitsTests` — Contact init truncates fields correctly
- `ScanFlowActorTests` — concurrent access from multiple tasks

### 10.2 UI Tests

```swift
// Tests/UI/ScanFlowUITests.swift
final class ScanFlowUITests: XCTestCase {
    func test_confirmScreenShowsExtractedName() { /* ... */ }
    func test_duplicateDialogAppearsForDuplicate() { /* ... */ }
    func test_eventMatchSkipNavigatesToHome() { /* ... */ }
}
```

### 10.3 Test Coverage Rules

- `CardParser`, `VCardParser`, `DuplicateDetector`, `ICSGenerator`, `URLValidator` — 100% line coverage required (pure functions, no mocks needed)
- ViewModels — test with mock protocol implementations injected via init
- SwiftData `ContactStore` — tested with in-memory `ModelConfiguration`
- `ScanFlowActor` — tested with `Task { }` concurrent access to verify no data races

---

## 11. Anti-Patterns Explicitly Avoided

These patterns caused bugs in Android and must not appear in the iOS implementation.

### ❌ Mutable shared struct/class passed across concurrency domains
Use Swift actors (`ScanFlowActor`) instead. No `var` fields on a singleton accessible from multiple `Task` closures.

### ❌ String-typed navigation routes
Use `enum AppRoute: Hashable`. A `NavigationPath` typed to `AppRoute` produces compile errors on typos — not runtime crashes.

### ❌ LIKE-based duplicate detection with user data as wildcards
Use `#Predicate` with `==` for exact matches. For fields stored as JSON arrays, deserialise in Swift and compare with `Array.contains`.

### ❌ Two implementations of the same parser
One `VCardParser` with a `ParseSource` enum. Shared RFC 6350 unfolding applied in all cases.

### ❌ Raw URL string opened via deep link without domain validation
`URLValidator.validateLinkedIn` is called at parse time, not at display time. Stored `linkedin` field is guaranteed valid or empty.

### ❌ Unconstrained free-text fields in the persistence layer
`Contact.init` enforces `FieldLimits` on every field assignment. There is no way to create a `Contact` with an overlength field.

### ❌ Permissions requested without rationale, or re-requested after permanent denial
`PermissionCoordinator` checks `authorizationStatus` before every request call. `.permanentlyDenied` routes to Settings — never calls `requestAccess` again.

### ❌ Profile PII in UserDefaults
`UserProfile` (email, phone, name) lives in Keychain only. Non-sensitive booleans use `@AppStorage`.

### ❌ No process-death recovery for mid-flow screens
`AppRoute` values in `NavigationPath` are `Codable` via `Hashable` conformance. SwiftUI restores the path on scene reconnect. The `contactID` UUID in `.duplicate(contactID:)` and `.eventMatch(contactID:)` allows every screen to reload from SwiftData independently.

### ❌ Backup of contact photos and database without user consent
`Info.plist` sets `com.apple.developer.icloud-container-identifiers` to none. iCloud backup exclusion:
```swift
var resourceValues = URLResourceValues()
resourceValues.isExcludedFromBackup = true
try? photoDir.setResourceValues(resourceValues)
```
Applied to `photos/`, `ics/`, `vcf/` directories on first launch.

### ❌ Dead code / unused permissions in Info.plist
`NSCameraUsageDescription`, `NSContactsUsageDescription`, `NSCalendarsUsageDescription` are declared only. `NSPhotoLibraryUsageDescription` is added only if gallery picker is compiled in. Audited in CI via `SwiftLint` rule checking plist keys against usage sites.

---

*Document version: 1.0 — 2026-06-24*  
*Source: Android codebase analysis + DECISIONS.md + closed issue history (commits #106–#169)*
