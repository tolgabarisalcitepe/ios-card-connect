#!/usr/bin/env bash
# =============================================================================
# create_ios_issues.sh
# Card Connect iOS — Epic + Issue yaratma scripti
#
# Kullanım:
#   gh auth login   (sadece ilk seferinde)
#   chmod +x create_ios_issues.sh
#   ./create_ios_issues.sh
#
# Gereksinim: gh CLI kurulu ve auth yapılmış olmalı
# Repo: tolgabarisalcitepe/and-card-connect (veya iOS reposu)
# =============================================================================

set -euo pipefail

REPO="tolgabarisalcitepe/and-card-connect"   # iOS reposuna taşıyınca güncelle

# Renkler
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log()  { echo -e "${BLUE}▶ $*${NC}"; }
done() { echo -e "${GREEN}✓ $*${NC}"; }

# =============================================================================
# LABELS
# =============================================================================

log "Label'lar yaratılıyor..."

create_label() {
  local name="$1" color="$2" desc="$3"
  gh label create "$name" --color "$color" --description "$desc" --repo "$REPO" --force 2>/dev/null || true
}

# Epic labels
create_label "epic:0-foundation"    "0052cc" "Epic 0 — Foundation"
create_label "epic:1-ocr"          "e4e669" "Epic 1 — OCR Pipeline"
create_label "epic:2-storage"      "0e8a16" "Epic 2 — Contact Storage"
create_label "epic:3-duplicate"    "b60205" "Epic 3 — Duplicate Flow"
create_label "epic:4-events"       "5319e7" "Epic 4 — Event Matching"
create_label "epic:5-mail"         "1d76db" "Epic 5 — Mail + Templates"
create_label "epic:6-profile"      "f9d0c4" "Epic 6 — Profile + QR"
create_label "epic:7-security"     "c5def5" "Epic 7 — Security Hardening"

# Type labels
create_label "type:feat"     "a2eeef" "New feature"
create_label "type:test"     "d93f0b" "Tests"
create_label "type:infra"    "e99695" "Infrastructure / DI / config"
create_label "type:security" "b60205" "Security"
create_label "ios"           "000000" "iOS"

done "Label'lar hazır"

# =============================================================================
# HELPER: issue yarat, numarasını döndür
# =============================================================================

# Epic issue'ların numaralarını saklıyoruz (milestone olarak kullanacağız)
declare -A EPIC_ISSUES

create_issue() {
  local title="$1"
  local body="$2"
  local labels="$3"
  gh issue create \
    --repo "$REPO" \
    --title "$title" \
    --body "$body" \
    --label "$labels" \
    | grep -oE '[0-9]+$'
}

# =============================================================================
# EPIC 0 — FOUNDATION
# =============================================================================

log "Epic 0 — Foundation yaratılıyor..."

E0=$(create_issue \
  "Epic 0 — Foundation" \
  "## Hedef
Uygulama açılıyor. Onboarding çalışıyor. Boş home ekranı açılıyor.

## Scope
- SwiftData stack (schema v1, Keychain-encrypted)
- Keychain wrapper (UserProfile + DB key)
- DependencyContainer protocol + live impl
- NavigationStack + AppRoute enum (typed routes, no strings)
- ScanFlowActor (transient scan state — Cat-1 race condition fix)
- PermissionCoordinator (no loops — Cat-7 fix)
- Onboarding (3 pages, privacy checkbox)
- ProfileSetup screen
- HomeView (empty state)
- FLAG_SECURE equivalent (blur on inactive scene)

## Çıktı
\`\`\`
Uygulama açılıyor.
Onboarding çalışıyor.
Boş home ekranı açılıyor.
\`\`\`

## Referanslar
- iOS_ARCHITECTURE.md §3 (Project Structure)
- iOS_ARCHITECTURE.md §5.1 (SwiftData)
- iOS_ARCHITECTURE.md §5.2 (ScanFlowActor)
- iOS_ARCHITECTURE.md §8 (Navigation)
- iOS_ARCHITECTURE.md §9 (Permission Handling)
- DECISIONS.md §1 (Manual DI → DependencyContainer)
- DECISIONS.md §5 (String routes → AppRoute enum)" \
  "epic:0-foundation,ios")
EPIC_ISSUES[0]=$E0
done "Epic 0 → #$E0"

# Epic 0 child issues
log "  Epic 0 issue'ları yaratılıyor..."

create_issue \
  "feat(foundation): SwiftData stack — SchemaV1 + Keychain-encrypted DB" \
  "## Bağlı Epic
#$E0

## Yapılacaklar
- [ ] \`SchemaV1.swift\` — \`ContactModel\` + \`EmailTemplateModel\` \`@Model\` tanımları
- [ ] \`ContactStore.swift\` — \`@ModelActor\` actor; CRUD metodları
- [ ] \`ContactStoreProtocol.swift\` — mock-friendly protocol
- [ ] \`ModelConfiguration\` — iCloud sync kapalı (\`cloudKitDatabase: .none\`)
- [ ] Keychain'den 32-byte key çek; SQLite PRAGMA ile şifreleme aç
- [ ] iCloud backup exclusion — photos/, ics/, vcf/ dizinleri
- [ ] \`SchemaV2\` boş migration şablonu hazırla

## Kabul Kriterleri
- ContactModel insert/fetch/delete unit testleri geçiyor (in-memory ModelConfiguration)
- DB dosyası \`.isExcludedFromBackup = true\`

## Referanslar
- iOS_ARCHITECTURE.md §5.1
- DECISIONS.md §2 (SQLCipher → SwiftData encrypted)
- DECISIONS.md §3 (JSON columns)
- Android Bug Cat-3 (process death), Cat-6 (field limits)" \
  "epic:0-foundation,type:infra,ios"

create_issue \
  "feat(foundation): KeychainStore + UserProfileStore" \
  "## Bağlı Epic
#$E0

## Yapılacaklar
- [ ] \`KeychainStore.swift\` — generic \`save(key:data:)\` / \`load(key:)\` / \`delete(key:)\`
- [ ] \`kSecAttrAccessibleWhenUnlocked\` — yalnızca unlock sonrası erişim
- [ ] \`UserProfileStore.swift\` — \`actor\`; JSON encode/decode; Keychain üzerinde saklıyor
- [ ] DB passphrase key (\`com.cardconnect.db.key\`) yönetimi
- [ ] Keystore corruption recovery — key yoksa yeni üret, DB sil

## Kabul Kriterleri
- \`UserProfileStore.save() → load()\` round-trip testi geçiyor
- Keychain'de \`kSecClassGenericPassword\` item var

## Referanslar
- iOS_ARCHITECTURE.md §5.3
- DECISIONS.md §6 (EncryptedSharedPreferences → Keychain)
- Android Bug Cat-8 (thread safety)" \
  "epic:0-foundation,type:infra,ios"

create_issue \
  "feat(foundation): DependencyContainer + @Environment wiring" \
  "## Bağlı Epic
#$E0

## Yapılacaklar
- [ ] \`DependencyContainer.swift\` protocol + \`LiveDependencyContainer\` impl
- [ ] \`ScanFlowActor\` — \`@StateObject\` olarak \`CardConnectApp\`'e bağla
- [ ] \`@Environment(\.dependencies)\` custom EnvironmentKey
- [ ] \`CardConnectApp.swift\` — tüm bağımlılıkları wire et
- [ ] Her ViewModel sadece ihtiyacı olan protokolü alıyor (AppContainer god-object yok)

## Kabul Kriterleri
- Herhangi bir ViewModel init'inde \`Application\` cast yok
- Mock DependencyContainer ile unit test çalışıyor

## Referanslar
- iOS_ARCHITECTURE.md §2 (DI)
- DECISIONS.md §4 (AndroidViewModel → protocol injection)
- Android Bug Cat-1 (AppContainer god object)" \
  "epic:0-foundation,type:infra,ios"

create_issue \
  "feat(foundation): NavigationStack + AppRoute enum (typed routes)" \
  "## Bağlı Epic
#$E0

## Yapılacaklar
- [ ] \`AppRoute.swift\` — \`enum AppRoute: Hashable\` tüm case'lerle
- [ ] \`RootNavigationView.swift\` — \`NavigationStack<AppRoute>\` + \`navigationDestination\`
- [ ] Tab bar — Home / Contacts / Scan (FAB) / Templates / Mail
- [ ] \`.vcf\` incoming URL → \`AppRoute.confirm\` yönlendirmesi
- [ ] \`Info.plist\` UTI: \`public.vcard\`, \`public.x-vcard\`

## Kabul Kriterleri
- String route yok; \`AppRoute\` typo → compile error
- \`.vcf\` dosyası uygulamaya açıldığında ConfirmView görünüyor

## Referanslar
- iOS_ARCHITECTURE.md §8
- DECISIONS.md §5 (String routes → typed)
- Android Bug Cat-3 (process death nav recovery)" \
  "epic:0-foundation,type:feat,ios"

create_issue \
  "feat(foundation): ScanFlowActor — thread-safe transient scan state" \
  "## Bağlı Epic
#$E0

## Yapılacaklar
- [ ] \`ScanFlowActor.swift\` — Swift \`actor\`; \`photoPaths\`, \`parsedCard\`, \`contactID\`, \`incomingVCard\`
- [ ] \`reset()\` — flow tamamlanınca veya iptal edilince tüm state temizleniyor
- [ ] \`setPhotoPaths\`, \`setParsedCard\`, \`setContactID\`, \`setIncomingVCard\` async mutators
- [ ] Concurrent access testi — iki \`Task\` aynı anda yazıyor, data race yok

## Kabul Kriterleri
- \`actor isolation\` Swift compiler uyarısı yok
- \`reset()\` sonrası tüm alanlar sıfırlanıyor

## Referanslar
- iOS_ARCHITECTURE.md §5.2
- DECISIONS.md Cat-1 (race condition)
- DECISIONS.md Cat-2 (stale pending state)" \
  "epic:0-foundation,type:infra,ios"

create_issue \
  "feat(foundation): PermissionCoordinator — kamera, rehber, takvim" \
  "## Bağlı Epic
#$E0

## Yapılacaklar
- [ ] \`PermissionCoordinator.swift\` — \`@MainActor final class\`
- [ ] \`requestCamera()\`, \`requestContacts()\`, \`requestCalendar()\` → \`PermResult\`
- [ ] \`.permanentlyDenied\` → \`openSettings()\` (UIApplication.openSettingsURLString)
- [ ] \`PermissionRationaleSheet\` component
- [ ] Permanent denial tracking — \`@AppStorage\` ile denial count
- [ ] WRITE_CONTACTS permanent denial → Settings route (Android'de eksikti)

## Kabul Kriterleri
- \`requestCamera()\` zaten .authorized ise tekrar dialog açmıyor
- .permanentlyDenied sonrası tekrar requestAccess çağrılmıyor

## Referanslar
- iOS_ARCHITECTURE.md §9
- Android Bug Cat-7 (permission loop)" \
  "epic:0-foundation,type:feat,ios"

create_issue \
  "feat(foundation): Onboarding + ProfileSetup + HomeView (boş)" \
  "## Bağlı Epic
#$E0

## Yapılacaklar
- [ ] \`OnboardingView\` — 3 sayfa \`TabView(.page)\`, privacy checkbox, Skip butonu
- [ ] \`@AppStorage(\"onboarding_done\")\` ve \`privacy_accepted\` flag'leri
- [ ] \`ProfileSetupView\` — firstName/lastName/company/title/phone/email alanları
- [ ] \`HomeView\` — boş state (kişi yok), Scan FAB, profil ikonu
- [ ] Scene blur modifikörü — \`scenePhase == .inactive\` → siyah overlay (FLAG_SECURE karşılığı)

## Kabul Kriterleri
- Onboarding → ProfileSetup → Home akışı çalışıyor
- Privacy checkbox işaretlenmeden ilerlenemiyor
- App background'a gidince içerik görünmüyor

## Referanslar
- iOS_ARCHITECTURE.md §7.2
- PROJECT_CONTEXT.md Onboarding bölümü" \
  "epic:0-foundation,type:feat,ios"

done "Epic 0 issue'ları tamam"

# =============================================================================
# EPIC 1 — OCR PIPELINE
# =============================================================================

log "Epic 1 — OCR Pipeline yaratılıyor..."

E1=$(create_issue \
  "Epic 1 — OCR Pipeline" \
  "## Hedef
Kartvizit çek → Alanlar gelsin → Düzenle.

## Scope
- CameraView (AVFoundation card capture + DataScannerViewController QR)
- VisionOCRService (VNRecognizeTextRequest — ML Kit yok)
- CardParser (Kotlin → Swift port)
- VCardParser (tek impl, ParseSource enum)
- ConfirmView + ConfirmViewModel
- Unit testler (CardParser, VCardParser)

## Çıktı
\`\`\`
Kartvizit çek
↓
Alanlar gelsin
↓
Düzenle
\`\`\`

## Referanslar
- iOS_ARCHITECTURE.md §4.5 (VCardParser)
- iOS_ARCHITECTURE.md §4.6 (CardParser)
- iOS_ARCHITECTURE.md §6 (CameraView, ConfirmView)
- PROJECT_CONTEXT.md — Card Scanning, QR Code Scanning, .vcf File Import
- DECISIONS.md Cat-4 (URI injection), Cat-9 (duplicate VCardParser)" \
  "epic:1-ocr,ios")
EPIC_ISSUES[1]=$E1
done "Epic 1 → #$E1"

create_issue \
  "feat(ocr): CameraView — AVFoundation card capture + QR DataScanner" \
  "## Bağlı Epic
#$E1

## Yapılacaklar
- [ ] \`CameraView.swift\` — \`AVCaptureSession\` ile fotoğraf çekimi (ön + arka yüz)
- [ ] Kart çerçeve overlay (CardFrameOverlay component)
- [ ] Galeri picker alternatifi (PhotosUI \`PhotosPicker\`)
- [ ] QR modu toggle — \`DataScannerViewController\` wrapper (\`DataScannerRepresentable\`)
- [ ] QR → vCard değilse Snackbar (non-vCard QR rejected)
- [ ] \`CameraViewModel\` — \`ScanFlowActor\`'a yazar; kamera izni \`PermissionCoordinator\`'dan alır
- [ ] Çift fotoğraf: ön + arka OCR text'i \"---\" separator ile merge

## Kabul Kriterleri
- vCard QR → ConfirmView'e yönleniyor
- Non-vCard QR → alert gösteriliyor
- Kamera izni reddinde Settings deep link çıkıyor

## Referanslar
- iOS_ARCHITECTURE.md §6 (CameraView detail)
- PROJECT_CONTEXT.md — QR Code Scanning" \
  "epic:1-ocr,type:feat,ios"

create_issue \
  "feat(ocr): VisionOCRService — VNRecognizeTextRequest wrapper" \
  "## Bağlı Epic
#$E1

## Yapılacaklar
- [ ] \`VisionOCRService.swift\` — \`VNRecognizeTextRequest\` async wrapper
- [ ] Dil tanıma: \`recognitionLanguages = [\"tr-TR\", \"en-US\"]\`
- [ ] İki görüntüden gelen text'i \"---\" ile merge (\`mergeTexts\`)
- [ ] OCR input 8,192 karakter ile sınırlı (\`FieldLimits.maxOCRInput\`)
- [ ] Hata durumu: \`VisionOCRError\` enum

## Kabul Kriterleri
- Gerçek kartvizit görüntüsünde isim + telefon çıkarıyor
- 8192+ char input clamp'leniyor

## Referanslar
- iOS_ARCHITECTURE.md §2 (VisionKit)
- PROJECT_CONTEXT.md — ML Kit on-device OCR" \
  "epic:1-ocr,type:feat,ios"

create_issue \
  "feat(ocr): CardParser — Kotlin'den Swift'e port" \
  "## Bağlı Epic
#$E1

## Yapılacaklar
- [ ] \`CardParser.swift\` — \`static func parseCardText(_ text: String) -> ParsedCard\`
- [ ] Tüm Kotlin Regex'lerini \`NSRegularExpression\` olarak port et
- [ ] Türkçe karakter desteği (NSRegularExpression Unicode-aware)
- [ ] Input clamp: \`text.prefix(FieldLimits.maxOCRInput)\`
- [ ] Şu parser özellikleri:
  - [ ] Faks / dahili numara hariç tutma
  - [ ] SOYAD Ad ters format algılama
  - [ ] Telefon cap: max 3
  - [ ] E-posta lowercase + boşluk temizleme
  - [ ] LinkedIn regex + URL normalizasyonu (\`URLValidator\`)
  - [ ] Şirket suffix tanıma (A.Ş., Ltd., Inc., vb.)
  - [ ] Unvan anahtar kelime tanıma (CEO, Müdür, Engineer, vb.)

## Kabul Kriterleri
- Tüm \`CardParserTests\` geçiyor (Android test coverage ile eşit)
- \`parseCardText(\"\")\` crash yapmıyor

## Referanslar
- iOS_ARCHITECTURE.md §4.6
- Android: \`domain/ocr/CardParser.kt\`" \
  "epic:1-ocr,type:feat,ios"

create_issue \
  "feat(ocr): VCardParser — tek impl, ParseSource enum, RFC 6350 unfold" \
  "## Bağlı Epic
#$E1

## Yapılacaklar
- [ ] \`VCardParser.swift\` — \`enum ParseSource { case file(URL), case string(String) }\`
- [ ] RFC 6350 §3.2 line unfolding her iki source'ta da uygulanıyor
- [ ] Field limit enforcement: phone 30, email 254, field 300, vCard 16384 bytes
- [ ] LinkedIn URL domain validation: \`URLValidator.validateLinkedIn\`
- [ ] \`VCardError.tooLarge\` thrown when over limit
- [ ] FN fallback: N alanı boşsa FN'den ad/soyad parse et

## Kabul Kriterleri
- Android'deki iki parser (vcf/ + vcard/) tek implementasyonla replace edildi
- evil.com LinkedIn URL'si reddediliyor
- RFC folded vCard doğru parse ediliyor

## Referanslar
- iOS_ARCHITECTURE.md §4.5
- DECISIONS.md Cat-9 (duplicate VCardParser)
- DECISIONS.md Cat-4 (URI injection)" \
  "epic:1-ocr,type:feat,ios"

create_issue \
  "feat(ocr): ConfirmView + ConfirmViewModel" \
  "## Bağlı Epic
#$E1

## Yapılacaklar
- [ ] \`ConfirmView\` — TabView fotoğraf pager (ön/arka), düzenlenebilir form
- [ ] Form alanları: Ad, Soyad, Şirket, Ünvan, Telefon(lar), E-posta(lar), Adres, LinkedIn, Not
- [ ] Dinamik telefon/e-posta satırları (ekle/sil)
- [ ] QR kaynak uyarı banner
- [ ] \"Yeniden Çek\" → geri dön
- [ ] \`ConfirmViewModel\` — \`ScanFlowActor\`'dan okur; OCR veya VCard parse eder; ContactStore'a kaydeder
- [ ] WRITE_CONTACTS izni — kaydetme öncesi \`PermissionCoordinator\`'dan
- [ ] \`@SceneStorage\` ile form draft recovery (process death fix)

## Kabul Kriterleri
- OCR sonucu form'da görünüyor
- Düzenlenmiş veri kaydediliyor
- Process kill sonrası form draft korunuyor

## Referanslar
- iOS_ARCHITECTURE.md §6 (ConfirmView)
- Android Bug Cat-3 (process death recovery)" \
  "epic:1-ocr,type:feat,ios"

create_issue \
  "test(ocr): CardParser + VCardParser unit testleri" \
  "## Bağlı Epic
#$E1

## Yapılacaklar
- [ ] \`CardParserTests.swift\` — Android \`CardParserTest.kt\` testlerinin birebir Swift karşılığı (42 test)
  - [ ] İsim, telefon, e-posta, adres, LinkedIn, şirket, unvan, edge case testleri
- [ ] \`VCardParserTests.swift\`
  - [ ] RFC 6350 line unfolding
  - [ ] Çok büyük vCard → \`VCardError.tooLarge\`
  - [ ] LinkedIn domain validation
  - [ ] Eksik N alanı — FN fallback
- [ ] \`URLValidatorTests.swift\`
  - [ ] evil.com reddediliyor
  - [ ] intent:// scheme reddediliyor
  - [ ] http (non-https) reddediliyor
  - [ ] https://linkedin.com/in/handle kabul ediliyor

## Kabul Kriterleri
- CardParser %100 line coverage
- VCardParser %100 line coverage
- URLValidator %100 line coverage

## Referanslar
- iOS_ARCHITECTURE.md §10
- Android: \`CardParserTest.kt\`" \
  "epic:1-ocr,type:test,ios"

done "Epic 1 issue'ları tamam"

# =============================================================================
# EPIC 2 — CONTACT STORAGE
# =============================================================================

log "Epic 2 — Contact Storage yaratılıyor..."

E2=$(create_issue \
  "Epic 2 — Contact Storage" \
  "## Hedef
DOMAIN_MODEL'deki tüm entity'ler SwiftData'da yaşıyor. CRUD + arama çalışıyor.

## Scope
- Contact struct validation (FieldLimits)
- ContactStore CRUD (SwiftData @ModelActor)
- ContactsView + ContactsViewModel (list, search, swipe)
- DetailView + DetailViewModel
- ContactEditView + ContactEditViewModel
- DeviceContactsService (CNContactStore)
- PhotoStorage
- Unit testler (ContactStore in-memory, DuplicateDetector)

## Referanslar
- iOS_ARCHITECTURE.md §4.1 (Contact struct)
- iOS_ARCHITECTURE.md §5.1 (ContactStore)
- DOMAIN_MODEL.md
- DECISIONS.md Cat-5 (LIKE injection → exact match)" \
  "epic:2-storage,ios")
EPIC_ISSUES[2]=$E2
done "Epic 2 → #$E2"

create_issue \
  "feat(storage): Contact struct + FieldLimits validation" \
  "## Bağlı Epic
#$E2

## Yapılacaklar
- [ ] \`Contact.swift\` struct — tüm alanlar \`init\`'te \`FieldLimits\` ile sınırlı
- [ ] \`FieldLimits.swift\` — tüm sabit değerler
- [ ] \`Contact.fullName\` computed property
- [ ] \`Contact: Identifiable, Hashable, Codable\`
- [ ] \`ParsedCard.swift\` — transient value type
- [ ] \`Event.swift\` — calendar event value type
- [ ] \`EmailTemplate.swift\` — value type + \`TemplateVars\` enum

## Kabul Kriterleri
- 301 char şirket adı init'te 300'e truncate ediliyor
- 4. telefon numarası eklenmek istenince max 3'te kalıyor

## Referanslar
- iOS_ARCHITECTURE.md §4.1
- DOMAIN_MODEL.md
- Android Bug Cat-6 (field limits)" \
  "epic:2-storage,type:feat,ios"

create_issue \
  "feat(storage): ContactStore — SwiftData CRUD + exact-match duplicate query" \
  "## Bağlı Epic
#$E2

## Yapılacaklar
- [ ] \`ContactStoreProtocol.swift\` — mock-friendly protocol
- [ ] \`ContactStore.swift\` — \`@ModelActor\`; insert, update, delete, fetchAll, fetchById, search, findDuplicate
- [ ] \`findDuplicate\` — \`#Predicate\` ile exact match (LIKE yok); array fields Swift'te karşılaştır
- [ ] \`search(query:)\` — in-memory filter; SQL LIKE wildcard injection riski yok
- [ ] Model → Domain mapping extensions (\`toDomain()\`, \`toModel()\`)

## Kabul Kriterleri
- CRUD round-trip testi in-memory ModelConfiguration ile geçiyor
- \`findDuplicate\` — phone değeri \"%\" olan kontakı tüm kişilerle eşleştirmiyor (Cat-5 fix)

## Referanslar
- iOS_ARCHITECTURE.md §5.1
- Android Bug Cat-5 (LIKE injection)" \
  "epic:2-storage,type:feat,ios"

create_issue \
  "feat(storage): ContactsView — liste, arama, swipe aksiyonları" \
  "## Bağlı Epic
#$E2

## Yapılacaklar
- [ ] \`ContactsView\` — \`List\` + \`searchable\` modifier (200ms debounce)
- [ ] \`ContactsViewModel\` — \`@Published\` contacts + search query; \`ContactStore\`'dan async stream
- [ ] Swipe aksiyonları: sol → sil (onay dialog), sağ → LinkedIn aç veya mail compose
- [ ] İlk açılışta swipe hint animasyonu
- [ ] Boş state — \"Kartvizit tara\" CTA
- [ ] Satır: initials avatar, fullName, company · title, eventName badge

## Kabul Kriterleri
- Arama 200ms debounce sonrası çalışıyor
- Silme → device rehber de temizleniyor (deviceContactID varsa)
- ICS dosyası da siliniyor

## Referanslar
- iOS_ARCHITECTURE.md §6
- PROJECT_CONTEXT.md — Contact List
- Android: \`ContactsViewModel.delete()\` — ICS temizleme fix (#133)" \
  "epic:2-storage,type:feat,ios"

create_issue \
  "feat(storage): DetailView — tappable fields, vCard share, edit/delete" \
  "## Bağlı Epic
#$E2

## Yapılacaklar
- [ ] \`DetailView\` — telefon (tel://), e-posta (mailto:), adres (maps://), LinkedIn
- [ ] LinkedIn açmadan önce \`URLValidator.validateLinkedIn\` kontrolü
- [ ] \`AsyncImage\` fotoğraf pager (TabView)
- [ ] \"Rehbere Ekle\" — \`deviceContactID == nil\` ise göster
- [ ] vCard paylaşımı — \`UIActivityViewController\` + RFC 6350 escape
- [ ] \`DetailViewModel\` — \`ContactStore.observeById\` Flow'u dinle
- [ ] Silme → \`DeviceContactsService.delete\` + photo files + ICS file

## Kabul Kriterleri
- vCard share'de özel karakterler RFC escape edilmiş
- LinkedIn https://linkedin.com/* dışı URL'ler açılmıyor

## Referanslar
- iOS_ARCHITECTURE.md §6
- Android Bug Cat-4 (URI injection)
- Android: DetailViewModel.shareContact()" \
  "epic:2-storage,type:feat,ios"

create_issue \
  "feat(storage): ContactEditView + DeviceContactsService sync" \
  "## Bağlı Epic
#$E2

## Yapılacaklar
- [ ] \`ContactEditView\` — ConfirmView form'unun düzenleme modu
- [ ] \`ContactEditViewModel\` — yükle, kaydet; WRITE_CONTACTS varsa \`DeviceContactsService.updateContact\`
- [ ] \`DeviceContactsService.swift\` — \`CNContactStore\` wrapper; \`addContact\`, \`updateContact\` (delete+reinsert), \`deleteContact\`
- [ ] \"Ad\" alanı zorunlu — \`canSave\` gate
- [ ] \`PhotoStorage.swift\` — Documents/photos/ dizini; yeni dosya URL üret, sil

## Kabul Kriterleri
- Düzenleme kaydedilince device rehber güncelleniyor (izin varsa)
- Notes alanı device rehbere de yazılıyor (Android #136 fix)

## Referanslar
- iOS_ARCHITECTURE.md §6
- Android Bug: ContactsRepository.updateContact — notes eksik (#136)" \
  "epic:2-storage,type:feat,ios"

done "Epic 2 issue'ları tamam"

# =============================================================================
# EPIC 3 — DUPLICATE FLOW
# =============================================================================

log "Epic 3 — Duplicate Flow yaratılıyor..."

E3=$(create_issue \
  "Epic 3 — Duplicate Flow" \
  "## Hedef
WORKFLOWS'taki duplicate akışı çalışıyor. Merge doğru.

## Scope
- DuplicateDetector pure function (no DB dependency)
- DuplicateView + DuplicateViewModel
- ContactMerge unit testleri

## Referanslar
- iOS_ARCHITECTURE.md §4.7 (DuplicateDetector)
- WORKFLOWS.md — Duplicate detection/merge
- DECISIONS.md Cat-2 (stale pending state fix)" \
  "epic:3-duplicate,ios")
EPIC_ISSUES[3]=$E3
done "Epic 3 → #$E3"

create_issue \
  "feat(duplicate): DuplicateDetector — pure function, no DB" \
  "## Bağlı Epic
#$E3

## Yapılacaklar
- [ ] \`DuplicateDetector.swift\` — \`static func findDuplicate(for:in:) -> Contact?\`
- [ ] Sıra: 1) ad+soyad+şirket, 2) telefon exact, 3) e-posta exact
- [ ] \`static func merge(existing:incoming:) -> Contact\`
  - [ ] Yeni non-empty alanlar eskinin üzerine yazar
  - [ ] E-postalar union + dedup
  - [ ] Fotoğraflar union + dedup
  - [ ] Notlar concat (distinct)
  - [ ] Mevcut \`id\` korunuyor
- [ ] \`ScanFlowActor\`'daki \`parsedCard\` flow bitiminde \`reset()\` ile temizleniyor

## Kabul Kriterleri
- Tüm \`ContactMergeTests\` geçiyor
- \`DuplicateDetector\` DB'ye erişmiyor (pure function)

## Referanslar
- iOS_ARCHITECTURE.md §4.7
- Android: DuplicateViewModel.mergeIntoExisting()
- Android Bug Cat-2 (stale pendingParsedCard)" \
  "epic:3-duplicate,type:feat,ios"

create_issue \
  "feat(duplicate): DuplicateView — diff görünüm, merge / yeni kayıt seçimi" \
  "## Bağlı Epic
#$E3

## Yapılacaklar
- [ ] \`DuplicateView\` — mevcut vs. yeni kişi yan yana diff
- [ ] \"Mevcut Güncelle\" → \`DuplicateDetector.merge\` + \`ContactStore.update\`
- [ ] \"Yeni Kayıt Oluştur\" → mevcut kişiyi olduğu gibi bırak
- [ ] \`DuplicateViewModel\` — \`ScanFlowActor\`'dan \`parsedCard\` alıyor; flow bitiminde \`reset()\` çağırıyor
- [ ] Geri butonu çalışıyor (Android #138 fix)

## Kabul Kriterleri
- Merge sonrası \`ScanFlowActor.parsedCard\` nil
- Yeni kişiyle duplicate kontrolü eşleşmiyor (self-exclusion)

## Referanslar
- iOS_ARCHITECTURE.md §6
- Android: #138 (geri butonu fix), #135 (notes kaybolma fix)" \
  "epic:3-duplicate,type:feat,ios"

create_issue \
  "test(duplicate): ContactMergeTests — Android ContactMergeTest.kt birebir port" \
  "## Bağlı Epic
#$E3

## Yapılacaklar
- [ ] \`ContactMergeTests.swift\` — 24 test (Android \`ContactMergeTest.kt\` ile aynı coverage)
  - [ ] firstName / company / title / address / linkedin — incoming wins when non-empty
  - [ ] Existing preserved when incoming empty
  - [ ] Phones — incoming replaces when non-empty, existing preserved when incoming empty
  - [ ] Emails — union dedup
  - [ ] Notes — concat distinct, identical not duped, empty cases
  - [ ] PhotoURLs — union dedup
  - [ ] ID retained

## Kabul Kriterleri
- 24/24 test geçiyor

## Referanslar
- iOS_ARCHITECTURE.md §10
- Android: \`ContactMergeTest.kt\`" \
  "epic:3-duplicate,type:test,ios"

done "Epic 3 issue'ları tamam"

# =============================================================================
# EPIC 4 — EVENT MATCHING
# =============================================================================

log "Epic 4 — Event Matching yaratılıyor..."

E4=$(create_issue \
  "Epic 4 — Event Matching" \
  "## Hedef
Kartvizit kaydedilince bugünün takvim etkinlikleri sunuluyor. Etkinlik seçilince kişiye bağlanıyor.

## Scope
- CalendarService (EKEventStore wrapper)
- EventMatchView + EventMatchViewModel
- Takvim izni — READ_CALENDAR denied → screen skip
- In-App Review trigger (ilk kayıtta)

## Referanslar
- iOS_ARCHITECTURE.md §6 (EventMatchView)
- WORKFLOWS.md — Calendar event matching
- Android: EventMatchViewModel, #139 (takvim izni reddinde snackbar)" \
  "epic:4-events,ios")
EPIC_ISSUES[4]=$E4
done "Epic 4 → #$E4"

create_issue \
  "feat(events): CalendarService — EKEventStore wrapper" \
  "## Bağlı Epic
#$E4

## Yapılacaklar
- [ ] \`CalendarService.swift\` — \`EKEventStore\`; \`getEventsForDay(start:end:)\`, \`getEventsBefore(_:limit:)\`
- [ ] \`Event\` domain model mapping (\`EKEvent → Event\`)
- [ ] \`SecurityException\` karşılığı: \`EKAuthorizationStatus\` kontrolü; izin yoksa boş dizi döndür
- [ ] Background thread'de çalışıyor (\`Task.detached\`)

## Kabul Kriterleri
- İzin yok → boş liste, crash yok
- Bugünkü etkinlikler DTSTART ASC sıralı

## Referanslar
- Android: \`CalendarRepository.kt\`" \
  "epic:4-events,type:feat,ios"

create_issue \
  "feat(events): EventMatchView + ViewModel — etkinlik seçimi, izin yönetimi" \
  "## Bağlı Epic
#$E4

## Yapılacaklar
- [ ] \`EventMatchView\` — aktif etkinlik / bugünkü liste / etkinlik yok state'leri
- [ ] \"Daha fazla yükle\" — önceki etkinlikler sayfalı yükleniyor
- [ ] Etkinlik seçimi → \`contact.eventID\`, \`contact.eventName\` güncelleniyor; notlara etkinlik ekleniyor
- [ ] \`PermissionCoordinator.requestCalendar()\` reddedilince → screen skip + Snackbar (Android #139 fix)
- [ ] \`EventMatchViewModel\` — WRITE_CONTACTS varsa rehbere yaz; yoksa Snackbar
- [ ] İlk kişi kaydında \`SKStoreReviewController.requestReview\` (In-App Review)

## Kabul Kriterleri
- Takvim izni reddinde uygulama donmuyor, home'a dönüyor
- Mevcut notların üzerine yazılmıyor (Android #134 fix)

## Referanslar
- iOS_ARCHITECTURE.md §6
- Android: #134 (notes overwrite fix), #139 (calendar perm fix)" \
  "epic:4-events,type:feat,ios"

done "Epic 4 issue'ları tamam"

# =============================================================================
# EPIC 5 — MAIL + TEMPLATES
# =============================================================================

log "Epic 5 — Mail + Templates yaratılıyor..."

E5=$(create_issue \
  "Epic 5 — Mail + Templates" \
  "## Hedef
Şablon seç → Değişkenler çözümleniyor → ICS ek ile mail gönderiliyor.

## Scope
- EmailTemplate SwiftData entity
- TemplatesView + TemplatesViewModel
- TemplateEditView + TemplateEditViewModel
- MailComposeView + MailComposeViewModel
- ICSGenerator (RFC 5545)
- ICSGenerator unit testleri

## Referanslar
- iOS_ARCHITECTURE.md §6 (MailComposeView)
- iOS_ARCHITECTURE.md §4 (ICSGenerator snippet)
- WORKFLOWS.md — Mail compose, ICS
- DECISIONS.md Cat-10 (ICS MIME type fix)" \
  "epic:5-mail,ios")
EPIC_ISSUES[5]=$E5
done "Epic 5 → #$E5"

create_issue \
  "feat(mail): EmailTemplate SwiftData entity + 5 varsayılan şablon seed" \
  "## Bağlı Epic
#$E5

## Yapılacaklar
- [ ] \`EmailTemplateModel\` — \`@Model\`; id, name, iconName, subject, body, isDefault, sortOrder
- [ ] \`EmailTemplateStore\` — \`@ModelActor\`; CRUD + reset to default
- [ ] 5 varsayılan şablon seed (Tanışma, İş Birliği, Bilgi Talebi, Takip, Toplantı Daveti)
- [ ] \`TemplateVars\` enum — \`[Ad]\`, \`[Tam Ad]\`, \`[Etkinlik]\`, \`[Benim Adım]\`, \`[Ünvanım]\`, \`[Şirketim]\`
- [ ] Token syntax kullanıcıya gösterilmiyor (UI'da chip olarak render) — Android #117 fix

## Kabul Kriterleri
- 5 default şablon ilk açılışta var
- Silinen default şablon reset ile geri yüklenebiliyor

## Referanslar
- DOMAIN_MODEL.md — EmailTemplate
- Android: #117 (token syntax fix)" \
  "epic:5-mail,type:feat,ios"

create_issue \
  "feat(mail): TemplatesView + TemplateEditView" \
  "## Bağlı Epic
#$E5

## Yapılacaklar
- [ ] \`TemplatesView\` — şablon listesi; swipe-to-delete, swipe-to-reset
- [ ] \`TemplatesViewModel\` — Flow'dan şablonlar
- [ ] \`TemplateEditView\` — isim, konu, gövde; değişken chip'leri (\`AttributedString\`)
- [ ] \`TemplateEditViewModel\` — yeni şablon (\`id: \"new\"\`) ve mevcut düzenleme

## Kabul Kriterleri
- Chip'e dokunma → cursor konumuna \`[Token]\` ekleniyor
- Default şablon reset sonrası orijinal içeriğe dönüyor

## Referanslar
- PROJECT_CONTEXT.md — Email Templates" \
  "epic:5-mail,type:feat,ios"

create_issue \
  "feat(mail): ICSGenerator — RFC 5545 uyumlu toplantı daveti" \
  "## Bağlı Epic
#$E5

## Yapılacaklar
- [ ] \`ICSGenerator.swift\` — \`async func generate(contact:organizer:start:end:description:) throws -> URL\`
- [ ] RFC 5545 TEXT escaping (\\\\, \\;, \\,, \\n)
- [ ] Line folding — 75 octet'te kat
- [ ] UTC tarih formatı (\`yyyyMMdd'T'HHmmss'Z'\`)
- [ ] E-posta validasyonu — geçersizse ORGANIZER/ATTENDEE alanı yazılmıyor
- [ ] UID: \`{contactID}-{startMs}@cardconnect\`
- [ ] Dosya: \`FileManager.default.temporaryDirectory/invite_{id}.ics\`
- [ ] \`UTType.calendarEvent\` ile \`UIActivityViewController\` — Android #Cat-10 fix

## Kabul Kriterleri
- Üretilen .ics iOS Calendar'da açılıyor
- 75 char üzeri satır fold'leniyor
- Geçersiz email → ORGANIZER satırı yok

## Referanslar
- iOS_ARCHITECTURE.md §4 (ICSGenerator snippet)
- DECISIONS.md Cat-10
- Android: IcsGenerator.kt" \
  "epic:5-mail,type:feat,ios"

create_issue \
  "feat(mail): MailComposeView — şablon seçici, değişken çözümleme, ICS ek" \
  "## Bağlı Epic
#$E5

## Yapılacaklar
- [ ] \`MailComposeView\` — template chip scroll, kişi seçici (contactID yoksa)
- [ ] Değişken çözümleme: \`[Ad]\` → contact.firstName, \`[Etkinlik]\` boşsa ilgili cümle silinuyor (Android #116 fix)
- [ ] Eksik profil değişkeni uyarı banner (örn. \`[Şirketim]\` boşsa)
- [ ] Toplantı daveti toggle → tarih/saat picker → ICSGenerator
- [ ] Takvim çakışma algılama: aynı günkü etkinlikler kırmızı gösteriliyor
- [ ] \`MFMailComposeViewController\` wrapper (\`UIViewControllerRepresentable\`)
- [ ] Mail gönderilince analytics log

## Kabul Kriterleri
- \`[Etkinlik]\` token'ı boşken gövdede bozuk metin görünmüyor
- ICS eki mail'e eklenmiş şekilde açılıyor

## Referanslar
- WORKFLOWS.md — Mail compose
- Android: #116 ([Etkinlik] bozuk metin fix)" \
  "epic:5-mail,type:feat,ios"

create_issue \
  "test(mail): ICSGeneratorTests — RFC 5545 doğrulama" \
  "## Bağlı Epic
#$E5

## Yapılacaklar
- [ ] \`ICSGeneratorTests.swift\`
  - [ ] UTC tarih formatı doğru
  - [ ] 76+ char satır fold'leniyor
  - [ ] RFC TEXT escape — \\; \\, \\\\ \\n
  - [ ] Geçersiz e-posta → ORGANIZER/ATTENDEE satırı yok
  - [ ] BEGIN:VCALENDAR / END:VCALENDAR yapısı sağlam

## Kabul Kriterleri
- %100 line coverage

## Referanslar
- iOS_ARCHITECTURE.md §10
- Android: IcsGenerator.kt" \
  "epic:5-mail,type:test,ios"

done "Epic 5 issue'ları tamam"

# =============================================================================
# EPIC 6 — PROFILE + QR
# =============================================================================

log "Epic 6 — Profile + QR yaratılıyor..."

E6=$(create_issue \
  "Epic 6 — Profile + QR" \
  "## Hedef
Kullanıcı kendi kartını oluşturuyor, QR ile paylaşıyor.

## Scope
- UserProfile (Keychain)
- ProfileView + ProfileViewModel
- QR kodu oluşturma (CoreImage)
- QR paylaşma
- OCR ile kendi kartından profil doldurma

## Referanslar
- iOS_ARCHITECTURE.md §5.4 (UserProfileStore)
- PROJECT_CONTEXT.md — User Profile, QR Generation
- DECISIONS.md §6 (EncryptedSharedPreferences → Keychain)" \
  "epic:6-profile,ios")
EPIC_ISSUES[6]=$E6
done "Epic 6 → #$E6"

create_issue \
  "feat(profile): ProfileView + ProfileViewModel — Keychain'den okuma/yazma" \
  "## Bağlı Epic
#$E6

## Yapılacaklar
- [ ] \`ProfileView\` — ad, soyad, şirket, ünvan, telefon, e-posta, linkedin, website, avatar
- [ ] \`ProfileViewModel\` — \`UserProfileStore\` (actor) üzerinden async load/save
- [ ] Avatar: \`PhotosPicker\` (galeri) veya kamera
- [ ] Ön/arka kart fotoğrafı — OCR ile profil doldurma (\`VisionOCRService\` + \`CardParser\`)
- [ ] Kaydetme → \`_saveResult\` SharedFlow eşdeğeri (\`@Published\` + \`AsyncStream\`)

## Kabul Kriterleri
- Profil Keychain'de JSON encoded
- OCR ile doldurulan alan mevcut değerin üzerine yazıyor

## Referanslar
- Android: ProfileViewModel.kt, PreferencesRepository.kt" \
  "epic:6-profile,type:feat,ios"

create_issue \
  "feat(profile): QR kodu oluşturma ve paylaşma" \
  "## Bağlı Epic
#$E6

## Yapılacaklar
- [ ] \`CoreImage.CIFilter.qrCodeGenerator\` — profil vCard 3.0 içeriğinden QR üret
- [ ] QR görüntüleme: \`HomeView\` içinde sheet olarak
- [ ] QR paylaşma: \`UIActivityViewController\`
- [ ] HomeView'da profil boşken QR sheet engelleniyor — boş profil uyarısı (Android #141 fix)

## Kabul Kriterleri
- Üretilen QR başka cihazda okunuyor
- Profil boşken QR butonu tıklanamıyor veya uyarı gösteriyor

## Referanslar
- PROJECT_CONTEXT.md — QR Generation
- Android: #141 (boş profil QR fix)" \
  "epic:6-profile,type:feat,ios"

done "Epic 6 issue'ları tamam"

# =============================================================================
# EPIC 7 — SECURITY HARDENING
# =============================================================================

log "Epic 7 — Security Hardening yaratılıyor..."

E7=$(create_issue \
  "Epic 7 — Security Hardening" \
  "## Hedef
Android'de başta yapılmayıp sonra issue'lar açılan güvenlik önlemleri iOS'ta en baştan var.

## Scope
- Jailbreak detection
- iCloud backup exclusion
- Privacy Policy screen + KVKK
- App Store hazırlık (Privacy Manifest, export compliance)
- Security review

## Referanslar
- iOS_ARCHITECTURE.md §7
- DECISIONS.md — Security Decisions Summary
- Android: #119 (FLAG_SECURE), #120 (root detection), #157 (FileProvider scope)" \
  "epic:7-security,ios")
EPIC_ISSUES[7]=$E7
done "Epic 7 → #$E7"

create_issue \
  "feat(security): JailbreakDetector + uygulama açılış uyarısı" \
  "## Bağlı Epic
#$E7

## Yapılacaklar
- [ ] \`JailbreakDetector.swift\` — dosya varlığı, sandbox dışı yazma, dylib kontrolü
- [ ] Simulator build'de \`#if targetEnvironment(simulator)\` → false döner
- [ ] \`MainActivity\` karşılığı: uygulama başında \`JailbreakDetector.isJailbroken\` kontrolü
- [ ] Uyarı dialog — \"Devam Et\" / \"Çıkış\" (non-blocking)

## Kabul Kriterleri
- Jailbreak tespitinde dialog çıkıyor
- Simulator'da false alarm yok

## Referanslar
- iOS_ARCHITECTURE.md §7.1
- Android: SecurityUtils.kt, #120" \
  "epic:7-security,type:security,ios"

create_issue \
  "feat(security): iCloud backup exclusion — photos, ics, vcf, DB" \
  "## Bağlı Epic
#$E7

## Yapılacaklar
- [ ] photos/, ics/, vcf/ dizinlerine ilk açılışta \`isExcludedFromBackup = true\`
- [ ] SwiftData DB dosyasına \`isExcludedFromBackup = true\`
- [ ] UserProfile (Keychain) — zaten backup'a gitmez; doğrula
- [ ] \`@AppStorage\` değerleri (onboarding flags) — backup'a gidebilir (kasıtlı)

## Kabul Kriterleri
- Xcode Organizer'da iCloud backup size'ında photos dizini görünmüyor

## Referanslar
- iOS_ARCHITECTURE.md §7
- DECISIONS.md §11 (Backup Rules)
- Android: backup_rules.xml" \
  "epic:7-security,type:security,ios"

create_issue \
  "feat(security): Scene blur — inactive/background'da içerik gizleme" \
  "## Bağlı Epic
#$E7

## Yapılacaklar
- [ ] \`ScreenshotProtectionModifier\` — \`scenePhase == .inactive\` → siyah overlay
- [ ] \`RootNavigationView\`'a \`.modifier(ScreenshotProtectionModifier())\` ekle
- [ ] Hassas alanlarda (\`notes\`, \`phones\`) \`textContentType\` uygun set edilmiş

## Kabul Kriterleri
- App switcher thumbnail'ında içerik görünmüyor

## Referanslar
- iOS_ARCHITECTURE.md §7.2
- Android: FLAG_SECURE (#119)" \
  "epic:7-security,type:security,ios"

create_issue \
  "feat(security): PrivacyPolicyView + KVKK onay akışı" \
  "## Bağlı Epic
#$E7

## Yapılacaklar
- [ ] \`PrivacyPolicyView\` — gizlilik politikası metni
- [ ] Onboarding son sayfasında KVKK checkbox — onaysız ilerlenemiyor
- [ ] Settings → Gizlilik Politikası linki
- [ ] \`privacy_accepted\` \`@AppStorage\` flag

## Kabul Kriterleri
- KVKV checkbox işaretlenmeden ProfileSetup'a geçilemiyor

## Referanslar
- PROJECT_CONTEXT.md — Onboarding, Settings
- Android: OnboardingScreen privacy checkbox" \
  "epic:7-security,type:security,ios"

create_issue \
  "chore(security): App Store hazırlık — Privacy Manifest + export compliance" \
  "## Bağlı Epic
#$E7

## Yapılacaklar
- [ ] \`PrivacyInfo.xcprivacy\` — kullanılan API'ler beyan edilmiş (NSPrivacyAccessedAPITypes)
  - [ ] \`NSFileSystemAPI\` — photos/ics/vcf dosya erişimi
  - [ ] \`NSUserDefaultsAPI\` — @AppStorage flag'leri
- [ ] Export Compliance — şifreleme kullanımı (Keychain AES) App Store Connect'te beyan
- [ ] Tüm \`Info.plist\` usage description string'leri yazılmış
- [ ] \`NSCameraUsageDescription\`, \`NSContactsUsageDescription\`, \`NSCalendarsFullAccessUsageDescription\`

## Kabul Kriterleri
- Xcode Privacy Report uyarısız
- TestFlight yüklemesi export compliance hatası vermiyor

## Referanslar
- iOS_ARCHITECTURE.md §11 (unused permissions anti-pattern)" \
  "epic:7-security,type:security,ios"

create_issue \
  "chore(security): Security review — iOS_ARCHITECTURE Bug Prevention Matrix doğrulama" \
  "## Bağlı Epic
#$E7

## Yapılacaklar
- [ ] iOS_ARCHITECTURE.md §1 Bug Prevention Matrix'teki her madde uygulanmış mı kontrol et
- [ ] \`ScanFlowActor\` — Swift actor isolation uyarısı yok
- [ ] \`ContactStore.findDuplicate\` — LIKE query yok
- [ ] \`VCardParser\` — tek implementasyon, iki dosya yok
- [ ] \`URLValidator\` — tüm LinkedIn URL'leri valide ediliyor
- [ ] \`Contact.init\` — tüm field limit'ler enforce ediliyor
- [ ] \`PermissionCoordinator\` — permanent denial loop yok
- [ ] Backup exclusion — tüm dizinler için
- [ ] Jailbreak detection — simulator false alarm yok

## Kabul Kriterleri
- Matrix'teki 14 maddeden 14'ü geçiyor

## Referanslar
- iOS_ARCHITECTURE.md §1" \
  "epic:7-security,type:security,ios"

done "Epic 7 issue'ları tamam"

# =============================================================================
# ÖZET
# =============================================================================

echo ""
echo "=============================================="
echo -e "${GREEN}✅ Tüm issue'lar yaratıldı${NC}"
echo "=============================================="
echo ""
echo "Epic'ler:"
echo "  Epic 0 — Foundation      → #${EPIC_ISSUES[0]}"
echo "  Epic 1 — OCR Pipeline    → #${EPIC_ISSUES[1]}"
echo "  Epic 2 — Contact Storage → #${EPIC_ISSUES[2]}"
echo "  Epic 3 — Duplicate Flow  → #${EPIC_ISSUES[3]}"
echo "  Epic 4 — Event Matching  → #${EPIC_ISSUES[4]}"
echo "  Epic 5 — Mail + Templates→ #${EPIC_ISSUES[5]}"
echo "  Epic 6 — Profile + QR   → #${EPIC_ISSUES[6]}"
echo "  Epic 7 — Security        → #${EPIC_ISSUES[7]}"
echo ""
echo "Repo: https://github.com/$REPO/issues"
