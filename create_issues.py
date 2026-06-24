#!/usr/bin/env python3
"""Card Connect iOS — GitHub Epic + Issue yaratma scripti (PowerShell gh CLI ile)"""

import subprocess
import os
import sys
import tempfile

REPO = "tolgabarisalcitepe/ios-card-connect"

def gh(*args):
    result = subprocess.run(["gh"] + list(args), capture_output=True, text=True)
    if result.returncode != 0:
        print(f"  HATA: {result.stderr.strip()}", file=sys.stderr)
    return result.stdout.strip()

def create_label(name, color, desc):
    gh("label", "create", name, "--color", color, "--description", desc, "--repo", REPO, "--force")

def create_issue(title, labels, body):
    with tempfile.NamedTemporaryFile(mode='w', suffix='.md', delete=False, encoding='utf-8') as f:
        f.write(body)
        tmp = f.name
    try:
        url = gh("issue", "create", "--repo", REPO, "--title", title,
                 "--body-file", tmp, "--label", labels)
        return url
    finally:
        os.unlink(tmp)

def issue_num(url):
    return url.rstrip('/').split('/')[-1] if url else "?"

def add_to_project(project_num, url):
    if project_num and url:
        gh("project", "item-add", str(project_num),
           "--owner", "tolgabarisalcitepe", "--url", url)

# =============================================================================
# PROJECT
# =============================================================================
print("▶ GitHub Project oluşturuluyor...")
try:
    gh("auth", "refresh", "-s", "read:project,project")
except Exception:
    pass

raw = gh("project", "list", "--owner", "tolgabarisalcitepe", "--format", "json")
import json
project_num = None
try:
    projects = json.loads(raw).get("projects", [])
    for p in projects:
        if p.get("title") == "Card Connect iOS — Backlog":
            project_num = p["number"]
            print(f"  Mevcut project kullanılıyor: #{project_num}")
            break
except Exception:
    pass

if not project_num:
    out = gh("project", "create", "--owner", "tolgabarisalcitepe",
             "--title", "Card Connect iOS — Backlog")
    # Output genellikle URL içerir
    for line in out.splitlines():
        if "/projects/" in line:
            try:
                project_num = int(line.strip().rstrip('/').split('/')[-1])
            except Exception:
                pass

if project_num:
    print(f"✓ Project #{project_num} hazır")
else:
    print("  Project sayısı alınamadı, issue'lar repo'ya eklenecek")

# =============================================================================
# LABELS
# =============================================================================
print("\n▶ Label'lar yaratılıyor...")
labels = [
    ("epic:0-foundation",  "0052cc", "Epic 0 — Foundation"),
    ("epic:1-ocr",         "e4e669", "Epic 1 — OCR Pipeline"),
    ("epic:2-storage",     "0e8a16", "Epic 2 — Contact Storage"),
    ("epic:3-duplicate",   "b60205", "Epic 3 — Duplicate Flow"),
    ("epic:4-events",      "5319e7", "Epic 4 — Event Matching"),
    ("epic:5-mail",        "1d76db", "Epic 5 — Mail + Templates"),
    ("epic:6-profile",     "f9d0c4", "Epic 6 — Profile + QR"),
    ("epic:7-security",    "c5def5", "Epic 7 — Security Hardening"),
    ("type:feat",          "a2eeef", "New feature"),
    ("type:test",          "d93f0b", "Tests"),
    ("type:infra",         "e99695", "Infrastructure / DI / config"),
    ("type:security",      "ee0701", "Security"),
    ("type:chore",         "ededed", "Chore / housekeeping"),
    ("ios",                "1a1a2e", "iOS"),
    ("epic",               "6f42c1", "Epic tracking issue"),
]
for name, color, desc in labels:
    create_label(name, color, desc)
    print(f"  ✓ {name}")

# =============================================================================
# ISSUE FACTORY
# =============================================================================
def make(title, label_str, body):
    url = create_issue(title, label_str, body)
    num = issue_num(url)
    add_to_project(project_num, url)
    print(f"  ✓ #{num} — {title[:60]}")
    return url, num

# =============================================================================
# EPIC 0 — FOUNDATION
# =============================================================================
print("\n▶ Epic 0 — Foundation...")

e0_url, e0 = make("Epic 0 — Foundation", "epic:0-foundation,ios,epic", f"""## Özet
Xcode projesi ayağa kalkıyor. `SwiftData` şeması, `Keychain` wrapper, `DependencyContainer`, `NavigationStack` typed route sistemi, `ScanFlowActor` ve `PermissionCoordinator` kurulumu tamamlanıyor. Onboarding + boş HomeView ile uygulama ilk kez başarıyla açılıyor.

## Android → iOS Karşılaştırma
| Özellik | Android | iOS |
|---|---|---|
| Veritabanı | ✅ Room + SQLCipher | ❌ SwiftData + Keychain-encrypted yapılacak |
| Güvenli depolama | ✅ EncryptedSharedPreferences | ❌ Keychain yapılacak |
| DI | ✅ AppContainer (god object) | ❌ DependencyContainer protocol yapılacak |
| Navigation | ⚠️ String route (runtime crash riski) | ❌ AppRoute enum (typed) yapılacak |
| Scan state | ⚠️ AppContainer mutable state (race condition) | ❌ ScanFlowActor yapılacak |
| Permission yönetimi | ⚠️ Loop riski (Cat-7) | ❌ PermissionCoordinator yapılacak |
| Onboarding | ✅ 3 sayfa, privacy checkbox | ❌ iOS SwiftUI port yapılacak |

## Beklened Davranış
Uygulama açılıyor → Onboarding → ProfileSetup → Home (boş state).

```swift
// ScanFlowActor — race condition'sız transient state
actor ScanFlowActor {{
    private(set) var parsedCard: ParsedCard? = nil
    func setParsedCard(_ c: ParsedCard) {{ parsedCard = c }}
    func reset() {{ parsedCard = nil; photoPaths = [] }}
}}

// AppRoute — compile-time güvenli navigation
enum AppRoute: Hashable {{
    case onboarding, home, camera, confirm
    case duplicate(contactID: UUID)
    case eventMatch(contactID: UUID)
}}
```

## İlgili Dosyalar
- `App/CardConnectApp.swift` — @main, DI wiring, .vcf onOpenURL
- `App/DependencyContainer.swift` — protocol + live impl
- `Data/Persistence/ScanFlowActor.swift` — actor, tüm scan state
- `Data/Persistence/Schema/SchemaV1.swift` — ContactModel, EmailTemplateModel
- `Data/Persistence/ContactStore.swift` — @ModelActor CRUD
- `Data/Keychain/KeychainStore.swift` — generic keychain CRUD
- `Data/Keychain/UserProfileStore.swift` — actor, JSON encode/decode
- `UI/Navigation/AppRoute.swift` — enum AppRoute: Hashable
- `UI/Navigation/RootNavigationView.swift` — NavigationStack
- `UI/Onboarding/OnboardingView.swift`
- `UI/Home/HomeView.swift`
- `Security/ScreenshotProtection.swift`

## Tahmini Süre
**Uygulama:** ~3 gün
**Review:** ~2 saat

## Referans
- iOS_ARCHITECTURE.md §3, §5.1, §5.2, §8, §9
- DECISIONS.md §1, §2, §4, §5

## Doğrulama Checklist (Kapatmadan Önce)
- [ ] **Navigation** — Onboarding → ProfileSetup → Home akışı; back stack doğru
- [ ] **OCR** — N/A
- [ ] **API Calls** — N/A
- [ ] **Local Storage** — SwiftData insert/fetch round-trip; DB şifrelenmiş
- [ ] **Error Handling** — Keychain okuma hatası graceful handle ediliyor
- [ ] **Loading States** — N/A
- [ ] **Analytics** — N/A
- [ ] **Permissions** — PermissionCoordinator permanent denial → Settings yönlendirme
""")

make("feat(foundation): SwiftData stack — SchemaV1 + Keychain-encrypted DB", "epic:0-foundation,type:infra,ios", f"""## Özet
`SchemaV1` SwiftData modelleri tanımlanıyor. `ContactStore` @ModelActor actor ile CRUD (insert, update, delete, fetchAll, fetchById, search, findDuplicate) implement ediliyor. DB, Keychain'den alınan 32-byte key ile şifreleniyor.

## Android → iOS Karşılaştırma
| Özellik | Android | iOS |
|---|---|---|
| ORM | ✅ Room + SQLCipher | ❌ SwiftData + Keychain key yapılacak |
| Entity tanımı | ✅ @Entity data class | ❌ @Model class (SchemaV1) yapılacak |
| DB actor | ✅ Dispatchers.IO | ❌ @ModelActor yapılacak |
| Duplicate query | ⚠️ LIKE wildcard (Cat-5 bug) | ❌ #Predicate == exact match yapılacak |
| iCloud backup | N/A | ❌ isExcludedFromBackup yapılacak |

## Beklened Davranış
`ContactStore` in-memory `ModelConfiguration` ile test edilebilir; CRUD round-trip çalışıyor.

```swift
@ModelActor
actor ContactStore: ContactStoreProtocol {{
    func insert(_ contact: Contact) throws {{
        modelContext.insert(contact.toModel())
        try modelContext.save()
    }}
    func findDuplicate(firstName: String, ...) throws -> Contact? {{
        // #Predicate ile == , LIKE yok (Cat-5 fix)
    }}
}}
```

## İlgili Dosyalar
- `Data/Persistence/Schema/SchemaV1.swift`
- `Data/Persistence/Schema/SchemaV2.swift` — boş migration şablonu
- `Data/Persistence/ContactStore.swift`
- `Data/Persistence/ContactStoreProtocol.swift`
- `Tests/Unit/ContactStoreTests.swift`

## Tahmini Süre
**Uygulama:** ~4 saat
**Review:** ~30 dk

## Referans
- iOS_ARCHITECTURE.md §5.1
- Epic: #{e0}
- Android Bug Cat-5 (LIKE injection), Cat-6 (field limits)

## Doğrulama Checklist (Kapatmadan Önce)
- [ ] **Navigation** — N/A
- [ ] **OCR** — N/A
- [ ] **API Calls** — N/A
- [ ] **Local Storage** — insert → fetchById round-trip; DB isExcludedFromBackup=true
- [ ] **Error Handling** — modelContext.save() hatası yakalanıyor
- [ ] **Loading States** — N/A
- [ ] **Analytics** — N/A
- [ ] **Permissions** — N/A
""")

make("feat(foundation): KeychainStore + UserProfileStore", "epic:0-foundation,type:infra,ios", f"""## Özet
`KeychainStore` generic Keychain CRUD (save/load/delete). `UserProfileStore` actor olarak UserProfile'ı JSON encode ederek Keychain'de saklıyor. DB passphrase key yönetimi de burada. Android'deki callback-any-thread (Cat-8) bug'ı actor isolation ile önleniyor.

## Android → iOS Karşılaştırma
| Özellik | Android | iOS |
|---|---|---|
| Profil depolama | ✅ EncryptedSharedPreferences | ❌ Keychain + JSON actor yapılacak |
| Thread safety | ⚠️ Callback any thread (Cat-8) | ❌ Swift actor yapılacak |
| DB key | ✅ SQLCipher passphrase | ❌ Keychain 32-byte key yapılacak |

## Beklened Davranış
`UserProfileStore.save() → load()` round-trip testi geçiyor. UserProfile UserDefaults'a gitmiyor.

```swift
actor UserProfileStore {{
    func save(_ p: UserProfile) async throws {{
        try KeychainStore.save(key: "com.cardconnect.userprofile",
                               data: JSONEncoder().encode(p))
    }}
    func load() async -> UserProfile {{
        guard let d = try? KeychainStore.load(key: "com.cardconnect.userprofile"),
              let p = try? JSONDecoder().decode(UserProfile.self, from: d)
        else {{ return UserProfile() }}
        return p
    }}
}}
```

## İlgili Dosyalar
- `Data/Keychain/KeychainStore.swift`
- `Data/Keychain/UserProfileStore.swift`

## Tahmini Süre
**Uygulama:** ~2 saat
**Review:** ~20 dk

## Referans
- iOS_ARCHITECTURE.md §5.3, §5.4
- Epic: #{e0}
- Android Bug Cat-8

## Doğrulama Checklist (Kapatmadan Önce)
- [ ] **Navigation** — N/A
- [ ] **OCR** — N/A
- [ ] **API Calls** — N/A
- [ ] **Local Storage** — Keychain kSecClassGenericPassword item yazılıyor; round-trip OK
- [ ] **Error Handling** — Keychain corruption → yeni key üret, DB sıfırla
- [ ] **Loading States** — N/A
- [ ] **Analytics** — N/A
- [ ] **Permissions** — N/A
""")

make("feat(foundation): DependencyContainer + @Environment wiring", "epic:0-foundation,type:infra,ios", f"""## Özet
`DependencyContainer` protocol + `LiveDependencyContainer` impl yazılıyor. Her ViewModel sadece ihtiyacı olan protokolü constructor injection ile alıyor. Android'deki AppContainer god-object (Cat-1) anti-pattern'i yapısal olarak ortadan kaldırılıyor.

## Android → iOS Karşılaştırma
| Özellik | Android | iOS |
|---|---|---|
| DI | ⚠️ AppContainer god-object | ❌ DependencyContainer protocol yapılacak |
| ViewModel bağımlılığı | ⚠️ Application cast | ❌ init injection yapılacak |
| Test edilebilirlik | ⚠️ Zor | ❌ Mock protocol ile kolay yapılacak |

## Beklened Davranış
Mock `DependencyContainer` ile herhangi bir ViewModel unit test çalışıyor; `Application` cast yok.

```swift
protocol DependencyContainer {{
    var contactStore: ContactStoreProtocol {{ get }}
    var scanFlow: ScanFlowActor {{ get }}
    var permissionCoordinator: PermissionCoordinator {{ get }}
    var userProfileStore: UserProfileStore {{ get }}
}}
```

## İlgili Dosyalar
- `App/DependencyContainer.swift`
- `App/CardConnectApp.swift` — @StateObject wiring

## Tahmini Süre
**Uygulama:** ~2 saat
**Review:** ~20 dk

## Referans
- iOS_ARCHITECTURE.md §2
- Epic: #{e0}
- Android Bug Cat-1 (AppContainer god object)

## Doğrulama Checklist (Kapatmadan Önce)
- [ ] **Navigation** — N/A
- [ ] **OCR** — N/A
- [ ] **API Calls** — N/A
- [ ] **Local Storage** — N/A
- [ ] **Error Handling** — N/A
- [ ] **Loading States** — N/A
- [ ] **Analytics** — N/A
- [ ] **Permissions** — N/A
""")

make("feat(foundation): NavigationStack + AppRoute enum (typed routes)", "epic:0-foundation,type:feat,ios", f"""## Özet
`enum AppRoute: Hashable` ile tüm ekran geçişleri tip-güvenli. `NavigationStack<AppRoute>` + `.vcf` dosyası açıldığında `AppRoute.confirm`'e yönlendirme. Android'deki string route runtime crash'ları compile-time'a taşınıyor.

## Android → iOS Karşılaştırma
| Özellik | Android | iOS |
|---|---|---|
| Navigation | ⚠️ String route → runtime crash | ❌ AppRoute enum (compile-time) yapılacak |
| .vcf deep link | ✅ SplashActivity ACTION_VIEW | ❌ onOpenURL + Info.plist UTI yapılacak |
| Tab bar | ✅ BottomNavigation | ❌ TabView yapılacak |

## Beklened Davranış
Typo → compile error. `.vcf` açıldığında ConfirmView görünüyor.

```swift
enum AppRoute: Hashable {{
    case onboarding, profileSetup, home, contacts
    case camera, confirm
    case duplicate(contactID: UUID)
    case eventMatch(contactID: UUID)
    case detail(contactID: UUID), contactEdit(contactID: UUID)
    case mailCompose(contactID: UUID?), templates, profile, settings, privacyPolicy
}}
```

## İlgili Dosyalar
- `UI/Navigation/AppRoute.swift`
- `UI/Navigation/RootNavigationView.swift`
- `App/CardConnectApp.swift` — onOpenURL, Info.plist UTI

## Tahmini Süre
**Uygulama:** ~3 saat
**Review:** ~30 dk

## Referans
- iOS_ARCHITECTURE.md §8
- Epic: #{e0}
- Android Bug: string route crash (Cat-3)

## Doğrulama Checklist (Kapatmadan Önce)
- [ ] **Navigation** — .vcf dosyası ConfirmView'e gidiyor; tüm AppRoute case'leri bağlanmış; typo → compile error
- [ ] **OCR** — N/A
- [ ] **API Calls** — N/A
- [ ] **Local Storage** — N/A
- [ ] **Error Handling** — Bilinmeyen UTI sessizce görmezden geliniyor
- [ ] **Loading States** — N/A
- [ ] **Analytics** — N/A
- [ ] **Permissions** — N/A
""")

make("feat(foundation): ScanFlowActor — thread-safe transient scan state", "epic:0-foundation,type:infra,ios", f"""## Özet
`ScanFlowActor` Swift actor olarak implement ediliyor; Camera → Confirm → Duplicate → EventMatch akışındaki geçici state burada yaşıyor. `reset()` flow sonunda atomik olarak çağrılıyor. Android Cat-1 (race) ve Cat-2 (stale state) bug'ları yapısal olarak önleniyor.

## Android → iOS Karşılaştırma
| Özellik | Android | iOS |
|---|---|---|
| Scan state | ⚠️ AppContainer MutableList (race — Cat-1) | ❌ Swift actor yapılacak |
| State temizleme | ⚠️ pendingParsedCard temizlenmiyordu (Cat-2) | ❌ reset() yapılacak |

## Beklened Davranış
İki eş zamanlı Task yazarken data race yok. `reset()` sonrası tüm alanlar nil/empty.

```swift
actor ScanFlowActor {{
    private(set) var photoPaths:   [URL]       = []
    private(set) var parsedCard:   ParsedCard? = nil
    private(set) var contactID:    UUID?       = nil
    private(set) var incomingVCard: String?    = nil

    func setPhotoPaths(_ p: [URL]) {{ photoPaths = p }}
    func setParsedCard(_ c: ParsedCard) {{ parsedCard = c }}
    func setContactID(_ id: UUID) {{ contactID = id }}
    func setIncomingVCard(_ s: String) {{ incomingVCard = s }}
    func reset() {{ photoPaths = []; parsedCard = nil; contactID = nil; incomingVCard = nil }}
}}
```

## İlgili Dosyalar
- `Data/Persistence/ScanFlowActor.swift`
- `Tests/Unit/ScanFlowActorTests.swift`

## Tahmini Süre
**Uygulama:** ~1 saat
**Review:** ~20 dk

## Referans
- iOS_ARCHITECTURE.md §5.2
- Epic: #{e0}
- Android Bug Cat-1, Cat-2

## Doğrulama Checklist (Kapatmadan Önce)
- [ ] **Navigation** — N/A
- [ ] **OCR** — N/A
- [ ] **API Calls** — N/A
- [ ] **Local Storage** — reset() sonrası parsedCard nil; actor isolation uyarısı yok
- [ ] **Error Handling** — N/A
- [ ] **Loading States** — N/A
- [ ] **Analytics** — N/A
- [ ] **Permissions** — N/A
""")

make("feat(foundation): PermissionCoordinator — kamera, rehber, takvim", "epic:0-foundation,type:feat,ios", f"""## Özet
`PermissionCoordinator` implement ediliyor: kamera, rehber, takvim izinleri tek yerden yönetiliyor. `.permanentlyDenied`'da Settings'e yönleniyor; `requestAccess` asla tekrar çağrılmıyor. Android Cat-7 permission loop bug'ı yapısal olarak önleniyor.

## Android → iOS Karşılaştırma
| Özellik | Android | iOS |
|---|---|---|
| İzin döngüsü | ⚠️ shouldShowRationale loop (Cat-7) | ❌ denial count @AppStorage tracking yapılacak |
| Settings yönlendirme | ⚠️ Bazen eksik | ❌ UIApplication.openSettingsURLString yapılacak |
| Permission rationale | ✅ Mevcut | ❌ PermissionRationaleSheet component yapılacak |

## Beklened Davranış
`.permanentlyDenied` sonrası `requestAccess` çağrılmıyor; "Ayarlara Git" butonu görünüyor.

```swift
@MainActor final class PermissionCoordinator: ObservableObject {{
    enum PermResult {{ case granted, denied, permanentlyDenied }}
    func requestCamera() async -> PermResult {{
        switch AVCaptureDevice.authorizationStatus(for: .video) {{
        case .authorized: return .granted
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video) ? .granted : .denied
        case .denied, .restricted: return .permanentlyDenied
        @unknown default: return .denied
        }}
    }}
    func openSettings() {{
        guard let url = URL(string: UIApplication.openSettingsURLString) else {{ return }}
        UIApplication.shared.open(url)
    }}
}}
```

## İlgili Dosyalar
- `Data/Permissions/PermissionCoordinator.swift`
- `UI/Components/PermissionRationaleSheet.swift`

## Tahmini Süre
**Uygulama:** ~2 saat
**Review:** ~20 dk

## Referans
- iOS_ARCHITECTURE.md §9
- Epic: #{e0}
- Android Bug Cat-7

## Doğrulama Checklist (Kapatmadan Önce)
- [ ] **Navigation** — N/A
- [ ] **OCR** — N/A
- [ ] **API Calls** — N/A
- [ ] **Local Storage** — denial count @AppStorage'a yazılıyor
- [ ] **Error Handling** — İzin isteği exception → graceful handle
- [ ] **Loading States** — İzin diyalogu açıkken buton disabled
- [ ] **Analytics** — N/A
- [ ] **Permissions** — .denied sonrası requestAccess bir daha çağrılmıyor; permanentlyDenied → Settings
""")

make("feat(foundation): Onboarding + ProfileSetup + HomeView (boş)", "epic:0-foundation,type:feat,ios", f"""## Özet
Onboarding (3 sayfa SwiftUI TabView), ProfileSetup ve boş HomeView implement ediliyor. Privacy checkbox onaylanmadan ilerlenemiyor. App background'a geçince içerik siyah overlay ile gizleniyor (FLAG_SECURE karşılığı).

## Android → iOS Karşılaştırma
| Özellik | Android | iOS |
|---|---|---|
| Onboarding | ✅ 3 sayfa ViewPager | ❌ TabView(.page) yapılacak |
| Privacy checkbox | ✅ KVKK checkbox | ❌ SwiftUI Toggle yapılacak |
| FLAG_SECURE | ✅ MainActivity window flag | ❌ scenePhase overlay yapılacak |
| ProfileSetup | ✅ Mevcut | ❌ SwiftUI port yapılacak |

## Beklened Davranış
Onboarding → ProfileSetup → Home. App switcher'da içerik görünmüyor.

```swift
struct ScreenshotProtectionModifier: ViewModifier {{
    @Environment(\\.scenePhase) private var phase
    func body(content: Content) -> some View {{
        content.overlay {{ if phase == .inactive {{ Color.black.ignoresSafeArea() }} }}
    }}
}}
```

## İlgili Dosyalar
- `UI/Onboarding/OnboardingView.swift`
- `UI/ProfileSetup/ProfileSetupView.swift`
- `UI/Home/HomeView.swift`
- `Security/ScreenshotProtection.swift`

## Tahmini Süre
**Uygulama:** ~4 saat
**Review:** ~30 dk

## Referans
- iOS_ARCHITECTURE.md §7.2
- Epic: #{e0}
- Android: FLAG_SECURE (#119)

## Doğrulama Checklist (Kapatmadan Önce)
- [ ] **Navigation** — Onboarding → ProfileSetup → Home; Skip 1. ve 2. sayfada var
- [ ] **OCR** — N/A
- [ ] **API Calls** — N/A
- [ ] **Local Storage** — onboarding_done ve privacy_accepted @AppStorage'a yazılıyor
- [ ] **Error Handling** — N/A
- [ ] **Loading States** — N/A
- [ ] **Analytics** — N/A
- [ ] **Permissions** — N/A
""")

print("✓ Epic 0 tamamlandı")

# =============================================================================
# EPIC 1 — OCR PIPELINE
# =============================================================================
print("\n▶ Epic 1 — OCR Pipeline...")

e1_url, e1 = make("Epic 1 — OCR Pipeline", "epic:1-ocr,ios,epic", f"""## Özet
Kartvizit çekiminden OCR'a, alan çıkarmaya ve Confirm formuna kadar tüm scan pipeline çalışıyor. Android'deki iki ayrı VCardParser (Cat-9) tek implementasyona indirgeniyor. URL injection (Cat-4) URLValidator ile önleniyor.

## Android → iOS Karşılaştırma
| Özellik | Android | iOS |
|---|---|---|
| OCR engine | ✅ ML Kit (on-device) | ❌ VisionKit VNRecognizeTextRequest yapılacak |
| QR tarama | ✅ ML Kit Barcode | ❌ DataScannerViewController yapılacak |
| CardParser | ✅ Kotlin regex | ❌ NSRegularExpression port yapılacak |
| VCardParser | ⚠️ 2 ayrı impl (Cat-9) | ❌ Tek impl + ParseSource enum yapılacak |
| ConfirmView | ✅ Compose form | ❌ SwiftUI port yapılacak |
| Process death | ⚠️ Yoktu (Cat-3) | ❌ @SceneStorage draft yapılacak |

## Beklened Davranış
Kart çekiliyor → OCR → CardParser → ConfirmView'de alanlar dolu. QR → VCardParser → ConfirmView.

## İlgili Dosyalar
- `Domain/OCR/CardParser.swift`, `Domain/OCR/VisionOCRService.swift`
- `Domain/VCard/VCardParser.swift`, `Domain/Validation/URLValidator.swift`
- `UI/Camera/CameraView.swift`, `UI/Confirm/ConfirmView.swift`

## Tahmini Süre
**Uygulama:** ~5 gün
**Review:** ~3 saat

## Referans
- iOS_ARCHITECTURE.md §4.5, §4.6, §6
- Android Bug Cat-4, Cat-9

## Doğrulama Checklist (Kapatmadan Önce)
- [ ] **Navigation** — QR vCard → Confirm; non-vCard → alert; Yeniden Çek → CameraView
- [ ] **OCR** — Gerçek kartvizitte isim + telefon çıkarılıyor; 8192 char clamp çalışıyor
- [ ] **API Calls** — N/A (on-device)
- [ ] **Local Storage** — @SceneStorage ile form draft process kill sonrası korunuyor
- [ ] **Error Handling** — OCR başarısız → boş form, crash yok
- [ ] **Loading States** — OCR süresince spinner; Kaydet butonu async tamamlanana kadar disabled
- [ ] **Analytics** — N/A
- [ ] **Permissions** — Kamera permanentlyDenied → Settings
""")

make("feat(ocr): CameraView — AVFoundation card capture + QR DataScanner", "epic:1-ocr,type:feat,ios", f"""## Özet
`AVCaptureSession` ile ön + arka kart fotoğrafı çekimi, `DataScannerViewController` ile QR tarama, galeri picker ve non-vCard QR reddi.

## Android → iOS Karşılaştırma
| Özellik | Android | iOS |
|---|---|---|
| Kamera preview | ✅ CameraX | ❌ AVCaptureSession yapılacak |
| Çift fotoğraf | ✅ Ön + arka, "---" merge | ❌ Aynı mantık yapılacak |
| QR tarama | ✅ ML Kit ImageAnalysis | ❌ DataScannerViewController yapılacak |
| Non-vCard red | ✅ Snackbar | ❌ .alert yapılacak |
| Galeri picker | ✅ ActivityResultContracts | ❌ PhotosPicker yapılacak |

## Beklened Davranış
vCard QR → ConfirmView. Non-vCard → alert. Fotoğraflar ScanFlowActor.photoPaths'e kaydediliyor.

```swift
struct CameraView: View {{
    @State private var mode: CaptureMode = .card
    enum CaptureMode {{ case card, qr }}
    var body: some View {{
        ZStack {{
            if mode == .card {{ CardCaptureView(onPhotosTaken: vm.storePhotoPaths) }}
            else {{ DataScannerRepresentable(onQRDetected: vm.handleQRCode) }}
        }}
        .task {{ await vm.requestCameraPermission() }}
    }}
}}
```

## İlgili Dosyalar
- `UI/Camera/CameraView.swift`
- `UI/Camera/CameraViewModel.swift`
- `UI/Camera/DataScannerView.swift` — UIViewControllerRepresentable

## Tahmini Süre
**Uygulama:** ~6 saat
**Review:** ~45 dk

## Referans
- iOS_ARCHITECTURE.md §6
- Epic: #{e1}

## Doğrulama Checklist (Kapatmadan Önce)
- [ ] **Navigation** — vCard QR → ConfirmView; Yeniden Çek → CameraView
- [ ] **OCR** — Ön/arka fotoğraf "---" ile merge; ScanFlowActor.photoPaths'e kaydediliyor
- [ ] **API Calls** — N/A
- [ ] **Local Storage** — N/A
- [ ] **Error Handling** — Non-vCard QR → alert; kamera başlatma hatası graceful
- [ ] **Loading States** — Capture butonu işlem sırasında disabled
- [ ] **Analytics** — N/A
- [ ] **Permissions** — permanentlyDenied → Settings linki
""")

make("feat(ocr): VisionOCRService — VNRecognizeTextRequest wrapper", "epic:1-ocr,type:feat,ios", f"""## Özet
`VNRecognizeTextRequest` async wrapper. Türkçe + İngilizce dil tanıma. İki görüntüden gelen text "---" ile merge ediliyor ve 8192 karakter ile sınırlandırılıyor.

## Android → iOS Karşılaştırma
| Özellik | Android | iOS |
|---|---|---|
| OCR | ✅ ML Kit TextRecognition | ❌ VNRecognizeTextRequest yapılacak |
| Dil | ✅ Latin script | ❌ tr-TR + en-US yapılacak |
| Input cap | ✅ 8192 char | ❌ FieldLimits.maxOCRInput yapılacak |

## Beklened Davranış
`VisionOCRService.recognizeText(from: [CGImage]) async throws -> String` — iki görüntü merge ediliyor.

## İlgili Dosyalar
- `Domain/OCR/VisionOCRService.swift`
- `Domain/Validation/FieldLimits.swift`

## Tahmini Süre
**Uygulama:** ~3 saat
**Review:** ~20 dk

## Referans
- iOS_ARCHITECTURE.md §2
- Epic: #{e1}

## Doğrulama Checklist (Kapatmadan Önce)
- [ ] **Navigation** — N/A
- [ ] **OCR** — Gerçek kartvizitte isim çıkarılıyor; 8192 üzeri input clamp'leniyor
- [ ] **API Calls** — N/A (on-device)
- [ ] **Local Storage** — N/A
- [ ] **Error Handling** — VNRequest hatası VisionOCRError olarak iletiliyor
- [ ] **Loading States** — N/A
- [ ] **Analytics** — N/A
- [ ] **Permissions** — N/A
""")

make("feat(ocr): CardParser — Kotlin'den Swift'e port", "epic:1-ocr,type:feat,ios", f"""## Özet
Android `CardParser.kt` Swift'e port ediliyor. Kotlin regex'leri `NSRegularExpression`. Türkçe karakter desteği, faks hariç, ters isim, şirket suffix, LinkedIn normalizasyonu dahil.

## Android → iOS Karşılaştırma
| Özellik | Android | iOS |
|---|---|---|
| Regex | ✅ Kotlin Regex | ❌ NSRegularExpression yapılacak |
| Türkçe | ✅ | ❌ Unicode-aware yapılacak |
| Faks hariç | ✅ | ❌ Port yapılacak |
| Ters isim | ✅ SOYAD Ad | ❌ Port yapılacak |
| LinkedIn | ✅ | ❌ URLValidator.normalizeLinkedIn yapılacak |

## Beklened Davranış
`CardParser.parseCardText("Ali Veli\\nCEO\\nTech A.Ş.\\nali@tech.com")` → `ParsedCard(firstName:"Ali", ...)`

## İlgili Dosyalar
- `Domain/OCR/CardParser.swift`
- `Domain/Model/ParsedCard.swift`
- `Tests/Unit/CardParserTests.swift`

## Tahmini Süre
**Uygulama:** ~5 saat
**Review:** ~45 dk

## Referans
- iOS_ARCHITECTURE.md §4.6
- Epic: #{e1}
- Android: `domain/ocr/CardParser.kt`

## Doğrulama Checklist (Kapatmadan Önce)
- [ ] **Navigation** — N/A
- [ ] **OCR** — Tüm CardParserTests geçiyor; parseCardText("") crash yapmıyor
- [ ] **API Calls** — N/A
- [ ] **Local Storage** — N/A
- [ ] **Error Handling** — Boş/nil input → boş ParsedCard döndürülüyor
- [ ] **Loading States** — N/A
- [ ] **Analytics** — N/A
- [ ] **Permissions** — N/A
""")

make("feat(ocr): VCardParser — tek impl, ParseSource enum, RFC 6350 unfold", "epic:1-ocr,type:feat,ios", f"""## Özet
Android'de iki ayrı VCardParser (Cat-9) iOS'ta tek `VCardParser` + `ParseSource` enum ile replace ediliyor. RFC 6350 unfolding her iki source'ta uygulanıyor. LinkedIn domain validation zorunlu (Cat-4 fix).

## Android → iOS Karşılaştırma
| Özellik | Android | iOS |
|---|---|---|
| Parser sayısı | ⚠️ 2 ayrı impl (Cat-9) | ❌ Tek impl + ParseSource enum yapılacak |
| RFC 6350 unfold | ⚠️ Yalnızca biri uyguluyordu | ❌ Her iki source'ta yapılacak |
| URI injection | ⚠️ Domain check yoktu (Cat-4) | ❌ URLValidator yapılacak |
| Boyut limiti | ✅ 16384 bytes | ❌ FieldLimits.maxVCard yapılacak |

## Beklened Davranış
`.file(url)` ve `.string(vcf)` aynı unfold mantığını kullanıyor. evil.com URL reddediliyor.

```swift
enum ParseSource {{ case file(URL); case string(String) }}
struct VCardParser {{
    static func parse(_ source: ParseSource) throws -> ParsedCard {{ ... }}
}}
```

## İlgili Dosyalar
- `Domain/VCard/VCardParser.swift`
- `Domain/Validation/URLValidator.swift`
- `Tests/Unit/VCardParserTests.swift`

## Tahmini Süre
**Uygulama:** ~4 saat
**Review:** ~30 dk

## Referans
- iOS_ARCHITECTURE.md §4.5
- Epic: #{e1}
- Android Bug Cat-9, Cat-4

## Doğrulama Checklist (Kapatmadan Önce)
- [ ] **Navigation** — N/A
- [ ] **OCR** — N/A
- [ ] **API Calls** — N/A
- [ ] **Local Storage** — N/A
- [ ] **Error Handling** — 16384 byte üzeri → VCardError.tooLarge; malformed vCard → boş ParsedCard
- [ ] **Loading States** — N/A
- [ ] **Analytics** — N/A
- [ ] **Permissions** — N/A
""")

make("feat(ocr): ConfirmView + ConfirmViewModel", "epic:1-ocr,type:feat,ios", f"""## Özet
TabView fotoğraf pager, düzenlenebilir form (ad/soyad/şirket/ünvan/telefon/e-posta/adres/LinkedIn/not), dinamik satır ekleme/silme, QR kaynak banner. Form draft `@SceneStorage` ile process death'e karşı korunuyor (Android Cat-3 fix).

## Android → iOS Karşılaştırma
| Özellik | Android | iOS |
|---|---|---|
| Fotoğraf pager | ✅ ViewPager | ❌ TabView yapılacak |
| Dinamik satırlar | ✅ LazyColumn + add/remove | ❌ ForEach yapılacak |
| Process death | ⚠️ Yoktu (Cat-3) | ❌ @SceneStorage yapılacak |
| WRITE_CONTACTS | ✅ Save öncesi | ❌ PermissionCoordinator yapılacak |

## Beklened Davranış
Form doldurup save → ContactStore → DuplicateView. Process kill sonrası form korunuyor.

## İlgili Dosyalar
- `UI/Confirm/ConfirmView.swift`
- `UI/Confirm/ConfirmViewModel.swift`
- `UI/Components/PhoneEmailRowView.swift`

## Tahmini Süre
**Uygulama:** ~6 saat
**Review:** ~45 dk

## Referans
- iOS_ARCHITECTURE.md §6
- Epic: #{e1}
- Android Bug Cat-3

## Doğrulama Checklist (Kapatmadan Önce)
- [ ] **Navigation** — Yeniden Çek → CameraView; Save → DuplicateView
- [ ] **OCR** — ScanFlowActor.parsedCard form alanlarına doğru yükleniyor
- [ ] **API Calls** — N/A
- [ ] **Local Storage** — @SceneStorage form draft korunuyor; ContactStore.insert çalışıyor
- [ ] **Error Handling** — Save hatası alert ile gösteriliyor
- [ ] **Loading States** — Save butonu async süresince disabled
- [ ] **Analytics** — N/A
- [ ] **Permissions** — WRITE_CONTACTS reddedilince yalnızca SwiftData'ya kaydediliyor
""")

make("test(ocr): CardParser + VCardParser + URLValidator unit testleri", "epic:1-ocr,type:test,ios", f"""## Özet
Android testleri birebir Swift'e port ediliyor. CardParser, VCardParser, URLValidator — pure function oldukları için mock gerektirmiyor; %100 line coverage hedefleniyor.

## Android → iOS Karşılaştırma
| Özellik | Android | iOS |
|---|---|---|
| CardParserTest | ✅ ~42 test | ❌ XCTest port yapılacak |
| VCardParserTest | ✅ Mevcut | ❌ Port yapılacak |
| URLValidatorTest | ✅ Mevcut | ❌ Port yapılacak |

## Beklened Davranış
Tüm testler geçiyor; %100 line coverage.

## İlgili Dosyalar
- `Tests/Unit/CardParserTests.swift`
- `Tests/Unit/VCardParserTests.swift`
- `Tests/Unit/URLValidatorTests.swift`

## Tahmini Süre
**Uygulama:** ~3 saat
**Review:** ~20 dk

## Referans
- iOS_ARCHITECTURE.md §10
- Epic: #{e1}
- Android: `CardParserTest.kt`

## Doğrulama Checklist (Kapatmadan Önce)
- [ ] **Navigation** — N/A
- [ ] **OCR** — CardParser: isim, telefon, faks hariç, ters isim, clamp testleri geçiyor
- [ ] **API Calls** — N/A
- [ ] **Local Storage** — N/A
- [ ] **Error Handling** — N/A
- [ ] **Loading States** — N/A
- [ ] **Analytics** — N/A
- [ ] **Permissions** — N/A
""")

print("✓ Epic 1 tamamlandı")

# =============================================================================
# EPIC 2 — CONTACT STORAGE
# =============================================================================
print("\n▶ Epic 2 — Contact Storage...")

e2_url, e2 = make("Epic 2 — Contact Storage", "epic:2-storage,ios,epic", f"""## Özet
Contact domain model validation, ContactsView (liste/arama/swipe), DetailView (tappable), ContactEditView ve DeviceContactsService (CNContactStore). Android'deki LIKE injection (Cat-5), field limit (Cat-6) ve notes sync (#136) bug'ları önleniyor.

## Android → iOS Karşılaştırma
| Özellik | Android | iOS |
|---|---|---|
| Field limits | ⚠️ Yoktu (Cat-6) | ❌ Contact.init enforce yapılacak |
| LIKE injection | ⚠️ Cat-5 | ❌ #Predicate == yapılacak |
| Liste + arama | ✅ LazyColumn | ❌ List + searchable yapılacak |
| Device sync | ✅ ContentProviderClient | ❌ CNContactStore yapılacak |
| Notes sync | ⚠️ Eksikti (#136) | ❌ CNSaveRequest'te notes yapılacak |

## İlgili Dosyalar
- `Domain/Model/Contact.swift`, `Data/Persistence/ContactStore.swift`
- `UI/Contacts/ContactsView.swift`, `UI/Detail/DetailView.swift`
- `UI/Edit/ContactEditView.swift`, `Data/Contacts/DeviceContactsService.swift`

## Tahmini Süre
**Uygulama:** ~5 gün
**Review:** ~3 saat

## Referans
- iOS_ARCHITECTURE.md §4.1, §5.1, §6
- Android Bug Cat-5, Cat-6, #136

## Doğrulama Checklist (Kapatmadan Önce)
- [ ] **Navigation** — Swipe sağ → LinkedIn/mail; Swipe sol → sil onayı; Detail → Edit
- [ ] **OCR** — N/A
- [ ] **API Calls** — N/A
- [ ] **Local Storage** — Düzenleme SwiftData + CNContactStore (izin varsa); notes yazılıyor
- [ ] **Error Handling** — CNContactStore hata graceful; silme hatası alert
- [ ] **Loading States** — Arama 200ms debounce
- [ ] **Analytics** — N/A
- [ ] **Permissions** — WRITE_CONTACTS reddedilince yalnızca SwiftData
""")

make("feat(storage): Contact struct + FieldLimits validation", "epic:2-storage,type:feat,ios", f"""## Özet
`Contact` struct'ın `init`'inde tüm alanlar `FieldLimits` ile enforce ediliyor. Aşan değerler truncate edilir; overlength veri veritabanına ulaşamaz (Android Cat-6 fix).

## Android → iOS Karşılaştırma
| Özellik | Android | iOS |
|---|---|---|
| Field limits | ⚠️ Room entity'de yoktu (Cat-6) | ❌ Contact.init'te yapılacak |

## Beklened Davranış
`Contact(company: String(repeating:"x", count:301)).company.count == 300`

## İlgili Dosyalar
- `Domain/Model/Contact.swift`
- `Domain/Model/ParsedCard.swift`, `Domain/Model/EmailTemplate.swift`
- `Domain/Validation/FieldLimits.swift`

## Tahmini Süre
**Uygulama:** ~2 saat
**Review:** ~20 dk

## Referans
- iOS_ARCHITECTURE.md §4.1, §4.3
- Epic: #{e2}
- Android Bug Cat-6

## Doğrulama Checklist (Kapatmadan Önce)
- [ ] **Navigation** — N/A
- [ ] **OCR** — N/A
- [ ] **API Calls** — N/A
- [ ] **Local Storage** — 301 char → 300 truncate; 4. telefon eklenmek istenince max 3'te kalıyor
- [ ] **Error Handling** — N/A
- [ ] **Loading States** — N/A
- [ ] **Analytics** — N/A
- [ ] **Permissions** — N/A
""")

make("feat(storage): ContactStore — SwiftData CRUD + exact-match duplicate query", "epic:2-storage,type:feat,ios", f"""## Özet
`ContactStore` @ModelActor. `findDuplicate` `#Predicate` ile exact match (==); LIKE wildcard injection riski yok (Cat-5 fix). Arama da in-memory yapılıyor.

## Android → iOS Karşılaştırma
| Özellik | Android | iOS |
|---|---|---|
| Duplicate query | ⚠️ SQL LIKE (Cat-5) | ❌ #Predicate == yapılacak |
| Arama | ✅ SQL LIKE | ❌ In-memory .contains yapılacak |

## Beklened Davranış
Phone = "%" olan kontak tüm kayıtlarla eşleşmiyor.

## İlgili Dosyalar
- `Data/Persistence/ContactStoreProtocol.swift`
- `Data/Persistence/ContactStore.swift`
- `Tests/Unit/ContactStoreTests.swift`

## Tahmini Süre
**Uygulama:** ~4 saat
**Review:** ~30 dk

## Referans
- iOS_ARCHITECTURE.md §5.1
- Epic: #{e2}
- Android Bug Cat-5

## Doğrulama Checklist (Kapatmadan Önce)
- [ ] **Navigation** — N/A
- [ ] **OCR** — N/A
- [ ] **API Calls** — N/A
- [ ] **Local Storage** — CRUD in-memory round-trip; % wildcard injection testi geçiyor
- [ ] **Error Handling** — modelContext.save() hatası throw ediliyor
- [ ] **Loading States** — N/A
- [ ] **Analytics** — N/A
- [ ] **Permissions** — N/A
""")

make("feat(storage): ContactsView — liste, arama, swipe aksiyonları", "epic:2-storage,type:feat,ios", f"""## Özet
`List` + `searchable` modifier (200ms debounce), swipe-to-delete (onay dialog), swipe-to-right (LinkedIn veya mail compose). İlk açılışta swipe hint animasyonu. Silme aynı zamanda ICS dosyasını da temizliyor (Android #133 fix).

## Android → iOS Karşılaştırma
| Özellik | Android | iOS |
|---|---|---|
| Liste | ✅ LazyColumn + SwipeToDismiss | ❌ List + swipeActions yapılacak |
| Arama | ✅ 200ms debounce | ❌ searchable + .debounce yapılacak |
| ICS temizleme | ⚠️ Eksikti (#133) | ❌ Silme + ICS dosyası silinecek |

## İlgili Dosyalar
- `UI/Contacts/ContactsView.swift`
- `UI/Contacts/ContactsViewModel.swift`
- `UI/Components/InitialsAvatarView.swift`

## Tahmini Süre
**Uygulama:** ~5 saat
**Review:** ~30 dk

## Referans
- iOS_ARCHITECTURE.md §6
- Epic: #{e2}
- Android: #133

## Doğrulama Checklist (Kapatmadan Önce)
- [ ] **Navigation** — Swipe sağ → LinkedIn/mail; row tap → DetailView
- [ ] **OCR** — N/A
- [ ] **API Calls** — N/A
- [ ] **Local Storage** — Silme: SwiftData + CNContactStore + ICS dosyası
- [ ] **Error Handling** — Silme hatası alert
- [ ] **Loading States** — Arama 200ms debounce; async stream
- [ ] **Analytics** — N/A
- [ ] **Permissions** — N/A
""")

make("feat(storage): DetailView — tappable fields, vCard share, edit/delete", "epic:2-storage,type:feat,ios", f"""## Özet
Tıklanabilir telefon (tel://), e-posta (mailto:), adres (maps://), LinkedIn. LinkedIn açılmadan URLValidator kontrolü (Cat-4 fix). vCard paylaşımı UIActivityViewController. Fotoğraf TabView pager.

## Android → iOS Karşılaştırma
| Özellik | Android | iOS |
|---|---|---|
| Tıklanabilir | ✅ Intent'ler | ❌ openURL yapılacak |
| LinkedIn güvenlik | ⚠️ Domain check yoktu (Cat-4) | ❌ URLValidator yapılacak |
| vCard share | ✅ FileProvider | ❌ UIActivityViewController yapılacak |

## İlgili Dosyalar
- `UI/Detail/DetailView.swift`
- `UI/Detail/DetailViewModel.swift`

## Tahmini Süre
**Uygulama:** ~4 saat
**Review:** ~30 dk

## Referans
- iOS_ARCHITECTURE.md §6
- Epic: #{e2}
- Android Bug Cat-4

## Doğrulama Checklist (Kapatmadan Önce)
- [ ] **Navigation** — Edit → ContactEditView; Share → UIActivityViewController
- [ ] **OCR** — N/A
- [ ] **API Calls** — N/A
- [ ] **Local Storage** — ContactStore live update çalışıyor
- [ ] **Error Handling** — Geçersiz LinkedIn açılmıyor; RFC escape ile vCard doğru
- [ ] **Loading States** — N/A
- [ ] **Analytics** — N/A
- [ ] **Permissions** — Rehbere Ekle → WRITE_CONTACTS ister
""")

make("feat(storage): ContactEditView + DeviceContactsService sync", "epic:2-storage,type:feat,ios", f"""## Özet
`ContactEditView` mevcut kişiyi düzenleme. `DeviceContactsService` CNContactStore wrapper — add/update(delete+reinsert)/delete. Android'de notes alanı rehbere yazılmıyordu (#136); burada düzeltiliyor.

## Android → iOS Karşılaştırma
| Özellik | Android | iOS |
|---|---|---|
| Edit form | ✅ Compose | ❌ SwiftUI port yapılacak |
| Device sync | ✅ delete+reinsert | ❌ CNSaveRequest yapılacak |
| Notes sync | ⚠️ Eksikti (#136) | ❌ CNContactStore'a notes eklenecek |

## İlgili Dosyalar
- `UI/Edit/ContactEditView.swift`, `UI/Edit/ContactEditViewModel.swift`
- `Data/Contacts/DeviceContactsService.swift`
- `Data/Photo/PhotoStorage.swift`

## Tahmini Süre
**Uygulama:** ~5 saat
**Review:** ~30 dk

## Referans
- iOS_ARCHITECTURE.md §6
- Epic: #{e2}
- Android: #136

## Doğrulama Checklist (Kapatmadan Önce)
- [ ] **Navigation** — Save → DetailView; back → iptal
- [ ] **OCR** — N/A
- [ ] **API Calls** — N/A
- [ ] **Local Storage** — SwiftData + CNContactStore güncelleniyor; notes yazılıyor
- [ ] **Error Handling** — CNContactStore hata → yalnızca SwiftData
- [ ] **Loading States** — Save butonu disabled (async)
- [ ] **Analytics** — N/A
- [ ] **Permissions** — WRITE_CONTACTS permanentlyDenied → Settings
""")

print("✓ Epic 2 tamamlandı")

# =============================================================================
# EPIC 3 — DUPLICATE FLOW
# =============================================================================
print("\n▶ Epic 3 — Duplicate Flow...")

e3_url, e3 = make("Epic 3 — Duplicate Flow", "epic:3-duplicate,ios,epic", f"""## Özet
Kayıt sonrası duplicate detection ve merge. `DuplicateDetector` pure function (DB erişimi yok). Android Cat-2 (stale state), #138 (geri butonu) ve #135 (notes kaybolma) önleniyor.

## Android → iOS Karşılaştırma
| Özellik | Android | iOS |
|---|---|---|
| Duplicate detection | ✅ DuplicateViewModel + DB | ❌ Pure function yapılacak |
| Stale state | ⚠️ Cat-2 | ❌ ScanFlowActor.reset() yapılacak |
| Geri butonu | ⚠️ Bozuktu (#138) | ❌ NavigationPath.removeLast yapılacak |
| Notes kaybolma | ⚠️ Merge'de (#135) | ❌ DuplicateDetector.merge'de fixed |

## İlgili Dosyalar
- `Domain/Duplicate/DuplicateDetector.swift`
- `UI/Duplicate/DuplicateView.swift`
- `Tests/Unit/ContactMergeTests.swift`

## Tahmini Süre
**Uygulama:** ~2 gün
**Review:** ~1 saat

## Referans
- iOS_ARCHITECTURE.md §4.7, §6
- Android Bug Cat-2, #138, #135

## Doğrulama Checklist (Kapatmadan Önce)
- [ ] **Navigation** — Merge → DetailView; Yeni Kayıt → EventMatchView; Geri → ConfirmView
- [ ] **OCR** — N/A
- [ ] **API Calls** — N/A
- [ ] **Local Storage** — Merge → ContactStore.update; ScanFlowActor.reset() sonrası parsedCard nil
- [ ] **Error Handling** — N/A
- [ ] **Loading States** — Merge butonu async süresince disabled
- [ ] **Analytics** — N/A
- [ ] **Permissions** — N/A
""")

make("feat(duplicate): DuplicateDetector — pure function, no DB", "epic:3-duplicate,type:feat,ios", f"""## Özet
`DuplicateDetector` pure function — DB erişimi yok. `findDuplicate(for:in:)`: 1) ad+soyad+şirket, 2) telefon exact, 3) e-posta exact. `merge(existing:incoming:)`: yeni non-empty alanlar kazanır; e-postalar union+dedup; notlar concat distinct.

## Android → iOS Karşılaştırma
| Özellik | Android | iOS |
|---|---|---|
| Detector | ✅ DuplicateViewModel (DB bağımlı) | ❌ Pure function yapılacak |
| Merge | ✅ Mevcut | ❌ Swift port yapılacak |

## Beklened Davranış
`DuplicateDetector.findDuplicate(for: card, in: allContacts)` — caller contacts'ı geçiyor; DB çağrısı yok.

## İlgili Dosyalar
- `Domain/Duplicate/DuplicateDetector.swift`
- `Tests/Unit/ContactMergeTests.swift`
- `Tests/Unit/DuplicateDetectorTests.swift`

## Tahmini Süre
**Uygulama:** ~3 saat
**Review:** ~20 dk

## Referans
- iOS_ARCHITECTURE.md §4.7
- Epic: #{e3}

## Doğrulama Checklist (Kapatmadan Önce)
- [ ] **Navigation** — N/A
- [ ] **OCR** — N/A
- [ ] **API Calls** — N/A
- [ ] **Local Storage** — ContactMergeTests: 24 test geçiyor; ScanFlowActor.reset() sonrası state nil
- [ ] **Error Handling** — N/A
- [ ] **Loading States** — N/A
- [ ] **Analytics** — N/A
- [ ] **Permissions** — N/A
""")

make("feat(duplicate): DuplicateView — diff görünüm, merge / yeni kayıt", "epic:3-duplicate,type:feat,ios", f"""## Özet
Mevcut vs. yeni kişi yan yana diff. "Mevcut Güncelle" → merge + ContactStore.update. "Yeni Kayıt" → mevcut kişiyi bırak. Geri butonu çalışıyor (Android #138 fix). Merge'de notes kaybolmuyor (Android #135 fix).

## Android → iOS Karşılaştırma
| Özellik | Android | iOS |
|---|---|---|
| Diff view | ✅ Mevcut | ❌ SwiftUI port yapılacak |
| Geri butonu | ⚠️ Bozuktu (#138) | ❌ NavigationPath.removeLast yapılacak |
| Notes | ⚠️ Kayboluyordu (#135) | ❌ merge'de concat distinct |

## İlgili Dosyalar
- `UI/Duplicate/DuplicateView.swift`
- `UI/Duplicate/DuplicateViewModel.swift`

## Tahmini Süre
**Uygulama:** ~3 saat
**Review:** ~20 dk

## Referans
- iOS_ARCHITECTURE.md §6
- Epic: #{e3}
- Android: #138, #135

## Doğrulama Checklist (Kapatmadan Önce)
- [ ] **Navigation** — Geri → ConfirmView; Merge → EventMatchView
- [ ] **OCR** — N/A
- [ ] **API Calls** — N/A
- [ ] **Local Storage** — Merge sonrası notes concat (distinct) doğrulanıyor
- [ ] **Error Handling** — N/A
- [ ] **Loading States** — Merge butonu async disabled
- [ ] **Analytics** — N/A
- [ ] **Permissions** — N/A
""")

make("test(duplicate): ContactMergeTests — Android ContactMergeTest.kt birebir port", "epic:3-duplicate,type:test,ios", f"""## Özet
Android `ContactMergeTest.kt` birebir Swift port. 24 test case: firstName/lastName/company/title wins, phones, emails union dedup, notes distinct concat, photoURLs union, ID retained.

## Beklened Davranış
24/24 test geçiyor; DuplicateDetector.merge %100 line coverage.

## İlgili Dosyalar
- `Tests/Unit/ContactMergeTests.swift`
- `Tests/Unit/DuplicateDetectorTests.swift`

## Tahmini Süre
**Uygulama:** ~2 saat
**Review:** ~15 dk

## Referans
- iOS_ARCHITECTURE.md §10
- Epic: #{e3}
- Android: `ContactMergeTest.kt`

## Doğrulama Checklist (Kapatmadan Önce)
- [ ] **Navigation** — N/A
- [ ] **OCR** — N/A
- [ ] **API Calls** — N/A
- [ ] **Local Storage** — 24 test geçiyor
- [ ] **Error Handling** — N/A
- [ ] **Loading States** — N/A
- [ ] **Analytics** — N/A
- [ ] **Permissions** — N/A
""")

print("✓ Epic 3 tamamlandı")

# =============================================================================
# EPIC 4 — EVENT MATCHING
# =============================================================================
print("\n▶ Epic 4 — Event Matching...")

e4_url, e4 = make("Epic 4 — Event Matching", "epic:4-events,ios,epic", f"""## Özet
Kayıt sonrası bugünün takvim etkinlikleri sunuluyor. Takvim izni reddedilince skip (Android #139 fix). Etkinlik seçilince notes append ediliyor, overwrite yok (Android #134 fix). İlk kayıtta In-App Review tetikleniyor.

## Android → iOS Karşılaştırma
| Özellik | Android | iOS |
|---|---|---|
| Calendar API | ✅ CalendarRepository | ❌ CalendarService (EKEventStore) yapılacak |
| İzin crash | ⚠️ SecurityException (#139) | ❌ EKAuthorizationStatus check yapılacak |
| Notes overwrite | ⚠️ Mevcut notlar siliniyordu (#134) | ❌ Concat append yapılacak |
| In-App Review | ✅ Google Play Review | ❌ SKStoreReviewController yapılacak |

## İlgili Dosyalar
- `Data/Calendar/CalendarService.swift`
- `UI/EventMatch/EventMatchView.swift`
- `UI/EventMatch/EventMatchViewModel.swift`

## Tahmini Süre
**Uygulama:** ~2 gün
**Review:** ~1 saat

## Referans
- iOS_ARCHITECTURE.md §6
- Android: #134, #139

## Doğrulama Checklist (Kapatmadan Önce)
- [ ] **Navigation** — Skip/seçim → Home; izin reddi → skip; Geri → DuplicateView
- [ ] **OCR** — N/A
- [ ] **API Calls** — N/A
- [ ] **Local Storage** — eventName + notes append ContactStore'a yazılıyor
- [ ] **Error Handling** — EKEventStore hata → boş liste; crash yok
- [ ] **Loading States** — "Daha fazla yükle" pagination
- [ ] **Analytics** — N/A
- [ ] **Permissions** — READ_CALENDAR reddedilince view skip
""")

make("feat(events): CalendarService — EKEventStore wrapper", "epic:4-events,type:feat,ios", f"""## Özet
`EKEventStore` wrapper. `getEventsForDay()`, `getEventsBefore(limit:)`. İzin yoksa boş dizi dönüyor; crash yok. Events DTSTART ASC sıralı.

## Android → iOS Karşılaştırma
| Özellik | Android | iOS |
|---|---|---|
| Calendar | ✅ ContentResolver | ❌ EKEventStore yapılacak |
| İzin kontrolü | ⚠️ SecurityException | ❌ EKAuthorizationStatus check yapılacak |

## İlgili Dosyalar
- `Data/Calendar/CalendarService.swift`
- `Domain/Model/Event.swift`

## Tahmini Süre
**Uygulama:** ~2 saat
**Review:** ~15 dk

## Referans
- Epic: #{e4}

## Doğrulama Checklist (Kapatmadan Önce)
- [ ] **Navigation** — N/A
- [ ] **OCR** — N/A
- [ ] **API Calls** — N/A
- [ ] **Local Storage** — N/A
- [ ] **Error Handling** — İzin yok → boş liste; hata → boş liste
- [ ] **Loading States** — N/A
- [ ] **Analytics** — N/A
- [ ] **Permissions** — .fullAccess yoksa requestFullAccessToEvents çağrılıyor
""")

make("feat(events): EventMatchView + ViewModel — etkinlik seçimi, izin yönetimi", "epic:4-events,type:feat,ios", f"""## Özet
3 state: aktif etkinlik/bugün listesi/yok. "Daha fazla yükle" pagination. Etkinlik seçimi → contact.eventName güncelleniyor, notes'a append. İzin reddedilince screen skip (Android #139). İlk kayıtta SKStoreReviewController (Android #141 analog).

## Android → iOS Karşılaştırma
| Özellik | Android | iOS |
|---|---|---|
| State'ler | ✅ aktif/bugün/yok | ❌ Swift port yapılacak |
| Notes append | ⚠️ Overwrite (#134) | ❌ Concat yapılacak |
| Skip on denial | ⚠️ Crash (#139) | ❌ Screen skip yapılacak |

## İlgili Dosyalar
- `UI/EventMatch/EventMatchView.swift`
- `UI/EventMatch/EventMatchViewModel.swift`

## Tahmini Süre
**Uygulama:** ~4 saat
**Review:** ~30 dk

## Referans
- iOS_ARCHITECTURE.md §6
- Epic: #{e4}
- Android: #134, #139

## Doğrulama Checklist (Kapatmadan Önce)
- [ ] **Navigation** — Skip → Home; Geri → DuplicateView
- [ ] **OCR** — N/A
- [ ] **API Calls** — N/A
- [ ] **Local Storage** — Mevcut notlar silinmiyor; eventName ContactStore'a yazılıyor
- [ ] **Error Handling** — EKEventStore hata → boş liste, crash yok
- [ ] **Loading States** — "Daha fazla yükle" butonu; pagination async
- [ ] **Analytics** — N/A
- [ ] **Permissions** — READ_CALENDAR reddedilince skip; WRITE_CONTACTS yoksa yalnızca SwiftData
""")

print("✓ Epic 4 tamamlandı")

# =============================================================================
# EPIC 5 — MAIL + TEMPLATES
# =============================================================================
print("\n▶ Epic 5 — Mail + Templates...")

e5_url, e5 = make("Epic 5 — Mail + Templates", "epic:5-mail,ios,epic", f"""## Özet
5 Türkçe şablon SwiftData'da. Değişkenler (contact+profil) çözümleniyor. ICS RFC 5545 uyumlu üretiliyor, UTType.calendarEvent ile paylaşılıyor (Android Cat-10 fix). `[Etkinlik]` boşken bozuk metin yok (Android #116 fix).

## Android → iOS Karşılaştırma
| Özellik | Android | iOS |
|---|---|---|
| Template storage | ✅ Room | ❌ SwiftData yapılacak |
| ICS MIME | ⚠️ Yanlış (Cat-10) | ❌ UTType.calendarEvent yapılacak |
| [Etkinlik] boş | ⚠️ Bozuk metin (#116) | ❌ Cümle silme yapılacak |

## İlgili Dosyalar
- `Domain/ICS/ICSGenerator.swift`
- `UI/Templates/TemplatesView.swift`, `UI/Mail/MailComposeView.swift`

## Tahmini Süre
**Uygulama:** ~4 gün
**Review:** ~2 saat

## Referans
- iOS_ARCHITECTURE.md §4, §6
- Android Bug Cat-10, #116

## Doğrulama Checklist (Kapatmadan Önce)
- [ ] **Navigation** — Şablon seç → MailComposeView; ICS → UIActivityViewController
- [ ] **OCR** — N/A
- [ ] **API Calls** — N/A
- [ ] **Local Storage** — EmailTemplateStore CRUD; default reset çalışıyor
- [ ] **Error Handling** — Geçersiz e-posta → ORGANIZER yok; ICS hata throw
- [ ] **Loading States** — ICS üretimi async
- [ ] **Analytics** — N/A
- [ ] **Permissions** — N/A
""")

make("feat(mail): EmailTemplate SwiftData entity + 5 varsayılan şablon seed", "epic:5-mail,type:feat,ios", f"""## Özet
`EmailTemplateModel` @Model. 5 Türkçe default şablon seed: Tanışma, İş Birliği, Bilgi Talebi, Takip, Toplantı Daveti. Default şablon silinirse reset ile orijinaline dönüyor.

## Android → iOS Karşılaştırma
| Özellik | Android | iOS |
|---|---|---|
| Template entity | ✅ Room @Entity | ❌ @Model yapılacak |
| 5 default | ✅ Seed mevcut | ❌ iOS seed yapılacak |
| Token UI | ⚠️ Raw token gösteriliyordu (#117) | ❌ Chip render yapılacak |

## İlgili Dosyalar
- `Data/Persistence/Schema/SchemaV1.swift` — EmailTemplateModel
- `Domain/Model/EmailTemplate.swift`

## Tahmini Süre
**Uygulama:** ~3 saat
**Review:** ~20 dk

## Referans
- Epic: #{e5}
- Android: #117

## Doğrulama Checklist (Kapatmadan Önce)
- [ ] **Navigation** — N/A
- [ ] **OCR** — N/A
- [ ] **API Calls** — N/A
- [ ] **Local Storage** — 5 default şablon ilk açılışta; reset orijinale dönüyor
- [ ] **Error Handling** — N/A
- [ ] **Loading States** — N/A
- [ ] **Analytics** — N/A
- [ ] **Permissions** — N/A
""")

make("feat(mail): TemplatesView + TemplateEditView", "epic:5-mail,type:feat,ios", f"""## Özet
`TemplatesView` swipe-to-delete + swipe-to-reset. `TemplateEditView` değişken chip'leri `AttributedString`. Chip tap → cursor pozisyonuna token ekleniyor.

## Android → iOS Karşılaştırma
| Özellik | Android | iOS |
|---|---|---|
| Chip render | ✅ AnnotatedString | ❌ AttributedString yapılacak |
| Swipe actions | ✅ SwipeToDismiss | ❌ swipeActions yapılacak |

## İlgili Dosyalar
- `UI/Templates/TemplatesView.swift`, `UI/Templates/TemplatesViewModel.swift`
- `UI/Templates/TemplateEditView.swift`, `UI/Templates/TemplateEditViewModel.swift`

## Tahmini Süre
**Uygulama:** ~4 saat
**Review:** ~30 dk

## Referans
- Epic: #{e5}

## Doğrulama Checklist (Kapatmadan Önce)
- [ ] **Navigation** — Liste → Edit; Yeni → TemplateEditView(id:"new")
- [ ] **OCR** — N/A
- [ ] **API Calls** — N/A
- [ ] **Local Storage** — CRUD; default reset çalışıyor
- [ ] **Error Handling** — Boş isim → kayıt engelleniyor
- [ ] **Loading States** — N/A
- [ ] **Analytics** — N/A
- [ ] **Permissions** — N/A
""")

make("feat(mail): ICSGenerator — RFC 5545 uyumlu toplantı daveti", "epic:5-mail,type:feat,ios", f"""## Özet
RFC 5545 uyumlu ICS. Line folding 75 octet. TEXT escaping (\\\\, \\;, \\,, \\n). Geçersiz e-posta varsa ORGANIZER/ATTENDEE yazılmıyor. UTType.calendarEvent ile UIActivityViewController (Android Cat-10 fix).

## Android → iOS Karşılaştırma
| Özellik | Android | iOS |
|---|---|---|
| ICS | ✅ IcsGenerator.kt | ❌ Swift port yapılacak |
| MIME type | ⚠️ Yanlış (Cat-10) | ❌ UTType.calendarEvent yapılacak |
| E-posta validasyon | ⚠️ Yoktu | ❌ Regex kontrol yapılacak |

## İlgili Dosyalar
- `Domain/ICS/ICSGenerator.swift`
- `Tests/Unit/ICSGeneratorTests.swift`

## Tahmini Süre
**Uygulama:** ~3 saat
**Review:** ~20 dk

## Referans
- iOS_ARCHITECTURE.md §4
- Epic: #{e5}
- Android Bug Cat-10

## Doğrulama Checklist (Kapatmadan Önce)
- [ ] **Navigation** — N/A
- [ ] **OCR** — N/A
- [ ] **API Calls** — N/A
- [ ] **Local Storage** — Üretilen .ics iOS Calendar'da açılıyor
- [ ] **Error Handling** — Geçersiz email → ORGANIZER yok; hata throw ediliyor
- [ ] **Loading States** — N/A
- [ ] **Analytics** — N/A
- [ ] **Permissions** — N/A
""")

make("feat(mail): MailComposeView — şablon seçici, değişken çözümleme, ICS ek", "epic:5-mail,type:feat,ios", f"""## Özet
Şablon chip scroll, değişken çözümleme, eksik değişken uyarı banner. `[Etkinlik]` boşken ilgili cümle siliniyor (Android #116 fix). Takvim çakışma kırmızı gösteriliyor. MFMailComposeViewController wrapper.

## Android → iOS Karşılaştırma
| Özellik | Android | iOS |
|---|---|---|
| [Etkinlik] boş | ⚠️ Bozuk metin (#116) | ❌ Cümle silme yapılacak |
| Çakışma | ✅ Kırmızı highlight | ❌ Port yapılacak |
| MFMailCompose | ✅ Mevcut | ❌ UIViewControllerRepresentable yapılacak |

## İlgili Dosyalar
- `UI/Mail/MailComposeView.swift`
- `UI/Mail/MailComposeViewModel.swift`

## Tahmini Süre
**Uygulama:** ~5 saat
**Review:** ~30 dk

## Referans
- Epic: #{e5}
- Android: #116

## Doğrulama Checklist (Kapatmadan Önce)
- [ ] **Navigation** — contactID yoksa contact picker; ICS → UIActivityViewController
- [ ] **OCR** — N/A
- [ ] **API Calls** — N/A
- [ ] **Local Storage** — N/A
- [ ] **Error Handling** — [Etkinlik] boşken bozuk metin yok; eksik profil → banner
- [ ] **Loading States** — ICS üretimi async; gönder butonu disabled
- [ ] **Analytics** — N/A
- [ ] **Permissions** — N/A
""")

make("test(mail): ICSGeneratorTests — RFC 5545 doğrulama", "epic:5-mail,type:test,ios", f"""## Özet
RFC 5545 doğrulama: UTC format, 75 octet line folding, TEXT escaping, e-posta validasyon. %100 line coverage.

## İlgili Dosyalar
- `Tests/Unit/ICSGeneratorTests.swift`

## Tahmini Süre
**Uygulama:** ~2 saat
**Review:** ~15 dk

## Referans
- iOS_ARCHITECTURE.md §10
- Epic: #{e5}

## Doğrulama Checklist (Kapatmadan Önce)
- [ ] **Navigation** — N/A
- [ ] **OCR** — N/A
- [ ] **API Calls** — N/A
- [ ] **Local Storage** — N/A
- [ ] **Error Handling** — Tüm test case'ler geçiyor; %100 line coverage
- [ ] **Loading States** — N/A
- [ ] **Analytics** — N/A
- [ ] **Permissions** — N/A
""")

print("✓ Epic 5 tamamlandı")

# =============================================================================
# EPIC 6 — PROFILE + QR
# =============================================================================
print("\n▶ Epic 6 — Profile + QR...")

e6_url, e6 = make("Epic 6 — Profile + QR", "epic:6-profile,ios,epic", f"""## Özet
Kullanıcı profili Keychain'de. CoreImage QR üretimi. Boş profilde QR engelleniyor (Android #141 fix). OCR self-scan ile kendi kartından profil dolduruluyor.

## Android → iOS Karşılaştırma
| Özellik | Android | iOS |
|---|---|---|
| Profil depolama | ✅ EncryptedSharedPreferences | ❌ Keychain actor yapılacak |
| QR üretimi | ✅ ZXing | ❌ CoreImage.CIFilter yapılacak |
| Boş profil QR | ⚠️ Crash (#141) | ❌ Guard kontrol yapılacak |
| OCR self-scan | ✅ Mevcut | ❌ VisionOCRService yapılacak |

## İlgili Dosyalar
- `Data/Keychain/UserProfileStore.swift`
- `UI/Profile/ProfileView.swift`, `UI/Profile/ProfileViewModel.swift`

## Tahmini Süre
**Uygulama:** ~2 gün
**Review:** ~1 saat

## Referans
- iOS_ARCHITECTURE.md §5.4, §6
- Android: #141

## Doğrulama Checklist (Kapatmadan Önce)
- [ ] **Navigation** — QR sheet; Avatar picker; OCR self-scan akışı
- [ ] **OCR** — OCR self-scan alanları doğru dolduruyor
- [ ] **API Calls** — N/A
- [ ] **Local Storage** — Profil Keychain round-trip; PII UserDefaults'a gitmiyor
- [ ] **Error Handling** — Boş profilde QR butonu disabled/alert
- [ ] **Loading States** — N/A
- [ ] **Analytics** — N/A
- [ ] **Permissions** — Kamera (OCR self-scan); PhotosPicker (avatar)
""")

make("feat(profile): ProfileView + ProfileViewModel — Keychain'den okuma/yazma", "epic:6-profile,type:feat,ios", f"""## Özet
`ProfileView` + `ProfileViewModel`. `UserProfileStore` actor üzerinden async load/save. Avatar PhotosPicker veya kamera. OCR self-scan + CardParser ile kendi kartından profil dolduruluyor.

## Android → iOS Karşılaştırma
| Özellik | Android | iOS |
|---|---|---|
| Profil yükleme | ✅ PreferencesRepository | ❌ UserProfileStore actor yapılacak |
| OCR self-scan | ✅ Mevcut | ❌ VisionOCRService yapılacak |

## İlgili Dosyalar
- `UI/Profile/ProfileView.swift`, `UI/Profile/ProfileViewModel.swift`
- `Data/Keychain/UserProfileStore.swift`

## Tahmini Süre
**Uygulama:** ~4 saat
**Review:** ~30 dk

## Referans
- iOS_ARCHITECTURE.md §5.4
- Epic: #{e6}

## Doğrulama Checklist (Kapatmadan Önce)
- [ ] **Navigation** — N/A
- [ ] **OCR** — OCR self-scan alanları doğru dolduruyor
- [ ] **API Calls** — N/A
- [ ] **Local Storage** — Keychain round-trip; PII UserDefaults'a gitmiyor
- [ ] **Error Handling** — Kayıt hatası alert
- [ ] **Loading States** — N/A
- [ ] **Analytics** — N/A
- [ ] **Permissions** — Kamera PermissionCoordinator üzerinden
""")

make("feat(profile): QR kodu oluşturma ve paylaşma", "epic:6-profile,type:feat,ios", f"""## Özet
`CoreImage.CIFilter.qrCodeGenerator` ile vCard QR üretimi. HomeView'de sheet. UIActivityViewController ile paylaşma. Profil boşsa QR butonu engelleniyor (Android #141 fix).

## Android → iOS Karşılaştırma
| Özellik | Android | iOS |
|---|---|---|
| QR üretimi | ✅ ZXing | ❌ CoreImage.CIFilter yapılacak |
| Boş profil | ⚠️ Crash (#141) | ❌ Guard + disabled yapılacak |
| QR paylaşma | ✅ ShareCompat | ❌ UIActivityViewController yapılacak |

## İlgili Dosyalar
- `UI/Home/HomeView.swift` — QR sheet
- `UI/Profile/ProfileViewModel.swift` — QR üretim mantığı

## Tahmini Süre
**Uygulama:** ~2 saat
**Review:** ~20 dk

## Referans
- Epic: #{e6}
- Android: #141

## Doğrulama Checklist (Kapatmadan Önce)
- [ ] **Navigation** — QR sheet kapanma; Share → UIActivityViewController
- [ ] **OCR** — N/A
- [ ] **API Calls** — N/A
- [ ] **Local Storage** — N/A
- [ ] **Error Handling** — Boş profil → QR butonu disabled/alert
- [ ] **Loading States** — N/A
- [ ] **Analytics** — N/A
- [ ] **Permissions** — N/A
""")

print("✓ Epic 6 tamamlandı")

# =============================================================================
# EPIC 7 — SECURITY HARDENING
# =============================================================================
print("\n▶ Epic 7 — Security Hardening...")

e7_url, e7 = make("Epic 7 — Security Hardening", "epic:7-security,ios,epic", f"""## Özet
Android'de sonradan eklenen güvenlik önlemleri iOS'ta baştan var: Jailbreak detection, iCloud backup exclusion, scene blur (FLAG_SECURE), KVKK onay akışı, App Store Privacy Manifest, Bug Prevention Matrix doğrulaması.

## Android → iOS Karşılaştırma
| Özellik | Android | iOS |
|---|---|---|
| Root detection | ✅ SecurityUtils (#120) | ❌ JailbreakDetector yapılacak |
| FLAG_SECURE | ✅ Window flag (#119) | ❌ scenePhase overlay yapılacak |
| Backup exclusion | ✅ backup_rules.xml | ❌ isExcludedFromBackup yapılacak |
| Privacy Manifest | N/A (Android) | ❌ PrivacyInfo.xcprivacy yapılacak |

## İlgili Dosyalar
- `Security/JailbreakDetector.swift`
- `Security/ScreenshotProtection.swift`
- `PrivacyInfo.xcprivacy`

## Tahmini Süre
**Uygulama:** ~2 gün
**Review:** ~2 saat

## Referans
- iOS_ARCHITECTURE.md §7
- Android: #119, #120

## Doğrulama Checklist (Kapatmadan Önce)
- [ ] **Navigation** — Jailbreak dialog → "Devam Et" / "Çıkış"
- [ ] **OCR** — N/A
- [ ] **API Calls** — N/A
- [ ] **Local Storage** — photos/ ve DB isExcludedFromBackup=true
- [ ] **Error Handling** — N/A
- [ ] **Loading States** — N/A
- [ ] **Analytics** — N/A
- [ ] **Permissions** — Info.plist'te yalnızca kullanılan permission string'leri var
""")

make("feat(security): JailbreakDetector + uygulama açılış uyarısı", "epic:7-security,type:security,ios", f"""## Özet
Dosya varlığı, sandbox dışı yazma, dylib kontrolleri. Simulator'da false positive yok. Uygulama başında kontrol; jailbreak → non-blocking dialog.

## Android → iOS Karşılaştırma
| Özellik | Android | iOS |
|---|---|---|
| Root detection | ✅ SecurityUtils.kt | ❌ JailbreakDetector yapılacak |
| Emulator check | ✅ Build.FINGERPRINT | ❌ targetEnvironment(simulator) yapılacak |

## İlgili Dosyalar
- `Security/JailbreakDetector.swift`

## Tahmini Süre
**Uygulama:** ~2 saat
**Review:** ~20 dk

## Referans
- iOS_ARCHITECTURE.md §7.1
- Epic: #{e7}
- Android: #120

## Doğrulama Checklist (Kapatmadan Önce)
- [ ] **Navigation** — Jailbreak dialog → "Devam Et" / "Çıkış"
- [ ] **OCR** — N/A
- [ ] **API Calls** — N/A
- [ ] **Local Storage** — N/A
- [ ] **Error Handling** — Simulator'da false alarm yok
- [ ] **Loading States** — N/A
- [ ] **Analytics** — N/A
- [ ] **Permissions** — N/A
""")

make("feat(security): iCloud backup exclusion — photos, ics, vcf, DB", "epic:7-security,type:security,ios", f"""## Özet
photos/, ics/, vcf/ ve SwiftData DB dosyasına ilk açılışta `isExcludedFromBackup = true`. UserProfile Keychain'de; iCloud'a gitmiyor. `@AppStorage` onboarding flag'leri kasıtlı backup'a dahil.

## Android → iOS Karşılaştırma
| Özellik | Android | iOS |
|---|---|---|
| Backup exclusion | ✅ backup_rules.xml | ❌ URLResourceValues yapılacak |
| DB backup | ✅ Excluded | ❌ SwiftData db excluded yapılacak |

## İlgili Dosyalar
- `App/CardConnectApp.swift` — ilk açılış
- `Data/Photo/PhotoStorage.swift`

## Tahmini Süre
**Uygulama:** ~1 saat
**Review:** ~15 dk

## Referans
- iOS_ARCHITECTURE.md §7, §11
- Epic: #{e7}

## Doğrulama Checklist (Kapatmadan Önce)
- [ ] **Navigation** — N/A
- [ ] **OCR** — N/A
- [ ] **API Calls** — N/A
- [ ] **Local Storage** — photos/ isExcludedFromBackup=true; DB dosyası excluded
- [ ] **Error Handling** — setResourceValues hata → log + devam
- [ ] **Loading States** — N/A
- [ ] **Analytics** — N/A
- [ ] **Permissions** — N/A
""")

make("feat(security): Scene blur — inactive/background'da içerik gizleme", "epic:7-security,type:security,ios", f"""## Özet
`ScreenshotProtectionModifier`: `scenePhase == .inactive` → siyah overlay. App switcher thumbnail'da kişi bilgisi görünmüyor. FLAG_SECURE'un iOS karşılığı.

## Android → iOS Karşılaştırma
| Özellik | Android | iOS |
|---|---|---|
| FLAG_SECURE | ✅ Window flag (#119) | ❌ scenePhase + overlay yapılacak |

## İlgili Dosyalar
- `Security/ScreenshotProtection.swift`
- `UI/Navigation/RootNavigationView.swift`

## Tahmini Süre
**Uygulama:** ~30 dk
**Review:** ~10 dk

## Referans
- iOS_ARCHITECTURE.md §7.2
- Epic: #{e7}
- Android: #119

## Doğrulama Checklist (Kapatmadan Önce)
- [ ] **Navigation** — N/A
- [ ] **OCR** — N/A
- [ ] **API Calls** — N/A
- [ ] **Local Storage** — N/A
- [ ] **Error Handling** — N/A
- [ ] **Loading States** — N/A
- [ ] **Analytics** — N/A
- [ ] **Permissions** — N/A
""")

make("feat(security): PrivacyPolicyView + KVKK onay akışı", "epic:7-security,type:security,ios", f"""## Özet
`PrivacyPolicyView` + Onboarding son sayfasında KVKK checkbox. Onaylanmadan ProfileSetup'a geçilemiyor. Settings → gizlilik politikası linki.

## Android → iOS Karşılaştırma
| Özellik | Android | iOS |
|---|---|---|
| KVKK onay | ✅ Onboarding checkbox | ❌ SwiftUI Toggle yapılacak |
| Privacy screen | ✅ PrivacyPolicyScreen | ❌ SwiftUI port yapılacak |

## İlgili Dosyalar
- `UI/Settings/PrivacyPolicyView.swift`
- `UI/Onboarding/OnboardingView.swift`

## Tahmini Süre
**Uygulama:** ~2 saat
**Review:** ~15 dk

## Referans
- Epic: #{e7}

## Doğrulama Checklist (Kapatmadan Önce)
- [ ] **Navigation** — Settings → PrivacyPolicyView; Onboarding checkbox → ProfileSetup
- [ ] **OCR** — N/A
- [ ] **API Calls** — N/A
- [ ] **Local Storage** — privacy_accepted @AppStorage'a yazılıyor
- [ ] **Error Handling** — N/A
- [ ] **Loading States** — N/A
- [ ] **Analytics** — N/A
- [ ] **Permissions** — N/A
""")

make("chore(security): App Store hazırlık — Privacy Manifest + export compliance", "epic:7-security,type:chore,ios", f"""## Özet
`PrivacyInfo.xcprivacy`: NSFileSystemAPI, NSUserDefaultsAPI beyan ediliyor. App Store Connect'te şifreleme (Keychain AES) beyan. Info.plist'te yalnızca kullanılan permission string'leri mevcut.

## Android → iOS Karşılaştırma
| Özellik | Android | iOS |
|---|---|---|
| Permission audit | ✅ READ_CONTACTS unused → removed | ❌ SwiftLint plist audit kuralı yapılacak |
| Privacy beyan | N/A | ❌ PrivacyInfo.xcprivacy yapılacak |

## İlgili Dosyalar
- `PrivacyInfo.xcprivacy`
- `Info.plist`

## Tahmini Süre
**Uygulama:** ~2 saat
**Review:** ~20 dk

## Referans
- iOS_ARCHITECTURE.md §11
- Epic: #{e7}

## Doğrulama Checklist (Kapatmadan Önce)
- [ ] **Navigation** — N/A
- [ ] **OCR** — N/A
- [ ] **API Calls** — N/A
- [ ] **Local Storage** — N/A
- [ ] **Error Handling** — N/A
- [ ] **Loading States** — N/A
- [ ] **Analytics** — N/A
- [ ] **Permissions** — Xcode Privacy Report uyarısız; yalnızca kullanılan permission string'leri var
""")

make("chore(security): Security review — Bug Prevention Matrix doğrulama", "epic:7-security,type:security,ios", f"""## Özet
iOS_ARCHITECTURE.md §1 Bug Prevention Matrix'teki 14 maddenin tamamının uygulanmış olduğu doğrulanıyor. Her madde için kod incelemesi + otomatik test.

## Beklened Davranış
14/14 madde geçiyor; eksik varsa yeni issue açılıyor.

## İlgili Dosyalar
- iOS_ARCHITECTURE.md §1
- Tüm Domain/ ve Data/ dosyaları

## Tahmini Süre
**Uygulama:** ~3 saat
**Review:** ~1 saat

## Referans
- iOS_ARCHITECTURE.md §1
- Epic: #{e7}

## Doğrulama Checklist (Kapatmadan Önce)
- [ ] **Navigation** — N/A
- [ ] **OCR** — CardParser/VCardParser unit testleri geçiyor
- [ ] **API Calls** — N/A
- [ ] **Local Storage** — ContactStore LIKE query yok; ScanFlowActor isolation uyarısı yok
- [ ] **Error Handling** — N/A
- [ ] **Loading States** — N/A
- [ ] **Analytics** — N/A
- [ ] **Permissions** — PermissionCoordinator permanent denial loop yok
""")

print("✓ Epic 7 tamamlandı")

print(f"""
============================================================
✅ Tüm epic'ler ve issue'lar oluşturuldu
============================================================

Repo: https://github.com/{REPO}/issues
""")
if project_num:
    print(f"Project: https://github.com/users/tolgabarisalcitepe/projects/{project_num}")
