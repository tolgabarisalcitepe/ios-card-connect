#!/usr/bin/env bash
# =============================================================================
# create_ios_issues_final.sh
# Card Connect iOS — Epic + Issue yaratma scripti (GITHUB_ISSUE_STANDARD uyumlu)
# Repo: tolgabarisalcitepe/ios-card-connect
# =============================================================================

set -euo pipefail

REPO="tolgabarisalcitepe/ios-card-connect"
TMP="/tmp/cc_issue_body.md"

GREEN='\033[0;32m'; BLUE='\033[0;34m'; NC='\033[0m'
log()  { echo -e "${BLUE}▶ $*${NC}"; }
ok()   { echo -e "${GREEN}✓ $*${NC}"; }

# GitHub Project oluştur (varsa atla)
log "GitHub Project oluşturuluyor..."
PROJECT_URL=$(gh project create \
  --owner tolgabarisalcitepe \
  --title "Card Connect iOS — Backlog" \
  --format json 2>/dev/null | grep -o '"url":"[^"]*"' | head -1 | cut -d'"' -f4) || true

if [ -z "$PROJECT_URL" ]; then
  # Zaten varsa mevcut projeyi al
  PROJECT_NUMBER=$(gh project list --owner tolgabarisalcitepe --format json \
    | python3 -c "import sys,json; pl=json.load(sys.stdin)['projects']; \
      [print(p['number']) for p in pl if p['title']=='Card Connect iOS — Backlog']" 2>/dev/null | head -1) || true
else
  PROJECT_NUMBER=$(echo "$PROJECT_URL" | grep -oE '[0-9]+$') || true
fi
ok "Project hazır (number: ${PROJECT_NUMBER:-?})"

# Issue'yu projeye ekle
add_to_project() {
  local issue_url="$1"
  if [ -n "${PROJECT_NUMBER:-}" ]; then
    gh project item-add "$PROJECT_NUMBER" \
      --owner tolgabarisalcitepe \
      --url "$issue_url" 2>/dev/null || true
  fi
}

# =============================================================================
# LABELS
# =============================================================================
log "Label'lar yaratılıyor..."

create_label() {
  gh label create "$1" --color "$2" --description "$3" --repo "$REPO" --force 2>/dev/null || true
}

# Epic
create_label "epic:0-foundation"  "0052cc" "Epic 0 — Foundation"
create_label "epic:1-ocr"         "e4e669" "Epic 1 — OCR Pipeline"
create_label "epic:2-storage"     "0e8a16" "Epic 2 — Contact Storage"
create_label "epic:3-duplicate"   "b60205" "Epic 3 — Duplicate Flow"
create_label "epic:4-events"      "5319e7" "Epic 4 — Event Matching"
create_label "epic:5-mail"        "1d76db" "Epic 5 — Mail + Templates"
create_label "epic:6-profile"     "f9d0c4" "Epic 6 — Profile + QR"
create_label "epic:7-security"    "c5def5" "Epic 7 — Security Hardening"

# Type
create_label "type:feat"          "a2eeef" "New feature"
create_label "type:test"          "d93f0b" "Tests"
create_label "type:infra"         "e99695" "Infrastructure / DI / config"
create_label "type:security"      "b60205" "Security"
create_label "type:chore"         "ededed" "Chore / housekeeping"
create_label "ios"                "000000" "iOS"
create_label "epic"               "6f42c1" "Epic tracking issue"

ok "Label'lar hazır"

# =============================================================================
# HELPER
# =============================================================================
create_issue() {
  local title="$1"
  local labels="$2"
  # Body /tmp/cc_issue_body.md dosyasında
  local url
  url=$(gh issue create \
    --repo "$REPO" \
    --title "$title" \
    --body-file "$TMP" \
    --label "$labels")
  echo "$url"
}

# =============================================================================
# EPIC 0 — FOUNDATION
# =============================================================================
log "Epic 0 — Foundation..."

cat > "$TMP" << 'BODY'
## Özet
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

## Beklenen Davranış
Uygulama açılıyor → Onboarding → ProfileSetup → Home (boş state).

```swift
// ScanFlowActor — race condition'sız transient state
actor ScanFlowActor {
    private(set) var parsedCard: ParsedCard? = nil
    func setParsedCard(_ c: ParsedCard) { parsedCard = c }
    func reset() { parsedCard = nil; photoPaths = [] }
}

// AppRoute — compile-time güvenli navigation
enum AppRoute: Hashable {
    case onboarding, home, camera, confirm
    case duplicate(contactID: UUID)
    case eventMatch(contactID: UUID)
}
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
- iOS_ARCHITECTURE.md §3 (Project Structure)
- iOS_ARCHITECTURE.md §5.1 (SwiftData)
- iOS_ARCHITECTURE.md §5.2 (ScanFlowActor)
- iOS_ARCHITECTURE.md §8 (Navigation)
- iOS_ARCHITECTURE.md §9 (Permission Handling)

## Doğrulama Checklist (Kapatmadan Önce)
- [ ] **Navigation** — Onboarding → ProfileSetup → Home akışı çalışıyor; back stack doğru
- [ ] **OCR** — N/A (bu epic'te kamera yok)
- [ ] **API Calls** — N/A (internet yok)
- [ ] **Local Storage** — SwiftData insert/fetch round-trip çalışıyor; DB şifrelenmiş
- [ ] **Error Handling** — Keychain okuma hatası graceful handle ediliyor
- [ ] **Loading States** — N/A
- [ ] **Analytics** — N/A
- [ ] **Permissions** — PermissionCoordinator permanent denial → Settings yönlendirmesi çalışıyor
BODY

E0_URL=$(create_issue "Epic 0 — Foundation" "epic:0-foundation,ios,epic")
E0_NUM=$(echo "$E0_URL" | grep -oE '[0-9]+$')
add_to_project "$E0_URL"
ok "Epic 0 → #$E0_NUM ($E0_URL)"

# --- E0 Child Issues ---

cat > "$TMP" << BODY
## Özet
\`SchemaV1\` SwiftData modelleri tanımlanıyor. \`ContactStore\` actor ile CRUD operasyonları (\`insert\`, \`update\`, \`delete\`, \`fetchAll\`, \`fetchById\`, \`search\`, \`findDuplicate\`) implement ediliyor. DB Keychain'den alınan 32-byte key ile SQLite pragma üzerinden şifreleniyor.

## Android → iOS Karşılaştırma
| Özellik | Android | iOS |
|---|---|---|
| ORM | ✅ Room + SQLCipher | ❌ SwiftData + Keychain key yapılacak |
| Entity tanımı | ✅ @Entity data class | ❌ @Model class (SchemaV1) yapılacak |
| DB actor | ✅ Coroutine Dispatchers.IO | ❌ @ModelActor yapılacak |
| Duplicate query | ⚠️ LIKE wildcard (Cat-5 bug) | ❌ #Predicate == exact match yapılacak |
| iCloud backup | ❌ N/A | ❌ isExcludedFromBackup yapılacak |

## Beklenen Davranış
\`ContactStore\` in-memory \`ModelConfiguration\` ile test edilebilir; CRUD round-trip çalışıyor.

\`\`\`swift
@ModelActor
actor ContactStore: ContactStoreProtocol {
    func insert(_ contact: Contact) throws {
        modelContext.insert(contact.toModel())
        try modelContext.save()
    }
    func findDuplicate(firstName: String, lastName: String, company: String,
                       phones: [String], emails: [String]) throws -> Contact? {
        // #Predicate ile == , LIKE yok (Cat-5 fix)
        let fn = firstName.lowercased()
        if let m = try modelContext.fetch(
            FetchDescriptor<SchemaV1.ContactModel>(
                predicate: #Predicate { \$0.firstName.lowercased() == fn }
            )
        ).first { return m.toDomain() }
        return nil
    }
}
\`\`\`

## İlgili Dosyalar
- \`Data/Persistence/Schema/SchemaV1.swift\` — ContactModel, EmailTemplateModel
- \`Data/Persistence/Schema/SchemaV2.swift\` — boş migration şablonu
- \`Data/Persistence/ContactStore.swift\` — @ModelActor
- \`Data/Persistence/ContactStoreProtocol.swift\` — mock-friendly protocol
- \`Tests/Unit/ContactStoreTests.swift\`

## Tahmini Süre
**Uygulama:** ~4 saat
**Review:** ~30 dk

## Referans
- iOS_ARCHITECTURE.md §5.1
- Epic: #$E0_NUM
- Android Bug Cat-5 (LIKE injection), Cat-6 (field limits)

## Doğrulama Checklist (Kapatmadan Önce)
- [ ] **Navigation** — N/A
- [ ] **OCR** — N/A
- [ ] **API Calls** — N/A
- [ ] **Local Storage** — insert → fetchById round-trip testi geçiyor; DB dosyası isExcludedFromBackup=true
- [ ] **Error Handling** — ModelContext.save() hatası yakalanıyor
- [ ] **Loading States** — N/A
- [ ] **Analytics** — N/A
- [ ] **Permissions** — N/A
BODY
I_URL=$(create_issue "feat(foundation): SwiftData stack — SchemaV1 + Keychain-encrypted DB" "epic:0-foundation,type:infra,ios")
add_to_project "$I_URL"; ok "  → $(echo $I_URL | grep -oE '[0-9]+$')"

cat > "$TMP" << BODY
## Özet
\`KeychainStore\` ile generic Keychain CRUD implement ediliyor. \`UserProfileStore\` actor olarak UserProfile'ı JSON encode ederek Keychain'de saklıyor. DB passphrase key'i de aynı store üzerinden yönetiliyor.

## Android → iOS Karşılaştırma
| Özellik | Android | iOS |
|---|---|---|
| Profil depolama | ✅ EncryptedSharedPreferences | ❌ Keychain + JSON yapılacak |
| Thread safety | ⚠️ Callback any thread (Cat-8) | ❌ actor + @MainActor yapılacak |
| DB key | ✅ SQLCipher passphrase | ❌ Keychain'den 32-byte key yapılacak |

## Beklened Davranış
\`UserProfileStore.save() → load()\` round-trip'i doğrulayan unit test geçiyor.

\`\`\`swift
actor UserProfileStore {
    private let key = "com.cardconnect.userprofile"
    func save(_ profile: UserProfile) async throws {
        let data = try JSONEncoder().encode(profile)
        try KeychainStore.save(key: key, data: data)
    }
    func load() async -> UserProfile {
        guard let data = try? KeychainStore.load(key: key),
              let p = try? JSONDecoder().decode(UserProfile.self, from: data)
        else { return UserProfile() }
        return p
    }
}
\`\`\`

## İlgili Dosyalar
- \`Data/Keychain/KeychainStore.swift\` — save/load/delete
- \`Data/Keychain/UserProfileStore.swift\` — actor, JSON

## Tahmini Süre
**Uygulama:** ~2 saat
**Review:** ~20 dk

## Referans
- iOS_ARCHITECTURE.md §5.3, §5.4
- Epic: #$E0_NUM
- Android Bug Cat-8 (thread safety of prefs)

## Doğrulama Checklist (Kapatmadan Önce)
- [ ] **Navigation** — N/A
- [ ] **OCR** — N/A
- [ ] **API Calls** — N/A
- [ ] **Local Storage** — Keychain item kSecClassGenericPassword olarak yazılıyor; round-trip testi geçiyor
- [ ] **Error Handling** — Keychain corruption → yeni key üret + DB sıfırla
- [ ] **Loading States** — N/A
- [ ] **Analytics** — N/A
- [ ] **Permissions** — N/A
BODY
I_URL=$(create_issue "feat(foundation): KeychainStore + UserProfileStore" "epic:0-foundation,type:infra,ios")
add_to_project "$I_URL"; ok "  → $(echo $I_URL | grep -oE '[0-9]+$')"

cat > "$TMP" << BODY
## Özet
\`DependencyContainer\` protocol + live implementasyonu yazılıyor. Her ViewModel sadece ihtiyacı olan protokolü constructor injection ile alıyor. Android'deki AppContainer god-object anti-pattern'i ortadan kaldırılıyor.

## Android → iOS Karşılaştırma
| Özellik | Android | iOS |
|---|---|---|
| DI | ⚠️ AppContainer god-object | ❌ DependencyContainer protocol yapılacak |
| ViewModel bağımlılığı | ⚠️ Application cast via factory | ❌ init injection yapılacak |
| Test edilebilirlik | ⚠️ Zor (AppContainer mock gerekir) | ❌ Mock protocol ile kolay yapılacak |

## Beklened Davranış
Mock \`DependencyContainer\` ile herhangi bir ViewModel unit test çalışıyor; \`Application\` cast yok.

\`\`\`swift
protocol DependencyContainer {
    var contactStore: ContactStoreProtocol { get }
    var scanFlow: ScanFlowActor { get }
    var permissionCoordinator: PermissionCoordinator { get }
    var userProfileStore: UserProfileStore { get }
}
\`\`\`

## İlgili Dosyalar
- \`App/DependencyContainer.swift\`
- \`App/CardConnectApp.swift\` — @StateObject wiring

## Tahmini Süre
**Uygulama:** ~2 saat
**Review:** ~20 dk

## Referans
- iOS_ARCHITECTURE.md §2 (DI)
- Epic: #$E0_NUM
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
BODY
I_URL=$(create_issue "feat(foundation): DependencyContainer + @Environment wiring" "epic:0-foundation,type:infra,ios")
add_to_project "$I_URL"; ok "  → $(echo $I_URL | grep -oE '[0-9]+$')"

cat > "$TMP" << BODY
## Özet
\`enum AppRoute: Hashable\` ile tüm ekran geçişleri tip-güvenli hale getiriliyor. \`NavigationStack<AppRoute>\` kurulumu ve \`.vcf\` dosyası açıldığında \`AppRoute.confirm\`'e yönlendirme ekleniyor.

## Android → iOS Karşılaştırma
| Özellik | Android | iOS |
|---|---|---|
| Navigation | ⚠️ String route → runtime crash | ❌ AppRoute enum (compile-time) yapılacak |
| Deep link / intent | ✅ SplashActivity ACTION_VIEW | ❌ onOpenURL + Info.plist UTI yapılacak |
| Tab bar | ✅ Bottom nav | ❌ TabView yapılacak |

## Beklened Davranış
Typo → compile error. \`.vcf\` dosya açıldığında ConfirmView görünüyor.

\`\`\`swift
enum AppRoute: Hashable {
    case onboarding, profileSetup, home, contacts
    case camera, confirm
    case duplicate(contactID: UUID)
    case eventMatch(contactID: UUID)
    case detail(contactID: UUID)
    case contactEdit(contactID: UUID)
    case mailCompose(contactID: UUID?)
    case templates, templateEdit(templateID: UUID), templateNew
    case profile, settings, privacyPolicy
}
\`\`\`

## İlgili Dosyalar
- \`UI/Navigation/AppRoute.swift\`
- \`UI/Navigation/RootNavigationView.swift\`
- \`App/CardConnectApp.swift\` — onOpenURL

## Tahmini Süre
**Uygulama:** ~3 saat
**Review:** ~30 dk

## Referans
- iOS_ARCHITECTURE.md §8
- Epic: #$E0_NUM
- Android Bug Cat-3 (process death nav recovery)

## Doğrulama Checklist (Kapatmadan Önce)
- [ ] **Navigation** — .vcf dosyası uygulamaya açıldığında ConfirmView görünüyor; tüm AppRoute case'leri bağlanmış
- [ ] **OCR** — N/A
- [ ] **API Calls** — N/A
- [ ] **Local Storage** — N/A
- [ ] **Error Handling** — Bilinmeyen UTI → sessizce görmezden geliniyor
- [ ] **Loading States** — N/A
- [ ] **Analytics** — N/A
- [ ] **Permissions** — N/A
BODY
I_URL=$(create_issue "feat(foundation): NavigationStack + AppRoute enum (typed routes)" "epic:0-foundation,type:feat,ios")
add_to_project "$I_URL"; ok "  → $(echo $I_URL | grep -oE '[0-9]+$')"

cat > "$TMP" << BODY
## Özet
\`ScanFlowActor\` Swift actor olarak implement ediliyor; Camera → Confirm → Duplicate → EventMatch akışındaki tüm geçici state bu actor üzerinden yönetiliyor. Android'deki \`AppContainer\` mutable state race condition (Cat-1) ve stale state (Cat-2) bug'ları yapısal olarak önleniyor.

## Android → iOS Karşılaştırma
| Özellik | Android | iOS |
|---|---|---|
| Scan state saklama | ⚠️ AppContainer MutableList (race) | ❌ ScanFlowActor (actor isolation) yapılacak |
| State temizleme | ⚠️ pendingParsedCard asla temizlenmiyordu | ❌ reset() atomik çağrısı yapılacak |

## Beklened Davranış
İki eş zamanlı Task aynı anda yazarken data race yok; \`reset()\` sonrası tüm alanlar nil/empty.

\`\`\`swift
actor ScanFlowActor {
    private(set) var photoPaths:  [URL]       = []
    private(set) var parsedCard:  ParsedCard? = nil
    private(set) var contactID:   UUID?       = nil
    private(set) var incomingVCard: String?   = nil

    func setPhotoPaths(_ paths: [URL]) { photoPaths = paths }
    func setParsedCard(_ card: ParsedCard) { parsedCard = card }
    func setContactID(_ id: UUID) { contactID = id }
    func setIncomingVCard(_ text: String) { incomingVCard = text }
    func reset() { photoPaths = []; parsedCard = nil; contactID = nil; incomingVCard = nil }
}
\`\`\`

## İlgili Dosyalar
- \`Data/Persistence/ScanFlowActor.swift\`
- \`Tests/Unit/ScanFlowActorTests.swift\` — concurrent access testi

## Tahmini Süre
**Uygulama:** ~1 saat
**Review:** ~20 dk

## Referans
- iOS_ARCHITECTURE.md §5.2
- Epic: #$E0_NUM
- Android Bug Cat-1 (race condition), Cat-2 (stale pending state)

## Doğrulama Checklist (Kapatmadan Önce)
- [ ] **Navigation** — N/A
- [ ] **OCR** — N/A
- [ ] **API Calls** — N/A
- [ ] **Local Storage** — reset() sonrası parsedCard nil
- [ ] **Error Handling** — N/A
- [ ] **Loading States** — N/A
- [ ] **Analytics** — N/A
- [ ] **Permissions** — N/A
BODY
I_URL=$(create_issue "feat(foundation): ScanFlowActor — thread-safe transient scan state" "epic:0-foundation,type:infra,ios")
add_to_project "$I_URL"; ok "  → $(echo $I_URL | grep -oE '[0-9]+$')"

cat > "$TMP" << BODY
## Özet
\`PermissionCoordinator\` implement ediliyor: kamera, rehber ve takvim izinleri tek yerden yönetiliyor. Kalıcı redde (\`.permanentlyDenied\`) ulaşıldığında uygulama Settings'e yönlendiriyor; \`requestAccess\` asla tekrar çağrılmıyor. Android Cat-7 permission loop bug'ı yapısal olarak önleniyor.

## Android → iOS Karşılaştırma
| Özellik | Android | iOS |
|---|---|---|
| İzin döngüsü | ⚠️ shouldShowRationale loop (Cat-7) | ❌ denial count @AppStorage tracking yapılacak |
| Settings yönlendirme | ⚠️ Bazen çalışmıyordu | ❌ UIApplication.openSettingsURLString yapılacak |
| Permission rationale | ✅ Mevcut | ❌ PermissionRationaleSheet component yapılacak |

## Beklened Davranış
\`.permanentlyDenied\` sonrası \`requestAccess\` çağrılmıyor; "Ayarlara Git" butonu görünüyor.

\`\`\`swift
@MainActor
final class PermissionCoordinator: ObservableObject {
    enum PermResult { case granted, denied, permanentlyDenied }

    func requestCamera() async -> PermResult {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return .granted
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video) ? .granted : .denied
        case .denied, .restricted: return .permanentlyDenied
        @unknown default: return .denied
        }
    }
    func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
\`\`\`

## İlgili Dosyalar
- \`Data/Permissions/PermissionCoordinator.swift\`
- \`UI/Components/PermissionRationaleSheet.swift\`

## Tahmini Süre
**Uygulama:** ~2 saat
**Review:** ~20 dk

## Referans
- iOS_ARCHITECTURE.md §9
- Epic: #$E0_NUM
- Android Bug Cat-7 (permission loop)

## Doğrulama Checklist (Kapatmadan Önce)
- [ ] **Navigation** — N/A
- [ ] **OCR** — N/A
- [ ] **API Calls** — N/A
- [ ] **Local Storage** — denial count @AppStorage'a yazılıyor
- [ ] **Error Handling** — İzin isteği exception atarsa graceful handle ediliyor
- [ ] **Loading States** — İzin diyalogu açıkken buton disabled
- [ ] **Analytics** — N/A
- [ ] **Permissions** — requestAccess, .denied sonrası bir daha çağrılmıyor; permanentlyDenied → Settings
BODY
I_URL=$(create_issue "feat(foundation): PermissionCoordinator — kamera, rehber, takvim" "epic:0-foundation,type:feat,ios")
add_to_project "$I_URL"; ok "  → $(echo $I_URL | grep -oE '[0-9]+$')"

cat > "$TMP" << BODY
## Özet
Onboarding (3 sayfa SwiftUI TabView), ProfileSetup ve boş HomeView ekranları implement ediliyor. Privacy checkbox onaylanmadan ilerlenemiyor. Uygulama background'a geçince içerik siyah overlay ile gizleniyor (FLAG_SECURE karşılığı).

## Android → iOS Karşılaştırma
| Özellik | Android | iOS |
|---|---|---|
| Onboarding | ✅ 3 sayfa ViewPager | ❌ TabView(.page) yapılacak |
| Privacy checkbox | ✅ KVKK checkbox | ❌ SwiftUI Toggle yapılacak |
| FLAG_SECURE | ✅ MainActivity window flag | ❌ scenePhase overlay yapılacak |
| ProfileSetup | ✅ Mevcut | ❌ SwiftUI port yapılacak |

## Beklened Davranış
Onboarding → ProfileSetup → Home akışı. App switcher'da içerik görünmüyor.

\`\`\`swift
struct ScreenshotProtectionModifier: ViewModifier {
    @Environment(\\.scenePhase) private var phase
    func body(content: Content) -> some View {
        content.overlay {
            if phase == .inactive { Color.black.ignoresSafeArea() }
        }
    }
}
\`\`\`

## İlgili Dosyalar
- \`UI/Onboarding/OnboardingView.swift\`
- \`UI/ProfileSetup/ProfileSetupView.swift\`
- \`UI/Home/HomeView.swift\`
- \`Security/ScreenshotProtection.swift\`

## Tahmini Süre
**Uygulama:** ~4 saat
**Review:** ~30 dk

## Referans
- iOS_ARCHITECTURE.md §7.2
- Epic: #$E0_NUM
- Android: FLAG_SECURE (#119)

## Doğrulama Checklist (Kapatmadan Önce)
- [ ] **Navigation** — Onboarding → ProfileSetup → Home akışı çalışıyor; Skip butonu 1. ve 2. sayfada var
- [ ] **OCR** — N/A
- [ ] **API Calls** — N/A
- [ ] **Local Storage** — onboarding_done ve privacy_accepted @AppStorage'a yazılıyor
- [ ] **Error Handling** — N/A
- [ ] **Loading States** — N/A
- [ ] **Analytics** — N/A
- [ ] **Permissions** — N/A
BODY
I_URL=$(create_issue "feat(foundation): Onboarding + ProfileSetup + HomeView (boş)" "epic:0-foundation,type:feat,ios")
add_to_project "$I_URL"; ok "  → $(echo $I_URL | grep -oE '[0-9]+$')"

ok "Epic 0 tamamlandı"

# =============================================================================
# EPIC 1 — OCR PIPELINE
# =============================================================================
log "Epic 1 — OCR Pipeline..."

cat > "$TMP" << BODY
## Özet
Kartvizit çekiminden (kamera veya galeri), OCR işleme, alan çıkarma ve kullanıcıya onay formu sunmaya kadar tüm scan pipeline'ı çalışıyor. Android'deki iki ayrı VCardParser implementasyonu tek dosyaya indirgeniyor.

## Android → iOS Karşılaştırma
| Özellik | Android | iOS |
|---|---|---|
| OCR engine | ✅ ML Kit (on-device) | ❌ VisionKit VNRecognizeTextRequest yapılacak |
| QR tarama | ✅ ML Kit Barcode | ❌ DataScannerViewController yapılacak |
| CardParser | ✅ Kotlin regex | ❌ Swift NSRegularExpression port yapılacak |
| VCardParser | ⚠️ 2 ayrı impl (Cat-9 bug) | ❌ Tek impl + ParseSource enum yapılacak |
| ConfirmView form | ✅ Compose | ❌ SwiftUI port yapılacak |
| Process death recovery | ⚠️ Yoktu (Cat-3) | ❌ @SceneStorage draft yapılacak |

## Beklened Davranış
Kart çekiliyor → OCR → CardParser → ConfirmView'de alanlar dolu. QR taranıyor → VCardParser → ConfirmView.

## İlgili Dosyalar
- \`Domain/OCR/CardParser.swift\`
- \`Domain/OCR/VisionOCRService.swift\`
- \`Domain/VCard/VCardParser.swift\`
- \`Domain/Validation/URLValidator.swift\`
- \`UI/Camera/CameraView.swift\`
- \`UI/Camera/CameraViewModel.swift\`
- \`UI/Confirm/ConfirmView.swift\`
- \`UI/Confirm/ConfirmViewModel.swift\`

## Tahmini Süre
**Uygulama:** ~5 gün
**Review:** ~3 saat

## Referans
- iOS_ARCHITECTURE.md §4.5, §4.6, §6
- Android Bug Cat-4 (URI injection), Cat-9 (duplicate VCardParser)

## Doğrulama Checklist (Kapatmadan Önce)
- [ ] **Navigation** — QR vCard → ConfirmView; non-vCard QR → alert; Yeniden Çek → CameraView
- [ ] **OCR** — Gerçek kartvizit görüntüsünde isim + telefon çıkarılıyor; 8192 char clamp çalışıyor
- [ ] **API Calls** — N/A (on-device)
- [ ] **Local Storage** — @SceneStorage ile form draft process kill sonrası korunuyor
- [ ] **Error Handling** — OCR başarısız → boş form açılıyor, crash yok
- [ ] **Loading States** — OCR işlemi süresince spinner; Kaydet butonu async tamamlanana kadar disabled
- [ ] **Analytics** — N/A
- [ ] **Permissions** — Kamera izni PermissionCoordinator üzerinden; reddedilince Settings deep link
BODY
E1_URL=$(create_issue "Epic 1 — OCR Pipeline" "epic:1-ocr,ios,epic")
E1_NUM=$(echo "$E1_URL" | grep -oE '[0-9]+$')
add_to_project "$E1_URL"
ok "Epic 1 → #$E1_NUM"

cat > "$TMP" << BODY
## Özet
\`AVCaptureSession\` ile ön + arka kart fotoğrafı çekimi, \`DataScannerViewController\` ile QR tarama, galeri picker alternatifi ve non-vCard QR reddi implement ediliyor.

## Android → iOS Karşılaştırma
| Özellik | Android | iOS |
|---|---|---|
| Kamera preview | ✅ CameraX | ❌ AVCaptureSession yapılacak |
| Çift fotoğraf | ✅ Ön + arka, "---" merge | ❌ Aynı mantık yapılacak |
| QR tarama | ✅ ML Kit ImageAnalysis | ❌ DataScannerViewController yapılacak |
| Non-vCard red | ✅ Snackbar | ❌ .alert yapılacak |
| Galeri picker | ✅ ActivityResultContracts | ❌ PhotosPicker yapılacak |

## Beklened Davranış
vCard QR → ConfirmView. Non-vCard QR → alert. Kart fotoğrafı → ScanFlowActor'a kaydediliyor.

\`\`\`swift
struct CameraView: View {
    @StateObject private var vm: CameraViewModel
    @State private var mode: CaptureMode = .card
    enum CaptureMode { case card, qr }

    var body: some View {
        ZStack {
            if mode == .card { CardCaptureView(onPhotosTaken: vm.storePhotoPaths) }
            else { DataScannerRepresentable(onQRDetected: vm.handleQRCode) }
        }
        .task { await vm.requestCameraPermission() }
    }
}
\`\`\`

## İlgili Dosyalar
- \`UI/Camera/CameraView.swift\`
- \`UI/Camera/CameraViewModel.swift\`
- \`UI/Camera/DataScannerView.swift\` — UIViewControllerRepresentable

## Tahmini Süre
**Uygulama:** ~6 saat
**Review:** ~45 dk

## Referans
- iOS_ARCHITECTURE.md §6 (CameraView detail)
- Epic: #$E1_NUM

## Doğrulama Checklist (Kapatmadan Önce)
- [ ] **Navigation** — vCard QR → ConfirmView; Yeniden Çek → CameraView; back stack doğru
- [ ] **OCR** — Kart fotoğrafı ScanFlowActor.photoPaths'e kaydediliyor; ön/arka "---" ile merge ediliyor
- [ ] **API Calls** — N/A
- [ ] **Local Storage** — N/A
- [ ] **Error Handling** — Non-vCard QR → alert; kamera başlatma hatası graceful
- [ ] **Loading States** — Capture butonu işlem sırasında disabled
- [ ] **Analytics** — N/A
- [ ] **Permissions** — Kamera izni .permanentlyDenied → Settings linki
BODY
I_URL=$(create_issue "feat(ocr): CameraView — AVFoundation card capture + QR DataScanner" "epic:1-ocr,type:feat,ios")
add_to_project "$I_URL"; ok "  → $(echo $I_URL | grep -oE '[0-9]+$')"

cat > "$TMP" << BODY
## Özet
\`VNRecognizeTextRequest\` async wrapper olarak implement ediliyor. Türkçe + İngilizce dil tanıma desteği ekleniyor. İki görüntüden gelen OCR text'i "---" separator ile merge ediliyor ve 8192 karakter ile sınırlandırılıyor.

## Android → iOS Karşılaştırma
| Özellik | Android | iOS |
|---|---|---|
| OCR | ✅ ML Kit TextRecognition | ❌ VNRecognizeTextRequest yapılacak |
| Dil desteği | ✅ Latin script | ❌ tr-TR + en-US yapılacak |
| Input cap | ✅ 8192 char | ❌ FieldLimits.maxOCRInput yapılacak |
| Çift görüntü merge | ✅ "---" separator | ❌ Aynı yapılacak |

## Beklened Davranış
\`VisionOCRService.recognizeText(from: [CGImage]) async throws -> String\` — iki görüntüyü merge eder.

## İlgili Dosyalar
- \`Domain/OCR/VisionOCRService.swift\`
- \`Domain/Validation/FieldLimits.swift\`

## Tahmini Süre
**Uygulama:** ~3 saat
**Review:** ~20 dk

## Referans
- iOS_ARCHITECTURE.md §2 (VisionKit)
- Epic: #$E1_NUM

## Doğrulama Checklist (Kapatmadan Önce)
- [ ] **Navigation** — N/A
- [ ] **OCR** — Gerçek kartvizit görüntüsünde isim çıkarılıyor; 8192 üzeri input clamp'leniyor
- [ ] **API Calls** — N/A (on-device)
- [ ] **Local Storage** — N/A
- [ ] **Error Handling** — VNRequest hatası VisionOCRError olarak iletiliyor
- [ ] **Loading States** — N/A
- [ ] **Analytics** — N/A
- [ ] **Permissions** — N/A
BODY
I_URL=$(create_issue "feat(ocr): VisionOCRService — VNRecognizeTextRequest wrapper" "epic:1-ocr,type:feat,ios")
add_to_project "$I_URL"; ok "  → $(echo $I_URL | grep -oE '[0-9]+$')"

cat > "$TMP" << BODY
## Özet
Android'deki \`CardParser.kt\` Swift'e port ediliyor. Tüm Kotlin regex'leri \`NSRegularExpression\` ile replace ediliyor. Türkçe karakter desteği, faks hariç tutma, ters isim formatı, şirket suffix tanıma ve LinkedIn URL normalizasyonu dahil.

## Android → iOS Karşılaştırma
| Özellik | Android | iOS |
|---|---|---|
| Regex | ✅ Kotlin Regex | ❌ NSRegularExpression port yapılacak |
| Türkçe chars | ✅ | ❌ NSRegularExpression .caseInsensitive + Unicode yapılacak |
| Faks hariç | ✅ | ❌ Port yapılacak |
| Ters isim | ✅ SOYAD Ad | ❌ Port yapılacak |
| LinkedIn | ✅ | ❌ URLValidator.normalizeLinkedIn yapılacak |

## Beklened Davranış
\`CardParser.parseCardText("Ali Veli\\nCEO\\nTech A.Ş.\\nali@tech.com")\` → \`ParsedCard(firstName: "Ali", lastName: "Veli", ...)\`

## İlgili Dosyalar
- \`Domain/OCR/CardParser.swift\`
- \`Domain/Model/ParsedCard.swift\`
- \`Domain/Validation/URLValidator.swift\`
- \`Tests/Unit/CardParserTests.swift\`

## Tahmini Süre
**Uygulama:** ~5 saat
**Review:** ~45 dk

## Referans
- iOS_ARCHITECTURE.md §4.6
- Epic: #$E1_NUM
- Android: \`domain/ocr/CardParser.kt\`

## Doğrulama Checklist (Kapatmadan Önce)
- [ ] **Navigation** — N/A
- [ ] **OCR** — Tüm CardParserTests geçiyor; parseCardText("") crash yapmıyor
- [ ] **API Calls** — N/A
- [ ] **Local Storage** — N/A
- [ ] **Error Handling** — Nil/empty input → boş ParsedCard döndürülüyor
- [ ] **Loading States** — N/A
- [ ] **Analytics** — N/A
- [ ] **Permissions** — N/A
BODY
I_URL=$(create_issue "feat(ocr): CardParser — Kotlin'den Swift'e port" "epic:1-ocr,type:feat,ios")
add_to_project "$I_URL"; ok "  → $(echo $I_URL | grep -oE '[0-9]+$')"

cat > "$TMP" << BODY
## Özet
Android'de iki ayrı VCardParser (domain/vcf ve domain/vcard) diverge etmişti. iOS'ta tek \`VCardParser\` + \`ParseSource\` enum ile bu sorun yapısal olarak önleniyor. RFC 6350 line unfolding her iki source'ta uygulanıyor. LinkedIn domain validation zorunlu.

## Android → iOS Karşılaştırma
| Özellik | Android | iOS |
|---|---|---|
| Parser sayısı | ⚠️ 2 ayrı impl (Cat-9 bug) | ❌ Tek impl + ParseSource enum yapılacak |
| RFC 6350 unfold | ⚠️ Yalnızca biri uyguluyordu | ❌ Her iki source'ta da yapılacak |
| URI injection | ⚠️ Domain check yoktu (Cat-4) | ❌ URLValidator.validateLinkedIn yapılacak |
| Dosya boyut limiti | ✅ 16384 bytes | ❌ FieldLimits.maxVCard yapılacak |

## Beklened Davranış
\`VCardParser.parse(.file(url))\` ve \`VCardParser.parse(.string(vcf))\` aynı unfold mantığını kullanıyor. evil.com URL reddediliyor.

\`\`\`swift
enum ParseSource { case file(URL); case string(String) }
struct VCardParser {
    static func parse(_ source: ParseSource) throws -> ParsedCard {
        // Her iki source için aynı unfold + parse
    }
}
\`\`\`

## İlgili Dosyalar
- \`Domain/VCard/VCardParser.swift\`
- \`Domain/Validation/URLValidator.swift\`
- \`Tests/Unit/VCardParserTests.swift\`

## Tahmini Süre
**Uygulama:** ~4 saat
**Review:** ~30 dk

## Referans
- iOS_ARCHITECTURE.md §4.5
- Epic: #$E1_NUM
- Android Bug Cat-9 (duplicate VCardParser), Cat-4 (URI injection)

## Doğrulama Checklist (Kapatmadan Önce)
- [ ] **Navigation** — N/A
- [ ] **OCR** — N/A
- [ ] **API Calls** — N/A
- [ ] **Local Storage** — N/A
- [ ] **Error Handling** — 16384 byte üzeri → VCardError.tooLarge; malformed vCard → boş ParsedCard
- [ ] **Loading States** — N/A
- [ ] **Analytics** — N/A
- [ ] **Permissions** — N/A
BODY
I_URL=$(create_issue "feat(ocr): VCardParser — tek impl, ParseSource enum, RFC 6350 unfold" "epic:1-ocr,type:feat,ios")
add_to_project "$I_URL"; ok "  → $(echo $I_URL | grep -oE '[0-9]+$')"

cat > "$TMP" << BODY
## Özet
\`ConfirmView\` — TabView fotoğraf pager, düzenlenebilir form (ad, soyad, şirket, ünvan, telefon/lar, e-posta/lar, adres, LinkedIn, not). Dinamik satır ekleme/silme. QR kaynak uyarı banner. Form draft \`@SceneStorage\` ile process death'e karşı korunuyor (Android Cat-3 fix).

## Android → iOS Karşılaştırma
| Özellik | Android | iOS |
|---|---|---|
| Fotoğraf pager | ✅ ViewPager | ❌ TabView yapılacak |
| Dinamik satırlar | ✅ LazyColumn + add/remove | ❌ ForEach + DynamicMember yapılacak |
| QR uyarı banner | ✅ Mevcut | ❌ Port yapılacak |
| Process death | ⚠️ Yoktu (Cat-3) | ❌ @SceneStorage draft yapılacak |
| WRITE_CONTACTS | ✅ Save öncesi isteniyordu | ❌ PermissionCoordinator yapılacak |

## Beklened Davranış
Form doldurulup save'e basılıyor → ContactStore'a yazılıyor → DuplicateView'e geçiliyor. Process kill sonrası form içeriği korunuyor.

## İlgili Dosyalar
- \`UI/Confirm/ConfirmView.swift\`
- \`UI/Confirm/ConfirmViewModel.swift\`
- \`UI/Components/PhoneEmailRowView.swift\`

## Tahmini Süre
**Uygulama:** ~6 saat
**Review:** ~45 dk

## Referans
- iOS_ARCHITECTURE.md §6
- Epic: #$E1_NUM
- Android Bug Cat-3 (process death recovery)

## Doğrulama Checklist (Kapatmadan Önce)
- [ ] **Navigation** — Yeniden Çek → CameraView; Save → DuplicateView veya ContactsView
- [ ] **OCR** — ScanFlowActor.parsedCard form alanlarına doğru yükleniyor
- [ ] **API Calls** — N/A
- [ ] **Local Storage** — @SceneStorage ile form draft korunuyor; ContactStore'a save çalışıyor
- [ ] **Error Handling** — Save hatası kullanıcıya gösteriliyor
- [ ] **Loading States** — Save butonu async tamamlanana kadar disabled
- [ ] **Analytics** — N/A
- [ ] **Permissions** — WRITE_CONTACTS izni save öncesi; reddedilince yalnızca SwiftData'ya kaydediliyor
BODY
I_URL=$(create_issue "feat(ocr): ConfirmView + ConfirmViewModel" "epic:1-ocr,type:feat,ios")
add_to_project "$I_URL"; ok "  → $(echo $I_URL | grep -oE '[0-9]+$')"

cat > "$TMP" << BODY
## Özet
Android'deki CardParser, VCardParser ve URLValidator testleri Swift'e birebir port ediliyor. Bu üç modül pure function olduğundan mock gerektirmiyor; %100 line coverage hedefleniyor.

## Android → iOS Karşılaştırma
| Özellik | Android | iOS |
|---|---|---|
| CardParserTest | ✅ 42 test | ❌ Swift XCTest port yapılacak |
| VCardParserTest | ✅ Mevcut | ❌ Port yapılacak |
| URLValidatorTest | ✅ Mevcut | ❌ Port yapılacak |

## Beklened Davranış
\`CardParserTests\`, \`VCardParserTests\`, \`URLValidatorTests\` — tümü geçiyor; %100 line coverage.

## İlgili Dosyalar
- \`Tests/Unit/CardParserTests.swift\`
- \`Tests/Unit/VCardParserTests.swift\`
- \`Tests/Unit/URLValidatorTests.swift\`

## Tahmini Süre
**Uygulama:** ~3 saat
**Review:** ~20 dk

## Referans
- iOS_ARCHITECTURE.md §10
- Epic: #$E1_NUM
- Android: \`CardParserTest.kt\`

## Doğrulama Checklist (Kapatmadan Önce)
- [ ] **Navigation** — N/A
- [ ] **OCR** — CardParserTests: isim, telefon, e-posta, faks hariç, ters isim, clamp testleri geçiyor
- [ ] **API Calls** — N/A
- [ ] **Local Storage** — N/A
- [ ] **Error Handling** — N/A
- [ ] **Loading States** — N/A
- [ ] **Analytics** — N/A
- [ ] **Permissions** — N/A
BODY
I_URL=$(create_issue "test(ocr): CardParser + VCardParser + URLValidator unit testleri" "epic:1-ocr,type:test,ios")
add_to_project "$I_URL"; ok "  → $(echo $I_URL | grep -oE '[0-9]+$')"

ok "Epic 1 tamamlandı"

# =============================================================================
# EPIC 2 — CONTACT STORAGE
# =============================================================================
log "Epic 2 — Contact Storage..."

cat > "$TMP" << BODY
## Özet
Contact domain model validation, ContactsView (liste + arama + swipe), DetailView (tappable alanlar, vCard share), ContactEditView ve DeviceContactsService (CNContactStore) implement ediliyor.

## Android → iOS Karşılaştırma
| Özellik | Android | iOS |
|---|---|---|
| Contact entity | ✅ Room @Entity | ❌ Contact struct + SchemaV1.ContactModel yapılacak |
| Field limits | ⚠️ Yoktu (Cat-6) | ❌ Contact.init FieldLimits enforce yapılacak |
| Liste + arama | ✅ LazyColumn + SQL LIKE | ❌ List + searchable (in-memory) yapılacak |
| Swipe aksiyonları | ✅ SwipeToDismiss | ❌ swipeActions modifier yapılacak |
| Device sync | ✅ ContentProviderClient | ❌ CNContactStore yapılacak |
| Notes güncelleme | ⚠️ Eksikti (#136) | ❌ CNSaveRequest'te notes dahil yapılacak |

## Beklened Davranış
Contact oluşturuluyor, listeleniyor, aranıyor, düzenleniyor, silinebiliyor. Rehbere ekleme çalışıyor.

## İlgili Dosyalar
- \`Domain/Model/Contact.swift\`, \`Domain/Validation/FieldLimits.swift\`
- \`Data/Persistence/ContactStore.swift\`, \`Data/Contacts/DeviceContactsService.swift\`
- \`UI/Contacts/ContactsView.swift\`, \`UI/Detail/DetailView.swift\`, \`UI/Edit/ContactEditView.swift\`

## Tahmini Süre
**Uygulama:** ~5 gün
**Review:** ~3 saat

## Referans
- iOS_ARCHITECTURE.md §4.1, §5.1, §6
- Android Bug Cat-5 (LIKE injection), Cat-6 (field limits)

## Doğrulama Checklist (Kapatmadan Önce)
- [ ] **Navigation** — Swipe sağ → LinkedIn veya mail compose; Swipe sol → sil onayı; Detail → Edit akışı
- [ ] **OCR** — N/A
- [ ] **API Calls** — N/A
- [ ] **Local Storage** — Düzenleme SwiftData'ya yazılıyor; deviceContactID varsa CNContactStore güncelleniyor
- [ ] **Error Handling** — Silme hatası graceful; CNContactStore erişim hatası graceful
- [ ] **Loading States** — Arama 200ms debounce; liste async yükleniyor
- [ ] **Analytics** — N/A
- [ ] **Permissions** — WRITE_CONTACTS reddedilince yalnızca SwiftData'ya kaydediliyor
BODY
E2_URL=$(create_issue "Epic 2 — Contact Storage" "epic:2-storage,ios,epic")
E2_NUM=$(echo "$E2_URL" | grep -oE '[0-9]+$')
add_to_project "$E2_URL"
ok "Epic 2 → #$E2_NUM"

cat > "$TMP" << BODY
## Özet
\`Contact\` struct'ın \`init\` metodunda tüm alanlar \`FieldLimits\` ile sınırlandırılıyor. Aşan değerler otomatik truncate ediliyor; bu sayede veritabanında overlength veri bulunması mümkün olmuyor (Android Cat-6 fix).

## Android → iOS Karşılaştırma
| Özellik | Android | iOS |
|---|---|---|
| Field limits | ⚠️ Room entity'de yoktu (Cat-6) | ❌ Contact.init'te enforce yapılacak |
| Type-safe model | ✅ data class | ❌ Struct + Codable yapılacak |

## Beklened Davranış
\`Contact(company: String(repeating: "x", count: 301)).company.count == 300\`

## İlgili Dosyalar
- \`Domain/Model/Contact.swift\`
- \`Domain/Model/ParsedCard.swift\`
- \`Domain/Model/EmailTemplate.swift\`
- \`Domain/Model/Event.swift\`
- \`Domain/Validation/FieldLimits.swift\`

## Tahmini Süre
**Uygulama:** ~2 saat
**Review:** ~20 dk

## Referans
- iOS_ARCHITECTURE.md §4.1, §4.3
- Epic: #$E2_NUM
- Android Bug Cat-6 (missing field length limits)

## Doğrulama Checklist (Kapatmadan Önce)
- [ ] **Navigation** — N/A
- [ ] **OCR** — N/A
- [ ] **API Calls** — N/A
- [ ] **Local Storage** — 301 char şirket → 300'e truncate; 4. telefon eklenmek istenince max 3'te kalıyor
- [ ] **Error Handling** — N/A
- [ ] **Loading States** — N/A
- [ ] **Analytics** — N/A
- [ ] **Permissions** — N/A
BODY
I_URL=$(create_issue "feat(storage): Contact struct + FieldLimits validation" "epic:2-storage,type:feat,ios")
add_to_project "$I_URL"; ok "  → $(echo $I_URL | grep -oE '[0-9]+$')"

cat > "$TMP" << BODY
## Özet
\`ContactStore\` @ModelActor implement ediliyor. \`findDuplicate\` metodu \`#Predicate\` ile exact match (== operatörü) kullanıyor; LIKE wildcard injection riski tamamen ortadan kaldırılıyor (Android Cat-5 fix). Arama da in-memory yapılıyor.

## Android → iOS Karşılaştırma
| Özellik | Android | iOS |
|---|---|---|
| Duplicate query | ⚠️ SQL LIKE (Cat-5 injection riski) | ❌ #Predicate == exact match yapılacak |
| Arama | ✅ SQL LIKE | ❌ In-memory .contains yapılacak |
| Background thread | ✅ Dispatchers.IO | ❌ @ModelActor yapılacak |

## Beklened Davranış
Phone değeri "%" olan kontak, tüm kayıtlarla eşleşmiyor; tam eşleşme gerekiyor.

## İlgili Dosyalar
- \`Data/Persistence/ContactStoreProtocol.swift\`
- \`Data/Persistence/ContactStore.swift\`
- \`Tests/Unit/ContactStoreTests.swift\`

## Tahmini Süre
**Uygulama:** ~4 saat
**Review:** ~30 dk

## Referans
- iOS_ARCHITECTURE.md §5.1
- Epic: #$E2_NUM
- Android Bug Cat-5 (SQL LIKE wildcard injection)

## Doğrulama Checklist (Kapatmadan Önce)
- [ ] **Navigation** — N/A
- [ ] **OCR** — N/A
- [ ] **API Calls** — N/A
- [ ] **Local Storage** — CRUD round-trip in-memory ModelConfiguration ile geçiyor; findDuplicate % karakterini wildcard olarak kullanmıyor
- [ ] **Error Handling** — modelContext.save() hatası throw ediliyor
- [ ] **Loading States** — N/A
- [ ] **Analytics** — N/A
- [ ] **Permissions** — N/A
BODY
I_URL=$(create_issue "feat(storage): ContactStore — SwiftData CRUD + exact-match duplicate query" "epic:2-storage,type:feat,ios")
add_to_project "$I_URL"; ok "  → $(echo $I_URL | grep -oE '[0-9]+$')"

cat > "$TMP" << BODY
## Özet
Kişi listesi \`List\` + \`searchable\` modifier ile implement ediliyor. Swipe-to-delete (onay dialog) ve swipe-to-right (LinkedIn veya mail compose) ekleniyor. İlk açılışta swipe hint animasyonu gösteriliyor.

## Android → iOS Karşılaştırma
| Özellik | Android | iOS |
|---|---|---|
| Liste | ✅ LazyColumn + SwipeToDismiss | ❌ List + swipeActions yapılacak |
| Arama | ✅ 200ms debounce | ❌ searchable + .debounce yapılacak |
| Swipe hint | ✅ Animasyon | ❌ Port yapılacak |
| ICS temizleme | ⚠️ Eksikti (#133) | ❌ Silme + ICS dosyası da silinecek |

## İlgili Dosyalar
- \`UI/Contacts/ContactsView.swift\`
- \`UI/Contacts/ContactsViewModel.swift\`
- \`UI/Components/InitialsAvatarView.swift\`

## Tahmini Süre
**Uygulama:** ~5 saat
**Review:** ~30 dk

## Referans
- iOS_ARCHITECTURE.md §6
- Epic: #$E2_NUM
- Android: #133 (ICS temizleme fix)

## Doğrulama Checklist (Kapatmadan Önce)
- [ ] **Navigation** — Swipe sağ → LinkedIn veya mailCompose; row tap → DetailView
- [ ] **OCR** — N/A
- [ ] **API Calls** — N/A
- [ ] **Local Storage** — Silme: SwiftData + deviceContactID varsa CNContactStore + ICS dosyası
- [ ] **Error Handling** — Silme hatası uyarı dialog
- [ ] **Loading States** — Arama 200ms debounce
- [ ] **Analytics** — N/A
- [ ] **Permissions** — N/A
BODY
I_URL=$(create_issue "feat(storage): ContactsView — liste, arama, swipe aksiyonları" "epic:2-storage,type:feat,ios")
add_to_project "$I_URL"; ok "  → $(echo $I_URL | grep -oE '[0-9]+$')"

cat > "$TMP" << BODY
## Özet
\`DetailView\` telefon, e-posta, adres ve LinkedIn alanlarını tıklanabilir link olarak gösteriyor. LinkedIn açılmadan önce URLValidator kontrolü yapılıyor. vCard paylaşımı \`UIActivityViewController\` ile sağlanıyor.

## Android → iOS Karşılaştırma
| Özellik | Android | iOS |
|---|---|---|
| Tıklanabilir alanlar | ✅ Intent ACTION_DIAL vb. | ❌ openURL ile yapılacak |
| LinkedIn güvenlik | ⚠️ Domain check yoktu (Cat-4) | ❌ URLValidator kontrolü yapılacak |
| vCard share | ✅ FileProvider | ❌ UIActivityViewController yapılacak |
| Fotoğraf pager | ✅ ViewPager | ❌ TabView yapılacak |

## İlgili Dosyalar
- \`UI/Detail/DetailView.swift\`
- \`UI/Detail/DetailViewModel.swift\`

## Tahmini Süre
**Uygulama:** ~4 saat
**Review:** ~30 dk

## Referans
- iOS_ARCHITECTURE.md §6
- Epic: #$E2_NUM
- Android Bug Cat-4 (URI injection)

## Doğrulama Checklist (Kapatmadan Önce)
- [ ] **Navigation** — Edit butonu → ContactEditView; Share → UIActivityViewController
- [ ] **OCR** — N/A
- [ ] **API Calls** — N/A
- [ ] **Local Storage** — ContactStore.observeById ile live update çalışıyor
- [ ] **Error Handling** — Geçersiz LinkedIn URL açılmıyor; RFC escape ile vCard doğru üretiliyor
- [ ] **Loading States** — N/A
- [ ] **Analytics** — N/A
- [ ] **Permissions** — Rehbere Ekle butonu WRITE_CONTACTS ister
BODY
I_URL=$(create_issue "feat(storage): DetailView — tappable fields, vCard share, edit/delete" "epic:2-storage,type:feat,ios")
add_to_project "$I_URL"; ok "  → $(echo $I_URL | grep -oE '[0-9]+$')"

cat > "$TMP" << BODY
## Özet
\`ContactEditView\` mevcut kişiyi düzenlemeye, \`DeviceContactsService\` ise \`CNContactStore\` üzerinden rehber senkronizasyonuna olanak tanıyor. Android'de notes alanı rehbere yazılmıyordu (#136); iOS'ta bu düzeltiliyor.

## Android → iOS Karşılaştırma
| Özellik | Android | iOS |
|---|---|---|
| Edit form | ✅ Compose | ❌ SwiftUI port yapılacak |
| Device sync | ✅ delete+reinsert | ❌ CNSaveRequest yapılacak |
| Notes sync | ⚠️ Eksikti (#136) | ❌ CNContactStore'a notes eklenecek |

## İlgili Dosyalar
- \`UI/Edit/ContactEditView.swift\`
- \`UI/Edit/ContactEditViewModel.swift\`
- \`Data/Contacts/DeviceContactsService.swift\`
- \`Data/Photo/PhotoStorage.swift\`

## Tahmini Süre
**Uygulama:** ~5 saat
**Review:** ~30 dk

## Referans
- iOS_ARCHITECTURE.md §6
- Epic: #$E2_NUM
- Android: #136 (notes alanı eksik fix)

## Doğrulama Checklist (Kapatmadan Önce)
- [ ] **Navigation** — Save → DetailView; back → düzenleme iptal
- [ ] **OCR** — N/A
- [ ] **API Calls** — N/A
- [ ] **Local Storage** — SwiftData güncelleniyor; CNContactStore güncelleniyor (izin varsa); notes yazılıyor
- [ ] **Error Handling** — CNContactStore hata → yalnızca SwiftData güncelleniyor
- [ ] **Loading States** — Save butonu async tamamlanana kadar disabled
- [ ] **Analytics** — N/A
- [ ] **Permissions** — WRITE_CONTACTS .permanentlyDenied → Settings linki
BODY
I_URL=$(create_issue "feat(storage): ContactEditView + DeviceContactsService sync" "epic:2-storage,type:feat,ios")
add_to_project "$I_URL"; ok "  → $(echo $I_URL | grep -oE '[0-9]+$')"

ok "Epic 2 tamamlandı"

# =============================================================================
# EPIC 3 — DUPLICATE FLOW
# =============================================================================
log "Epic 3 — Duplicate Flow..."

cat > "$TMP" << BODY
## Özet
Kaydetme sonrası duplicate detection ve merge akışı çalışıyor. \`DuplicateDetector\` pure function; DB erişimi yok. Android'deki stale state (Cat-2) ve geri butonu bug'ı (#138) iOS'ta yapısal olarak önleniyor.

## Android → iOS Karşılaştırma
| Özellik | Android | iOS |
|---|---|---|
| Duplicate tespiti | ✅ DuplicateViewModel + DB | ❌ DuplicateDetector pure fn yapılacak |
| Stale state | ⚠️ pendingParsedCard temizlenmiyordu (Cat-2) | ❌ ScanFlowActor.reset() yapılacak |
| Merge | ✅ Mevcut | ❌ Swift port yapılacak |
| Geri butonu | ⚠️ Çalışmıyordu (#138) | ❌ NavigationPath pop yapılacak |

## Beklened Davranış
Duplicate bulundu → DuplicateView gösterildi → Merge veya yeni kayıt seçildi → ScanFlowActor.reset() çağrıldı.

## İlgili Dosyalar
- \`Domain/Duplicate/DuplicateDetector.swift\`
- \`UI/Duplicate/DuplicateView.swift\`
- \`UI/Duplicate/DuplicateViewModel.swift\`
- \`Tests/Unit/ContactMergeTests.swift\`

## Tahmini Süre
**Uygulama:** ~2 gün
**Review:** ~1 saat

## Referans
- iOS_ARCHITECTURE.md §4.7, §6
- Android Bug Cat-2 (stale pending state)
- Android: #138 (geri butonu), #135 (notes kaybolma)

## Doğrulama Checklist (Kapatmadan Önce)
- [ ] **Navigation** — Merge sonrası DetailView; Yeni Kayıt → EventMatchView; Geri → ConfirmView
- [ ] **OCR** — N/A
- [ ] **API Calls** — N/A
- [ ] **Local Storage** — Merge → ContactStore.update çalışıyor; ScanFlowActor.reset() sonrası parsedCard nil
- [ ] **Error Handling** — N/A
- [ ] **Loading States** — N/A
- [ ] **Analytics** — N/A
- [ ] **Permissions** — N/A
BODY
E3_URL=$(create_issue "Epic 3 — Duplicate Flow" "epic:3-duplicate,ios,epic")
E3_NUM=$(echo "$E3_URL" | grep -oE '[0-9]+$')
add_to_project "$E3_URL"
ok "Epic 3 → #$E3_NUM"

cat > "$TMP" << BODY
## Özet
\`DuplicateDetector\` pure function olarak implement ediliyor; DB'ye erişmiyor. Merge stratejisi: yeni non-empty alanlar kazanır; e-postalar union+dedup; notlar concat distinct.

## Android → iOS Karşılaştırma
| Özellik | Android | iOS |
|---|---|---|
| Detector | ✅ DuplicateViewModel (DB bağımlı) | ❌ Pure function yapılacak |
| Merge | ✅ Mevcut | ❌ Swift port yapılacak |
| State temizleme | ⚠️ Asla temizlenmiyordu (Cat-2) | ❌ ScanFlowActor.reset() yapılacak |

## Beklened Davranış
\`DuplicateDetector.findDuplicate(for: card, in: allContacts)\` — DB çağrısı yok; caller contacts'ı geçiyor.

## İlgili Dosyalar
- \`Domain/Duplicate/DuplicateDetector.swift\`
- \`Tests/Unit/ContactMergeTests.swift\`

## Tahmini Süre
**Uygulama:** ~3 saat
**Review:** ~20 dk

## Referans
- iOS_ARCHITECTURE.md §4.7
- Epic: #$E3_NUM

## Doğrulama Checklist (Kapatmadan Önce)
- [ ] **Navigation** — N/A
- [ ] **OCR** — N/A
- [ ] **API Calls** — N/A
- [ ] **Local Storage** — ContactMergeTests: 24 test geçiyor; ScanFlowActor.reset() sonrası state nil
- [ ] **Error Handling** — N/A
- [ ] **Loading States** — N/A
- [ ] **Analytics** — N/A
- [ ] **Permissions** — N/A
BODY
I_URL=$(create_issue "feat(duplicate): DuplicateDetector — pure function, no DB" "epic:3-duplicate,type:feat,ios")
add_to_project "$I_URL"; ok "  → $(echo $I_URL | grep -oE '[0-9]+$')"

cat > "$TMP" << BODY
## Özet
\`DuplicateView\` mevcut ve yeni kişiyi yan yana diff olarak gösteriyor. "Mevcut Güncelle" veya "Yeni Kayıt Oluştur" seçilip akış devam ediyor. Geri butonu çalışıyor (Android #138 fix).

## Android → iOS Karşılaştırma
| Özellik | Android | iOS |
|---|---|---|
| Diff view | ✅ Mevcut | ❌ SwiftUI port yapılacak |
| Geri butonu | ⚠️ Çalışmıyordu (#138) | ❌ NavigationPath.removeLast yapılacak |
| Notes kaybolma | ⚠️ Merge'de kayboluyordu (#135) | ❌ DuplicateDetector.merge'de fixed |

## İlgili Dosyalar
- \`UI/Duplicate/DuplicateView.swift\`
- \`UI/Duplicate/DuplicateViewModel.swift\`

## Tahmini Süre
**Uygulama:** ~3 saat
**Review:** ~20 dk

## Referans
- iOS_ARCHITECTURE.md §6
- Epic: #$E3_NUM
- Android: #138 (geri butonu), #135 (notes)

## Doğrulama Checklist (Kapatmadan Önce)
- [ ] **Navigation** — Geri → ConfirmView (NavigationPath.removeLast); Merge → EventMatchView
- [ ] **OCR** — N/A
- [ ] **API Calls** — N/A
- [ ] **Local Storage** — Merge sonrası notes concat (distinct) doğrulanıyor
- [ ] **Error Handling** — N/A
- [ ] **Loading States** — Merge butonu async tamamlanana kadar disabled
- [ ] **Analytics** — N/A
- [ ] **Permissions** — N/A
BODY
I_URL=$(create_issue "feat(duplicate): DuplicateView — diff görünüm, merge / yeni kayıt" "epic:3-duplicate,type:feat,ios")
add_to_project "$I_URL"; ok "  → $(echo $I_URL | grep -oE '[0-9]+$')"

cat > "$TMP" << BODY
## Özet
Android'deki \`ContactMergeTest.kt\` testleri birebir Swift'e port ediliyor. 24 test case: firstName/company/title wins, existing preserved, emails union dedup, notes distinct, ID retained vb.

## Beklened Davranış
24/24 test geçiyor; \`DuplicateDetector.merge\` %100 line coverage.

## İlgili Dosyalar
- \`Tests/Unit/ContactMergeTests.swift\`
- \`Tests/Unit/DuplicateDetectorTests.swift\`

## Tahmini Süre
**Uygulama:** ~2 saat
**Review:** ~15 dk

## Referans
- iOS_ARCHITECTURE.md §10
- Epic: #$E3_NUM
- Android: \`ContactMergeTest.kt\`

## Doğrulama Checklist (Kapatmadan Önce)
- [ ] **Navigation** — N/A
- [ ] **OCR** — N/A
- [ ] **API Calls** — N/A
- [ ] **Local Storage** — 24 test geçiyor
- [ ] **Error Handling** — N/A
- [ ] **Loading States** — N/A
- [ ] **Analytics** — N/A
- [ ] **Permissions** — N/A
BODY
I_URL=$(create_issue "test(duplicate): ContactMergeTests — Android ContactMergeTest.kt birebir port" "epic:3-duplicate,type:test,ios")
add_to_project "$I_URL"; ok "  → $(echo $I_URL | grep -oE '[0-9]+$')"

ok "Epic 3 tamamlandı"

# =============================================================================
# EPIC 4 — EVENT MATCHING
# =============================================================================
log "Epic 4 — Event Matching..."

cat > "$TMP" << BODY
## Özet
Kayıt sonrası bugünün takvim etkinlikleri sunuluyor. Takvim izni reddedilince ekran skip ediliyor (Android #139 fix). Etkinlik seçilince contact.eventName güncelleniyor, mevcut notların üzerine yazılmıyor (Android #134 fix). İlk kayıtta In-App Review tetikleniyor.

## Android → iOS Karşılaştırma
| Özellik | Android | iOS |
|---|---|---|
| EKEventStore | ✅ CalendarRepository | ❌ CalendarService yapılacak |
| İzin reddi crash | ⚠️ SecurityException (#139) | ❌ EKAuthorizationStatus check yapılacak |
| Notes overwrite | ⚠️ Mevcut notlar siliniyordu (#134) | ❌ Concat append yapılacak |
| In-App Review | ✅ Google Play Review | ❌ SKStoreReviewController yapılacak |

## İlgili Dosyalar
- \`Data/Calendar/CalendarService.swift\`
- \`UI/EventMatch/EventMatchView.swift\`
- \`UI/EventMatch/EventMatchViewModel.swift\`

## Tahmini Süre
**Uygulama:** ~2 gün
**Review:** ~1 saat

## Referans
- iOS_ARCHITECTURE.md §6
- Android: #134 (notes overwrite), #139 (calendar perm)

## Doğrulama Checklist (Kapatmadan Önce)
- [ ] **Navigation** — Etkinlik seçimi veya Skip → Home; takvim izni reddinde screen skip
- [ ] **OCR** — N/A
- [ ] **API Calls** — N/A
- [ ] **Local Storage** — contact.eventName + notes concat doğru yazılıyor
- [ ] **Error Handling** — EKEventStore hata → boş liste; crash yok
- [ ] **Loading States** — Etkinlikler yüklenirken spinner; "Daha fazla" butonu pagination
- [ ] **Analytics** — N/A
- [ ] **Permissions** — READ_CALENDAR reddedilince → screen skip; WRITE_CONTACTS yoksa rehber güncellenmeden devam
BODY
E4_URL=$(create_issue "Epic 4 — Event Matching" "epic:4-events,ios,epic")
E4_NUM=$(echo "$E4_URL" | grep -oE '[0-9]+$')
add_to_project "$E4_URL"
ok "Epic 4 → #$E4_NUM"

cat > "$TMP" << BODY
## Özet
\`EKEventStore\` wrapper olarak \`CalendarService\` implement ediliyor. Yetkilendirme kontrolü yapılıyor; izin yoksa boş dizi dönüyor; crash yok. Events DTSTART ASC sıralı.

## Android → iOS Karşılaştırma
| Özellik | Android | iOS |
|---|---|---|
| Calendar API | ✅ ContentResolver | ❌ EKEventStore yapılacak |
| İzin kontrolü | ⚠️ SecurityException fırlatıyordu | ❌ EKAuthorizationStatus check yapılacak |

## İlgili Dosyalar
- \`Data/Calendar/CalendarService.swift\`
- \`Domain/Model/Event.swift\`

## Tahmini Süre
**Uygulama:** ~2 saat
**Review:** ~15 dk

## Referans
- iOS_ARCHITECTURE.md §6
- Epic: #$E4_NUM

## Doğrulama Checklist (Kapatmadan Önce)
- [ ] **Navigation** — N/A
- [ ] **OCR** — N/A
- [ ] **API Calls** — N/A
- [ ] **Local Storage** — N/A
- [ ] **Error Handling** — İzin yok → boş liste; EKEventStore hata → boş liste
- [ ] **Loading States** — N/A
- [ ] **Analytics** — N/A
- [ ] **Permissions** — .fullAccess yoksa requestFullAccessToEvents çağrılıyor
BODY
I_URL=$(create_issue "feat(events): CalendarService — EKEventStore wrapper" "epic:4-events,type:feat,ios")
add_to_project "$I_URL"; ok "  → $(echo $I_URL | grep -oE '[0-9]+$')"

cat > "$TMP" << BODY
## Özet
\`EventMatchView\` bugünkü etkinlikleri listeliyor. Etkinlik seçimi contact.eventName'i güncelliyor ve notlara append ediyor (overwrite yok). İzin reddedilince view skip ediliyor. İlk kayıtta SKStoreReviewController tetikleniyor.

## Android → iOS Karşılaştırma
| Özellik | Android | iOS |
|---|---|---|
| State'ler | ✅ aktif/bugün/yok | ❌ Swift port yapılacak |
| Notes append | ⚠️ Overwrite yapıyordu (#134) | ❌ Concat yapılacak |
| Skip on denial | ⚠️ Crash oluyordu (#139) | ❌ Screen skip yapılacak |
| In-App Review | ✅ Google Play | ❌ SKStoreReviewController yapılacak |

## İlgili Dosyalar
- \`UI/EventMatch/EventMatchView.swift\`
- \`UI/EventMatch/EventMatchViewModel.swift\`

## Tahmini Süre
**Uygulama:** ~4 saat
**Review:** ~30 dk

## Referans
- iOS_ARCHITECTURE.md §6
- Epic: #$E4_NUM
- Android: #134, #139

## Doğrulama Checklist (Kapatmadan Önce)
- [ ] **Navigation** — Skip → Home; Etkinlik seç → Home; Geri → DuplicateView
- [ ] **OCR** — N/A
- [ ] **API Calls** — N/A
- [ ] **Local Storage** — Mevcut notlar silinmiyor; eventName ContactStore'a yazılıyor
- [ ] **Error Handling** — EKEventStore hata → boş liste, crash yok
- [ ] **Loading States** — "Daha fazla yükle" butonu; yükleme süresince disabled
- [ ] **Analytics** — N/A
- [ ] **Permissions** — READ_CALENDAR reddedilince view skip; WRITE_CONTACTS yoksa yalnızca SwiftData
BODY
I_URL=$(create_issue "feat(events): EventMatchView + ViewModel — etkinlik seçimi, izin yönetimi" "epic:4-events,type:feat,ios")
add_to_project "$I_URL"; ok "  → $(echo $I_URL | grep -oE '[0-9]+$')"

ok "Epic 4 tamamlandı"

# =============================================================================
# EPIC 5 — MAIL + TEMPLATES
# =============================================================================
log "Epic 5 — Mail + Templates..."

cat > "$TMP" << BODY
## Özet
E-posta şablonları SwiftData'da saklanıyor. Şablon değişkenleri contact + profil verisiyle çözümleniyor. ICS toplantı daveti RFC 5545 uyumlu üretiliyor ve UTType.calendarEvent MIME ile paylaşılıyor (Android Cat-10 fix).

## Android → iOS Karşılaştırma
| Özellik | Android | iOS |
|---|---|---|
| Template storage | ✅ Room | ❌ SwiftData yapılacak |
| 5 default template | ✅ Seed mevcut | ❌ iOS seed yapılacak |
| ICS MIME type | ⚠️ Yanlış MIME (Cat-10) | ❌ UTType.calendarEvent yapılacak |
| [Etkinlik] boş | ⚠️ Bozuk metin (#116) | ❌ Cümle silme mantığı yapılacak |
| Mail compose | ✅ MFMailComposeViewController | ❌ Port yapılacak |

## İlgili Dosyalar
- \`Domain/ICS/ICSGenerator.swift\`
- \`UI/Templates/TemplatesView.swift\`
- \`UI/Mail/MailComposeView.swift\`

## Tahmini Süre
**Uygulama:** ~4 gün
**Review:** ~2 saat

## Referans
- iOS_ARCHITECTURE.md §4, §6
- Android Bug Cat-10 (ICS MIME), Android: #116

## Doğrulama Checklist (Kapatmadan Önce)
- [ ] **Navigation** — Şablon seçimi → MailComposeView; ICS gönderimi → UIActivityViewController
- [ ] **OCR** — N/A
- [ ] **API Calls** — N/A
- [ ] **Local Storage** — EmailTemplateStore CRUD; default reset çalışıyor
- [ ] **Error Handling** — Geçersiz e-posta ORGANIZER satırı üretilmiyor; ICS dosyası hata durumunda silinmiyor
- [ ] **Loading States** — N/A
- [ ] **Analytics** — N/A
- [ ] **Permissions** — N/A
BODY
E5_URL=$(create_issue "Epic 5 — Mail + Templates" "epic:5-mail,ios,epic")
E5_NUM=$(echo "$E5_URL" | grep -oE '[0-9]+$')
add_to_project "$E5_URL"
ok "Epic 5 → #$E5_NUM"

cat > "$TMP" << BODY
## Özet
\`EmailTemplateModel\` SwiftData entity olarak tanımlanıyor. 5 varsayılan Türkçe şablon ilk açılışta seed ediliyor. Default şablon silinirse reset ile orijinaline dönebiliyor.

## Android → iOS Karşılaştırma
| Özellik | Android | iOS |
|---|---|---|
| Template entity | ✅ Room @Entity | ❌ @Model yapılacak |
| 5 default | ✅ Seed mevcut | ❌ iOS seed yapılacak |
| Token syntax | ⚠️ Kullanıcıya gösteriliyordu (#117) | ❌ Chip render yapılacak |

## İlgili Dosyalar
- \`Data/Persistence/Schema/SchemaV1.swift\` — EmailTemplateModel
- \`Domain/Model/EmailTemplate.swift\`

## Tahmini Süre
**Uygulama:** ~3 saat
**Review:** ~20 dk

## Referans
- Epic: #$E5_NUM
- Android: #117

## Doğrulama Checklist (Kapatmadan Önce)
- [ ] **Navigation** — N/A
- [ ] **OCR** — N/A
- [ ] **API Calls** — N/A
- [ ] **Local Storage** — 5 default şablon ilk açılışta var; reset çalışıyor
- [ ] **Error Handling** — N/A
- [ ] **Loading States** — N/A
- [ ] **Analytics** — N/A
- [ ] **Permissions** — N/A
BODY
I_URL=$(create_issue "feat(mail): EmailTemplate SwiftData entity + 5 varsayılan şablon seed" "epic:5-mail,type:feat,ios")
add_to_project "$I_URL"; ok "  → $(echo $I_URL | grep -oE '[0-9]+$')"

cat > "$TMP" << BODY
## Özet
\`TemplatesView\` şablon listesi + swipe-to-delete + swipe-to-reset. \`TemplateEditView\` değişken chip'leri \`AttributedString\` ile render ediyor; chip'e tıklanınca cursor pozisyonuna token ekleniyor.

## Android → iOS Karşılaştırma
| Özellik | Android | iOS |
|---|---|---|
| Chip render | ✅ AnnotatedString | ❌ AttributedString yapılacak |
| Swipe actions | ✅ SwipeToDismiss | ❌ swipeActions yapılacak |
| Token insert | ✅ Mevcut | ❌ Port yapılacak |

## İlgili Dosyalar
- \`UI/Templates/TemplatesView.swift\`
- \`UI/Templates/TemplatesViewModel.swift\`
- \`UI/Templates/TemplateEditView.swift\`
- \`UI/Templates/TemplateEditViewModel.swift\`

## Tahmini Süre
**Uygulama:** ~4 saat
**Review:** ~30 dk

## Referans
- Epic: #$E5_NUM

## Doğrulama Checklist (Kapatmadan Önce)
- [ ] **Navigation** — Liste → Edit; Yeni → TemplateEditView(id: "new")
- [ ] **OCR** — N/A
- [ ] **API Calls** — N/A
- [ ] **Local Storage** — CRUD çalışıyor; default reset orijinal içeriğe dönüyor
- [ ] **Error Handling** — Boş isim → kayıt engelleniyor
- [ ] **Loading States** — N/A
- [ ] **Analytics** — N/A
- [ ] **Permissions** — N/A
BODY
I_URL=$(create_issue "feat(mail): TemplatesView + TemplateEditView" "epic:5-mail,type:feat,ios")
add_to_project "$I_URL"; ok "  → $(echo $I_URL | grep -oE '[0-9]+$')"

cat > "$TMP" << BODY
## Özet
RFC 5545 uyumlu ICS dosyası üretiliyor. LINE FOLDING 75 octet'te yapılıyor. ORGANIZER/ATTENDEE satırı geçersiz e-posta varsa yazılmıyor. UTType.calendarEvent ile UIActivityViewController kullanılıyor (Android Cat-10 fix).

## Android → iOS Karşılaştırma
| Özellik | Android | iOS |
|---|---|---|
| ICS üretimi | ✅ IcsGenerator.kt | ❌ Swift port yapılacak |
| MIME type | ⚠️ Yanlış MIME (Cat-10) | ❌ UTType.calendarEvent yapılacak |
| E-posta validasyon | ⚠️ Yoktu | ❌ Regex kontrol yapılacak |

## İlgili Dosyalar
- \`Domain/ICS/ICSGenerator.swift\`
- \`Tests/Unit/ICSGeneratorTests.swift\`

## Tahmini Süre
**Uygulama:** ~3 saat
**Review:** ~20 dk

## Referans
- iOS_ARCHITECTURE.md §4 (ICSGenerator snippet)
- Epic: #$E5_NUM
- Android Bug Cat-10

## Doğrulama Checklist (Kapatmadan Önce)
- [ ] **Navigation** — N/A
- [ ] **OCR** — N/A
- [ ] **API Calls** — N/A
- [ ] **Local Storage** — Üretilen .ics iOS Calendar'da açılıyor
- [ ] **Error Handling** — Geçersiz email → ORGANIZER satırı yok; ICS üretim hatası throw ediliyor
- [ ] **Loading States** — N/A
- [ ] **Analytics** — N/A
- [ ] **Permissions** — N/A
BODY
I_URL=$(create_issue "feat(mail): ICSGenerator — RFC 5545 uyumlu toplantı daveti" "epic:5-mail,type:feat,ios")
add_to_project "$I_URL"; ok "  → $(echo $I_URL | grep -oE '[0-9]+$')"

cat > "$TMP" << BODY
## Özet
\`MailComposeView\` şablon seçici, değişken çözümleme, eksik değişken uyarısı ve ICS ek gönderimi ile implement ediliyor. \`[Etkinlik]\` boşken içeren cümle siliniyor (Android #116 fix). Takvim çakışma algılaması kırmızı renk ile gösteriliyor.

## Android → iOS Karşılaştırma
| Özellik | Android | iOS |
|---|---|---|
| Template picker | ✅ Horizontal scroll | ❌ SwiftUI scroll yapılacak |
| [Etkinlik] boş | ⚠️ Bozuk metin (#116) | ❌ Cümle silme yapılacak |
| Çakışma algılama | ✅ Kırmızı highlight | ❌ Port yapılacak |
| MFMailCompose | ✅ Mevcut | ❌ UIViewControllerRepresentable yapılacak |

## İlgili Dosyalar
- \`UI/Mail/MailComposeView.swift\`
- \`UI/Mail/MailComposeViewModel.swift\`

## Tahmini Süre
**Uygulama:** ~5 saat
**Review:** ~30 dk

## Referans
- Epic: #$E5_NUM
- Android: #116

## Doğrulama Checklist (Kapatmadan Önce)
- [ ] **Navigation** — ContactID yoksa contact picker; ICS → UIActivityViewController
- [ ] **OCR** — N/A
- [ ] **API Calls** — N/A
- [ ] **Local Storage** — N/A
- [ ] **Error Handling** — [Etkinlik] boşken gövdede bozuk metin yok; eksik profil → uyarı banner
- [ ] **Loading States** — ICS üretimi async; gönder butonu süresince disabled
- [ ] **Analytics** — N/A
- [ ] **Permissions** — N/A
BODY
I_URL=$(create_issue "feat(mail): MailComposeView — şablon seçici, değişken çözümleme, ICS ek" "epic:5-mail,type:feat,ios")
add_to_project "$I_URL"; ok "  → $(echo $I_URL | grep -oE '[0-9]+$')"

cat > "$TMP" << BODY
## Özet
\`ICSGeneratorTests\` RFC 5545 doğrulaması: UTC format, 75 octet line folding, TEXT escaping ve e-posta validasyon testleri. %100 line coverage hedefleniyor.

## İlgili Dosyalar
- \`Tests/Unit/ICSGeneratorTests.swift\`

## Tahmini Süre
**Uygulama:** ~2 saat
**Review:** ~15 dk

## Referans
- iOS_ARCHITECTURE.md §10
- Epic: #$E5_NUM

## Doğrulama Checklist (Kapatmadan Önce)
- [ ] **Navigation** — N/A
- [ ] **OCR** — N/A
- [ ] **API Calls** — N/A
- [ ] **Local Storage** — N/A
- [ ] **Error Handling** — Tüm test case'ler geçiyor
- [ ] **Loading States** — N/A
- [ ] **Analytics** — N/A
- [ ] **Permissions** — N/A
BODY
I_URL=$(create_issue "test(mail): ICSGeneratorTests — RFC 5545 doğrulama" "epic:5-mail,type:test,ios")
add_to_project "$I_URL"; ok "  → $(echo $I_URL | grep -oE '[0-9]+$')"

ok "Epic 5 tamamlandı"

# =============================================================================
# EPIC 6 — PROFILE + QR
# =============================================================================
log "Epic 6 — Profile + QR..."

cat > "$TMP" << BODY
## Özet
Kullanıcı kendi profilini oluşturuyor, Keychain'de PII olarak saklıyor. CoreImage ile vCard QR kodu üretiyor ve paylaşıyor. Boş profilde QR butonu engelleniyor (Android #141 fix).

## Android → iOS Karşılaştırma
| Özellik | Android | iOS |
|---|---|---|
| Profil depolama | ✅ EncryptedSharedPreferences | ❌ Keychain actor yapılacak |
| QR üretimi | ✅ ZXing | ❌ CoreImage.CIFilter yapılacak |
| Boş profil QR | ⚠️ Crash oluyordu (#141) | ❌ Guard kontrol yapılacak |
| OCR self-scan | ✅ Mevcut | ❌ VisionOCRService + CardParser yapılacak |

## İlgili Dosyalar
- \`Data/Keychain/UserProfileStore.swift\`
- \`UI/Profile/ProfileView.swift\`
- \`UI/Profile/ProfileViewModel.swift\`

## Tahmini Süre
**Uygulama:** ~2 gün
**Review:** ~1 saat

## Referans
- iOS_ARCHITECTURE.md §5.4, §6
- Android: #141

## Doğrulama Checklist (Kapatmadan Önce)
- [ ] **Navigation** — QR sheet gösterimi; Avatar picker; OCR self-scan akışı
- [ ] **OCR** — OCR self-scan profil alanlarını doğru dolduruyor
- [ ] **API Calls** — N/A
- [ ] **Local Storage** — Profil Keychain'e JSON encoded yazılıyor; round-trip doğru
- [ ] **Error Handling** — Boş profilde QR butonu disabled veya uyarı gösteriliyor
- [ ] **Loading States** — N/A
- [ ] **Analytics** — N/A
- [ ] **Permissions** — Kamera izni (OCR self-scan); PhotosPicker (avatar)
BODY
E6_URL=$(create_issue "Epic 6 — Profile + QR" "epic:6-profile,ios,epic")
E6_NUM=$(echo "$E6_URL" | grep -oE '[0-9]+$')
add_to_project "$E6_URL"
ok "Epic 6 → #$E6_NUM"

cat > "$TMP" << BODY
## Özet
\`ProfileView\` + \`ProfileViewModel\` implement ediliyor. Profil Keychain'deki \`UserProfileStore\` actor üzerinden async yükleniyor/kaydediliyor. Avatar için PhotosPicker veya kamera kullanılıyor. OCR self-scan ile kendi kartından profil dolduruluyor.

## Android → iOS Karşılaştırma
| Özellik | Android | iOS |
|---|---|---|
| Profil yükleme | ✅ PreferencesRepository | ❌ UserProfileStore actor yapılacak |
| OCR self-scan | ✅ Mevcut | ❌ VisionOCRService yapılacak |

## İlgili Dosyalar
- \`UI/Profile/ProfileView.swift\`
- \`UI/Profile/ProfileViewModel.swift\`
- \`Data/Keychain/UserProfileStore.swift\`

## Tahmini Süre
**Uygulama:** ~4 saat
**Review:** ~30 dk

## Referans
- iOS_ARCHITECTURE.md §5.4
- Epic: #$E6_NUM

## Doğrulama Checklist (Kapatmadan Önce)
- [ ] **Navigation** — N/A
- [ ] **OCR** — OCR self-scan alanları doğru dolduruyor
- [ ] **API Calls** — N/A
- [ ] **Local Storage** — Profil Keychain round-trip doğru; PII UserDefaults'a gitmiyor
- [ ] **Error Handling** — Kayıt hatası alert ile gösteriliyor
- [ ] **Loading States** — N/A
- [ ] **Analytics** — N/A
- [ ] **Permissions** — Kamera (OCR self-scan) PermissionCoordinator üzerinden
BODY
I_URL=$(create_issue "feat(profile): ProfileView + ProfileViewModel — Keychain'den okuma/yazma" "epic:6-profile,type:feat,ios")
add_to_project "$I_URL"; ok "  → $(echo $I_URL | grep -oE '[0-9]+$')"

cat > "$TMP" << BODY
## Özet
\`CoreImage.CIFilter.qrCodeGenerator\` ile profil vCard 3.0 içeriğinden QR kodu üretiliyor. QR HomeView'de sheet olarak gösteriliyor ve UIActivityViewController ile paylaşılıyor. Profil boşsa QR butonu engelleniyor (Android #141 fix).

## Android → iOS Karşılaştırma
| Özellik | Android | iOS |
|---|---|---|
| QR üretimi | ✅ ZXing | ❌ CoreImage.CIFilter yapılacak |
| Boş profil | ⚠️ Crash (#141) | ❌ Guard + disabled buton yapılacak |
| QR paylaşma | ✅ ShareCompat | ❌ UIActivityViewController yapılacak |

## İlgili Dosyalar
- \`UI/Home/HomeView.swift\` — QR sheet
- \`UI/Profile/ProfileViewModel.swift\` — QR üretim mantığı

## Tahmini Süre
**Uygulama:** ~2 saat
**Review:** ~20 dk

## Referans
- Epic: #$E6_NUM
- Android: #141

## Doğrulama Checklist (Kapatmadan Önce)
- [ ] **Navigation** — QR sheet kapatma; Share → UIActivityViewController
- [ ] **OCR** — N/A
- [ ] **API Calls** — N/A
- [ ] **Local Storage** — N/A
- [ ] **Error Handling** — Boş profil → QR butonu disabled veya alert
- [ ] **Loading States** — N/A
- [ ] **Analytics** — N/A
- [ ] **Permissions** — N/A
BODY
I_URL=$(create_issue "feat(profile): QR kodu oluşturma ve paylaşma" "epic:6-profile,type:feat,ios")
add_to_project "$I_URL"; ok "  → $(echo $I_URL | grep -oE '[0-9]+$')"

ok "Epic 6 tamamlandı"

# =============================================================================
# EPIC 7 — SECURITY HARDENING
# =============================================================================
log "Epic 7 — Security Hardening..."

cat > "$TMP" << BODY
## Özet
Android'de sonradan eklenen güvenlik önlemleri iOS'ta en baştan yapılıyor: Jailbreak detection, iCloud backup exclusion, scene blur (FLAG_SECURE), KVKK onay akışı ve App Store Privacy Manifest.

## Android → iOS Karşılaştırma
| Özellik | Android | iOS |
|---|---|---|
| Root detection | ✅ SecurityUtils (#120) | ❌ JailbreakDetector yapılacak |
| FLAG_SECURE | ✅ Window flag (#119) | ❌ scenePhase overlay yapılacak |
| Backup exclusion | ✅ backup_rules.xml | ❌ isExcludedFromBackup yapılacak |
| Privacy Manifest | N/A (Android) | ❌ PrivacyInfo.xcprivacy yapılacak |

## İlgili Dosyalar
- \`Security/JailbreakDetector.swift\`
- \`Security/ScreenshotProtection.swift\`
- \`PrivacyInfo.xcprivacy\`

## Tahmini Süre
**Uygulama:** ~2 gün
**Review:** ~2 saat

## Referans
- iOS_ARCHITECTURE.md §7
- Android: #119, #120

## Doğrulama Checklist (Kapatmadan Önce)
- [ ] **Navigation** — N/A
- [ ] **OCR** — N/A
- [ ] **API Calls** — N/A
- [ ] **Local Storage** — photos/ ve DB isExcludedFromBackup=true
- [ ] **Error Handling** — N/A
- [ ] **Loading States** — N/A
- [ ] **Analytics** — N/A
- [ ] **Permissions** — Info.plist'te yalnızca kullanılan permission string'leri var
BODY
E7_URL=$(create_issue "Epic 7 — Security Hardening" "epic:7-security,ios,epic")
E7_NUM=$(echo "$E7_URL" | grep -oE '[0-9]+$')
add_to_project "$E7_URL"
ok "Epic 7 → #$E7_NUM"

cat > "$TMP" << BODY
## Özet
\`JailbreakDetector\` — dosya varlığı, sandbox dışı yazma ve dylib kontrolleri. Simulator build'de false positive yok. Uygulama başlangıcında kontrol yapılıyor; jailbreak tespit edilirse non-blocking dialog gösteriliyor.

## Android → iOS Karşılaştırma
| Özellik | Android | iOS |
|---|---|---|
| Root detection | ✅ SecurityUtils.kt | ❌ JailbreakDetector yapılacak |
| Emulator check | ✅ Build.FINGERPRINT | ❌ targetEnvironment(simulator) yapılacak |

## İlgili Dosyalar
- \`Security/JailbreakDetector.swift\`

## Tahmini Süre
**Uygulama:** ~2 saat
**Review:** ~20 dk

## Referans
- iOS_ARCHITECTURE.md §7.1
- Epic: #$E7_NUM
- Android: SecurityUtils.kt, #120

## Doğrulama Checklist (Kapatmadan Önce)
- [ ] **Navigation** — Jailbreak dialog → "Devam Et" veya "Çıkış"
- [ ] **OCR** — N/A
- [ ] **API Calls** — N/A
- [ ] **Local Storage** — N/A
- [ ] **Error Handling** — Simulator'da false alarm yok
- [ ] **Loading States** — N/A
- [ ] **Analytics** — N/A
- [ ] **Permissions** — N/A
BODY
I_URL=$(create_issue "feat(security): JailbreakDetector + uygulama açılış uyarısı" "epic:7-security,type:security,ios")
add_to_project "$I_URL"; ok "  → $(echo $I_URL | grep -oE '[0-9]+$')"

cat > "$TMP" << BODY
## Özet
photos/, ics/, vcf/ dizinlerine ve SwiftData DB dosyasına ilk açılışta \`isExcludedFromBackup = true\` atanıyor. UserProfile zaten Keychain'de; iCloud'a gitmiyor. \`@AppStorage\` onboarding flag'leri kasıtlı olarak backup'a dahil ediliyor.

## Android → iOS Karşılaştırma
| Özellik | Android | iOS |
|---|---|---|
| Backup exclusion | ✅ backup_rules.xml | ❌ URLResourceValues yapılacak |
| DB backup | ✅ Excluded | ❌ SwiftData db dosyası excluded yapılacak |

## İlgili Dosyalar
- \`App/CardConnectApp.swift\` — ilk açılış backup exclusion
- \`Data/Photo/PhotoStorage.swift\`

## Tahmini Süre
**Uygulama:** ~1 saat
**Review:** ~15 dk

## Referans
- iOS_ARCHITECTURE.md §7, §11
- Epic: #$E7_NUM

## Doğrulama Checklist (Kapatmadan Önce)
- [ ] **Navigation** — N/A
- [ ] **OCR** — N/A
- [ ] **API Calls** — N/A
- [ ] **Local Storage** — photos/ isExcludedFromBackup=true; DB dosyası excluded
- [ ] **Error Handling** — setResourceValues hata → log + devam
- [ ] **Loading States** — N/A
- [ ] **Analytics** — N/A
- [ ] **Permissions** — N/A
BODY
I_URL=$(create_issue "feat(security): iCloud backup exclusion — photos, ics, vcf, DB" "epic:7-security,type:security,ios")
add_to_project "$I_URL"; ok "  → $(echo $I_URL | grep -oE '[0-9]+$')"

cat > "$TMP" << BODY
## Özet
\`ScreenshotProtectionModifier\` — \`scenePhase == .inactive\` olduğunda tüm içerik siyah overlay ile kaplandı. App switcher thumbnail'ında kişi bilgisi görünmüyor. FLAG_SECURE'un iOS karşılığı.

## Android → iOS Karşılaştırma
| Özellik | Android | iOS |
|---|---|---|
| FLAG_SECURE | ✅ Window flag | ❌ scenePhase + overlay yapılacak |

## İlgili Dosyalar
- \`Security/ScreenshotProtection.swift\`
- \`UI/Navigation/RootNavigationView.swift\` — modifier ekleniyor

## Tahmini Süre
**Uygulama:** ~30 dk
**Review:** ~10 dk

## Referans
- iOS_ARCHITECTURE.md §7.2
- Epic: #$E7_NUM
- Android: #119 (FLAG_SECURE)

## Doğrulama Checklist (Kapatmadan Önce)
- [ ] **Navigation** — N/A
- [ ] **OCR** — N/A
- [ ] **API Calls** — N/A
- [ ] **Local Storage** — N/A
- [ ] **Error Handling** — N/A
- [ ] **Loading States** — N/A
- [ ] **Analytics** — N/A
- [ ] **Permissions** — N/A
BODY
I_URL=$(create_issue "feat(security): Scene blur — inactive/background'da içerik gizleme" "epic:7-security,type:security,ios")
add_to_project "$I_URL"; ok "  → $(echo $I_URL | grep -oE '[0-9]+$')"

cat > "$TMP" << BODY
## Özet
\`PrivacyPolicyView\` ve KVKK onay akışı implement ediliyor. Onboarding son sayfasında Privacy checkbox işaretlenmeden bir sonraki adıma geçilemiyor. Settings'ten gizlilik politikasına erişim mevcut.

## Android → iOS Karşılaştırma
| Özellik | Android | iOS |
|---|---|---|
| KVKK onay | ✅ Onboarding checkbox | ❌ SwiftUI Toggle yapılacak |
| Privacy screen | ✅ PrivacyPolicyScreen | ❌ SwiftUI port yapılacak |

## İlgili Dosyalar
- \`UI/Settings/PrivacyPolicyView.swift\`
- \`UI/Onboarding/OnboardingView.swift\` — checkbox

## Tahmini Süre
**Uygulama:** ~2 saat
**Review:** ~15 dk

## Referans
- Epic: #$E7_NUM

## Doğrulama Checklist (Kapatmadan Önce)
- [ ] **Navigation** — Settings → PrivacyPolicyView; Onboarding checkbox → ProfileSetup
- [ ] **OCR** — N/A
- [ ] **API Calls** — N/A
- [ ] **Local Storage** — privacy_accepted @AppStorage'a yazılıyor
- [ ] **Error Handling** — N/A
- [ ] **Loading States** — N/A
- [ ] **Analytics** — N/A
- [ ] **Permissions** — N/A
BODY
I_URL=$(create_issue "feat(security): PrivacyPolicyView + KVKK onay akışı" "epic:7-security,type:security,ios")
add_to_project "$I_URL"; ok "  → $(echo $I_URL | grep -oE '[0-9]+$')"

cat > "$TMP" << BODY
## Özet
\`PrivacyInfo.xcprivacy\` dosyası oluşturuluyor; kullanılan API'ler (NSFileSystemAPI, NSUserDefaultsAPI) beyan ediliyor. App Store Connect'te şifreleme kullanımı (Keychain AES) beyan ediliyor. Info.plist'te yalnızca kullanılan permission description string'leri mevcut.

## Android → iOS Karşılaştırma
| Özellik | Android | iOS |
|---|---|---|
| Permission audit | ✅ READ_CONTACTS unused → removed | ❌ SwiftLint plist audit kuralı yapılacak |
| Privacy beyan | N/A | ❌ PrivacyInfo.xcprivacy yapılacak |

## İlgili Dosyalar
- \`PrivacyInfo.xcprivacy\`
- \`Info.plist\`

## Tahmini Süre
**Uygulama:** ~2 saat
**Review:** ~20 dk

## Referans
- iOS_ARCHITECTURE.md §11
- Epic: #$E7_NUM

## Doğrulama Checklist (Kapatmadan Önce)
- [ ] **Navigation** — N/A
- [ ] **OCR** — N/A
- [ ] **API Calls** — N/A
- [ ] **Local Storage** — N/A
- [ ] **Error Handling** — N/A
- [ ] **Loading States** — N/A
- [ ] **Analytics** — N/A
- [ ] **Permissions** — Xcode Privacy Report uyarısız; yalnızca kullanılan permission string'leri var
BODY
I_URL=$(create_issue "chore(security): App Store hazırlık — Privacy Manifest + export compliance" "epic:7-security,type:chore,ios")
add_to_project "$I_URL"; ok "  → $(echo $I_URL | grep -oE '[0-9]+$')"

cat > "$TMP" << BODY
## Özet
iOS_ARCHITECTURE.md §1'deki 14 maddelik Bug Prevention Matrix'in tamamının uygulanmış olduğu doğrulanıyor. Her madde için kod incelemesi + otomatik test çalıştırılıyor.

## Beklened Davranış
14/14 madde geçiyor; herhangi birinde eksik varsa yeni bug fix issue açılıyor.

## İlgili Dosyalar
- iOS_ARCHITECTURE.md §1 (Bug Prevention Matrix)
- Tüm Domain/ ve Data/ dosyaları

## Tahmini Süre
**Uygulama:** ~3 saat
**Review:** ~1 saat

## Referans
- iOS_ARCHITECTURE.md §1
- Epic: #$E7_NUM

## Doğrulama Checklist (Kapatmadan Önce)
- [ ] **Navigation** — N/A
- [ ] **OCR** — CardParser/VCardParser unit testleri geçiyor
- [ ] **API Calls** — N/A
- [ ] **Local Storage** — ContactStore LIKE query yok; ScanFlowActor isolation uyarısı yok
- [ ] **Error Handling** — N/A
- [ ] **Loading States** — N/A
- [ ] **Analytics** — N/A
- [ ] **Permissions** — PermissionCoordinator permanent denial loop yok
BODY
I_URL=$(create_issue "chore(security): Security review — iOS_ARCHITECTURE Bug Prevention Matrix doğrulama" "epic:7-security,type:security,ios")
add_to_project "$I_URL"; ok "  → $(echo $I_URL | grep -oE '[0-9]+$')"

ok "Epic 7 tamamlandı"

# Temp dosyayı temizle
rm -f "$TMP"

echo ""
echo "============================================================"
echo -e "${GREEN}✅ Tüm epic'ler ve issue'lar oluşturuldu${NC}"
echo "============================================================"
echo ""
echo "Repo: https://github.com/$REPO/issues"
if [ -n "${PROJECT_NUMBER:-}" ]; then
  echo "Project: https://github.com/users/tolgabarisalcitepe/projects/$PROJECT_NUMBER"
fi
