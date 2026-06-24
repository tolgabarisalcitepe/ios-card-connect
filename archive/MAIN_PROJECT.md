# MAIN_PROJECT.md — Card Connect iOS
> **Amaç:** Bu dosya iOS projesini baştan sona kodlatmak için yeterli tek referans kaynağıdır.  
> Android projesine bir daha bakmanıza gerek yoktur.

---

## İçindekiler

1. [Uygulama Amacı & Hedef Kitle](#1-uygulama-amacı--hedef-kitle)
2. [Tech Stack](#2-tech-stack)
3. [Tam Özellik Listesi](#3-tam-özellik-listesi)
4. [Domain Modeli](#4-domain-modeli)
5. [Proje Klasör Yapısı](#5-proje-klasör-yapısı)
6. [Mimari Katmanlar & Bileşenler](#6-mimari-katmanlar--bileşenler)
7. [Bug Önleme Matrisi](#7-bug-önleme-matrisi)
8. [Ekran Envanteri & Navigasyon](#8-ekran-envanteri--navigasyon)
9. [Kullanıcı Akışları](#9-kullanıcı-akışları)
10. [Email Şablonları](#10-email-şablonları)
11. [Güvenlik Katmanı](#11-güvenlik-katmanı)
12. [Test Stratejisi](#12-test-stratejisi)
13. [Kod Kuralları & Anti-Pattern'ler](#13-kod-kuralları--anti-patternler)
14. [Release & App Store Gereksinimleri](#14-release--app-store-gereksinimleri)

---

## 1. Uygulama Amacı & Hedef Kitle

**Card Connect**, Türkçe dilli bir iOS uygulamasıdır. Fiziksel kartvizitleri kamera ile dijitalleştirerek profesyonel kişi yönetimi sağlar.

**Değer önerisi:** Kartviziti telefona göster → OCR metin çıkarır → form onayla → şifreli veritabanına kaydet. Opsiyonel olarak telefon rehberine senkronize et, Türkçe şablonla mail gönder, takvim etkinliğiyle eşleştir.

**Hedef kullanıcılar:**
- Türkçe konuşan iş profesyonelleri
- Konferans ve fuar katılımcıları
- Dijitalleştirmek istediği kartvizit yığını olan herkes
- Tanıştıktan hemen sonra Türkçe şablon mail göndermek isteyenler

**Önemli kısıtlar:**
- Hiç network isteği yok — tüm işlem cihazda
- KVKK uyumluluğu: iCloud backup kapalı, analytics yok
- Türkçe UI metinleri (localizable anchor: Türkçe öncelikli)
- iOS 17+ deployment target

---

## 2. Tech Stack

| Katman | Teknoloji | Notlar |
|--------|-----------|--------|
| Dil | Swift 5.10+ | Swift 6 strict concurrency mode etkin |
| UI | SwiftUI | iOS 17+ deployment target |
| Veritabanı | SwiftData | `@Model`, `@ModelActor`, versioned schema |
| Güvenli depolama | Keychain (Security framework) | DB key, UserProfile PII |
| Flags/ayarlar | `@AppStorage` (UserDefaults) | Yalnızca hassas olmayan bayraklar |
| Async | Swift Concurrency | `async/await`, `AsyncStream`, `actor` — Combine YASAK |
| Navigasyon | `NavigationStack` + `NavigationPath` | Typed routes, string route YASAK |
| Kamera/OCR | `AVFoundation` + VisionKit (`VNRecognizeTextRequest`) | Kart OCR |
| QR Tarama | `DataScannerViewController` (iOS 16+) | ML Kit gerekmez |
| QR Üretme | `CoreImage.CIFilter.qrCodeGenerator` | On-device |
| Kişiler | `CNContactStore` + `CNSaveRequest` | |
| Takvim | `EKEventStore` (EventKit) | |
| Mail | `MFMailComposeViewController` + `UIActivityViewController` | |
| Görsel yükleme | `AsyncImage` (SwiftUI native) | |
| Şifreleme | CryptoKit + Keychain | AES-GCM |
| DI | `@Environment` + protocol-based `DependencyContainer` | Swinject/Factory yok |
| Test | XCTest + Swift Testing | Unit + UI testler |
| Linting | SwiftLint | CI'da zorunlu |

---

## 3. Tam Özellik Listesi

### 3.1 Kartvizit Tarama (OCR Akışı)
- AVFoundation canlı kamera önizlemesi + kart şekli overlay (1.6:1 aspect ratio)
- İki aşamalı çekim: ön fotoğraf → "arka yüz var mı?" dialog → opsiyonel arka fotoğraf
- Alternatif: Galeri'den fotoğraf seçme (PhotosPicker)
- VisionKit `VNRecognizeTextRequest` — on-device OCR (internet gerektirmez)
- Çift görsel OCR: ön + arka metinler `\n---\n` ile birleştirilerek parse edilir
- 8.192 karakter giriş limiti (parse öncesi)
- `CardParser.parseCardText()`: kural tabanlı alan çıkarımı
  - Ad, Soyad, Şirket, Ünvan, Telefon (maks 3), Email, Adres, LinkedIn
  - Türkçe ve uluslararası format desteği
  - Türkçe şirket sonekleri: A.Ş., Ltd., Tic., San., Şti. vb.
  - Ünvan anahtar kelimeleri: CEO, Müdür, Mühendis, Direktör vb.
  - Ters isim formatı tespiti (SOYAD Ad)
  - Faks ve dahili numara hariç tutma
  - Etiket ön eki temizleme: Tel:, E-mail:, GSM: vb.

### 3.2 QR Kod Tarama
- Kamera ekranında Kartvizit / QR mod geçişi
- `DataScannerViewController` ile barkod tarama
- vCard formatlı QR kodlar → aynı Onayla akışı
- vCard olmayan QR kodlar → uyarı mesajı ile reddedilir

### 3.3 .vcf Dosyası İçe Aktarma
- `Info.plist` UTI kaydı: `public.vcard` ve `public.x-vcard`
- `onOpenURL` ile dosya yakalanır → `VCardParser.parse(.file(url))`
- Uygulama doğrudan Onayla ekranından açılır (kamerayı atlar)
- RFC 6350 satır katlaması çözme (line unfolding) uygulanır
- Dosya boyutu limiti: 16.384 byte

### 3.4 Kişi Onayla & Düzenle Ekranı
- OCR'dan çıkarılan alanlarla dolu düzenlenebilir form
- Alanlar: Ad, Soyad, Şirket, Ünvan, Telefon(lar), E-posta(lar), Adres, LinkedIn, Not
- Dinamik telefon/email satırları: ekle ve sil
- QR kaynağı uyarı banner'ı
- "Yeniden Çek" butonu kameraya döner
- Kaydet: SwiftData (yerel) + opsiyonel CNContactStore sync

### 3.5 Duplikat Tespiti & Birleştirme
- Kayıt sonrası otomatik duplikat kontrolü
- Eşleşme kriterleri (sırayla):
  1. firstName + lastName + company hepsinin eşleşmesi (üçü de dolu olmalı)
  2. Herhangi bir telefon numarasının exact match
  3. Herhangi bir email adresinin exact match (küçük harf normalize edilmiş)
- Duplikat bulunursa: alan bazında diff view
- İki seçenek: "Mevcut kaydı güncelle" (merge) veya "Yeni kayıt oluştur"
- Birleştirme kuralları (→ Bkz. §4.5 Business Rules)

### 3.6 Etkinlik Eşleştirme
- Duplikat kontrolü sonrası otomatik tetiklenir
- EKEventStore ile bugünkü takvim etkinlikleri okunur
- Üç durum: aktif etkinlik, bugünkü etkinlikler listesi, etkinlik yok
- "Daha fazla" ile 20'şer geçmiş etkinlik yüklenir
- Etkinlik seçimi: `eventID` + `eventName` kişiye eklenir, notes'a etkinlik bağlamı eklenir
- CNContacts izni olmadan da çalışır (sadece SwiftData kaydeder)

### 3.7 Kişi Listesi
- SwipeActions: sola → sil (onay dialog'u), sağa → LinkedIn aç veya mail gönder
- İlk açılışta swipe ipucu animasyonu
- `searchable` modifier ile arama (200ms debounce)
- Arama alanları: isim, şirket, ünvan, etkinlik adı
- Boş durum: "Kartvizit Tara" CTA
- Satır: baş harfler avatar, tam ad, şirket · ünvan, etkinlik badge

### 3.8 Kişi Detay Görünümü
- Tıklanabilir telefon (tel:), email (mailto:), adres (maps:), LinkedIn (https: scheme kontrolü)
- Yatay fotoğraf pager (nokta göstergeli)
- "Rehbere Ekle" butonu (deviceContactID null ise görünür)
- .vcf olarak paylaş (`UIActivityViewController`)
- Düzenle ve Sil top bar aksiyonları
- Canlı güncelleme: SwiftData değişiklikleri otomatik yansır

### 3.9 Kişi Düzenle Ekranı
- Onayla ekranıyla aynı form; mevcut verilerle dolu
- Kaydet: SwiftData + CNSaveRequest (deviceContactID dolu ve izin varsa)
- "Ad" alanı zorunlu (canSave gate)

### 3.10 Email Şablonları
- 5 varsayılan Türkçe şablon (§10'a bakın)
- Şablon değişkenleri: `[Ad]`, `[Tam Ad]`, `[Etkinlik]`, `[Benim Adım]`, `[Ünvanım]`, `[Şirketim]`
- Listede renkli chip'ler ile token önizlemesi
- Sola kaydırma: varsayılanları sıfırla, özel şablonları sil
- Özel şablon oluşturma
- Şablonlar SwiftData'da saklanır (EmailTemplateModel)

### 3.11 Mail Oluşturma
- Yatay kaydırmalı şablon chip seçici
- Şablon değişkenleri kişi + kullanıcı profiliyle çözülür
- Eksik değişken uyarı banner'ı
- `[Etkinlik]` boşsa: içeren cümle body'den çıkarılır, subject'taki çizgi temizlenir
- "Toplantı Daveti Ekle" toggle: RFC 5545 uyumlu .ics dosyası üretir
- Takvim çakışma tespiti: aynı gün etkinlikleri kırmızı gösterilir
- Tarih/saat seçici
- `MFMailComposeViewController` veya `UIActivityViewController` ile gönderim
- Mail uygulaması yoksa kullanıcıya bildirim

### 3.12 Kullanıcı Profili
- Kendi kartvizit bilgileri: Ad, Soyad, Şirket, Ünvan, Telefon, Email, LinkedIn, Website, Avatar
- Şablon değişkenlerini çözer: `[Benim Adım]`, `[Ünvanım]`, `[Şirketim]`
- OCR self-scan: kendi kartını fotoğraflayarak profil alanlarını doldurma
- Avatar: galeri veya kamera
- QR kod üretimi (CoreImage): profil vCard 3.0 formatında, görüntülenebilir ve paylaşılabilir
- Keychain'de JSON olarak saklanır (PII içerdiğinden UserDefaults değil)

### 3.13 Onboarding
- 3 sayfalık yatay TabView (PageTabViewStyle)
- Sayfa 1: "Kartvizit Tara" özellik tanıtımı
- Sayfa 2: "Şablonla Mail Gönder" özellik tanıtımı
- Sayfa 3: "Bağlantılarını Yönet" + KVKK/gizlilik onay checkbox'ı (zorunlu)
- "Atla" butonu sayfa 1-2'de mevcut
- "Profili Kur" butonu onay checkbox'ı işaretlenmeden tıklanamaz
- Tamamlanınca `onboarding_done` + `privacy_accepted` @AppStorage bayrakları set edilir

### 3.14 Ayarlar
- Gizlilik Politikası → PrivacyPolicyView
- KVKK Aydınlatma Metni → aynı view
- "Arkadaşına Öner" → App Store linki içeren UIActivityViewController

---

## 4. Domain Modeli

### 4.1 Contact (Value Type)

```swift
// Domain/Model/Contact.swift
struct Contact: Identifiable, Hashable, Codable {
    let id: UUID
    var firstName:        String    // max 100 chars
    var lastName:         String    // max 100 chars
    var company:          String    // max 300 chars
    var title:            String    // max 300 chars
    var phones:           [String]  // max 3 items; each max 30 chars
    var emails:           [String]  // each max 254 chars (RFC 5321)
    var address:          String    // max 300 chars
    var notes:            String    // max 2000 chars
    var linkedin:         String    // validated https://linkedin.com/in/... or ""
    var eventID:          String?
    var eventName:        String?
    var photoURLs:        [URL]     // file:// URLs in Documents/photos/
    var deviceContactID:  String?   // CNContact rawContactId
    let createdAt:        Date
    var updatedAt:        Date

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
        self.id             = id
        self.firstName      = String(firstName.prefix(FieldLimits.maxNameField))
        self.lastName       = String(lastName.prefix(FieldLimits.maxNameField))
        self.company        = String(company.prefix(FieldLimits.maxField))
        self.title          = String(title.prefix(FieldLimits.maxField))
        self.phones         = Array(phones.map { String($0.prefix(FieldLimits.maxPhone)) }.prefix(3))
        self.emails         = emails.map { String($0.prefix(FieldLimits.maxEmail)).lowercased() }
        self.address        = String(address.prefix(FieldLimits.maxField))
        self.notes          = String(notes.prefix(FieldLimits.maxNotes))
        self.linkedin       = URLValidator.validateLinkedIn(linkedin) ? linkedin : ""
        self.eventID        = eventID
        self.eventName      = eventName
        self.photoURLs      = photoURLs
        self.deviceContactID = deviceContactID
        self.createdAt      = createdAt
        self.updatedAt      = updatedAt
    }
}
```

### 4.2 ParsedCard (Geçici Tarama Sonucu)

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

### 4.3 EmailTemplate (Value Type)

```swift
// Domain/Model/EmailTemplate.swift
struct EmailTemplate: Identifiable, Codable {
    let id: UUID            // "default_1"..."default_5" varsayılanlar için sabit UUID; özel için random
    var name:       String  // Görünen ad
    var iconName:   String  // SF Symbol adı: "hands.wave", "briefcase", "questionmark.circle", "arrowshape.turn.up.left", "calendar"
    var subject:    String  // [Variable] token'lı konu satırı
    var body:       String  // [Variable] token'lı çok satırlı gövde
    var isDefault:  Bool    // true: sıfırlama yapılır, silinmez
    var sortOrder:  Int
}
```

### 4.4 Event (Read-Only Takvim Projeksiyonu)

```swift
// Domain/Model/Event.swift
struct Event: Identifiable {
    let id:        String   // EKEvent.eventIdentifier
    let name:      String
    let startTime: Date
    let endTime:   Date

    func isActiveAt(_ date: Date) -> Bool {
        date >= startTime && date <= endTime
    }
}
```

### 4.5 UserProfile (Keychain'de JSON)

```swift
// Domain/Model/UserProfile.swift
struct UserProfile: Codable {
    var firstName:     String = ""
    var lastName:      String = ""
    var company:       String = ""
    var title:         String = ""
    var phone:         String = ""
    var email:         String = ""  // ICS ORGANIZER için email doğrulaması gerekir
    var linkedin:      String = ""
    var website:       String = ""
    var avatarPath:    String = ""  // Documents/avatar.jpg
    var frontCardPath: String = ""  // Kendi kartının ön yüzü
    var backCardPath:  String = ""  // Kendi kartının arka yüzü

    var fullName: String { "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces) }
    var initials: String {
        let parts = fullName.split(separator: " ")
        return parts.prefix(2).compactMap { $0.first }.map(String.init).joined().uppercased().isEmpty
            ? "?" : parts.prefix(2).compactMap { $0.first }.map(String.init).joined().uppercased()
    }
}
```

### 4.6 Field Limits

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

### 4.7 Business Rules & İnvaryantlar

**Contact İnvaryantları:**
1. `id` asla null değildir; oluşturulurken set edilir; hiç değişmez
2. `firstName` kaydetmek için boş olamaz (UI gate, SwiftData enforce etmez)
3. `phones` listesi OCR'dan gelince maks 3 eleman içerir
4. `emails` küçük harfe normalize edilmiş olmalı
5. `photoURLs` `Documents/photos/` içini gösterir
6. `eventID` ve `eventName` her zaman birlikte set/clear edilir
7. Etkinlik seçilince notes'a eklenen cümle: `"X etkinliğinde tanıştınız — D Ay Y"`
8. `updatedAt` her güncellemede `Date.now` olarak set edilir
9. Kişi silinince: fotoğraflar diskten silinir, `Documents/ics/invite_{id}.ics` de silinir
10. Duplikat kontrolünde yeni kaydedilen kişi sonuçlardan hariç tutulur

**Duplikat Kuralları (sırayla değerlendirilir, ilk eşleşme kazanır):**
1. firstName + lastName + company hepsinin eşleşmesi (üçü de dolu olmalı)
2. Gelen karttaki herhangi bir telefon mevcut kişinin telefonlarıyla exact match
3. Gelen karttaki herhangi bir email mevcut kişinin email'leriyle exact match (lowercase)

**Birleştirme Kuralları (merge):**
- firstName, lastName, company, title, address, linkedin: gelen değer doluysa kazanır; doluysa mevcut saklanır
- phones: gelen liste doluysa kazanır
- emails: union, deduplicate
- photoURLs: union, deduplicate
- notes: her ikisi de `\n` ile birleştirilir, yinelenen satırlar kaldırılır
- deviceContactID: mevcut kişinin değeri korunur
- id, createdAt: mevcut kişinin değerleri korunur
- updatedAt: `Date.now`
- Birleştirme sonrası: yeni kişi SwiftData'dan silinir, mevcut kişi güncellenir

**EmailTemplate İnvaryantları:**
1. `isDefault=true` olan şablonlar swipe-to-reset ile orijinal içeriğe döner, silinmez
2. Özel şablonlar swipe ile kalıcı silinir
3. Seed işlemi bir kez: `COUNT(*) > 0` ise tekrar seed yapılmaz
4. `sortOrder` sıralama için kullanılır; 0'dan başlar

**Photo Storage İnvaryantları:**
1. Fotoğraflar `Documents/photos/{timestamp}.jpg` olarak saklanır
2. iCloud backup'tan hariç tutulur (`isExcludedFromBackup = true`)
3. Kamera çekimi `PhotoStorage.newPhotoFile()` ile kayıt path'i alır
4. Galeri seçimi content URL'sinden app-private storage'a kopyalanır
5. Profil setup temp dosyaları `tmp/profile_temp/` klasöründe

---

## 5. Proje Klasör Yapısı

```
CardConnect/
├── App/
│   ├── CardConnectApp.swift          // @main, onOpenURL, ModelContainer kurulumu, DI wiring
│   ├── AppDelegate.swift             // Scene lifecycle
│   └── DependencyContainer.swift    // Protocol + LiveDependencyContainer
│
├── Domain/
│   ├── Model/
│   │   ├── Contact.swift             // struct + FieldLimits enforce
│   │   ├── ParsedCard.swift          // Geçici tarama sonucu
│   │   ├── EmailTemplate.swift       // Value type
│   │   ├── Event.swift               // Takvim etkinliği value type
│   │   └── UserProfile.swift         // Value type; Keychain'de saklanır
│   ├── OCR/
│   │   ├── CardParser.swift          // parseCardText(_:) -> ParsedCard (pure function)
│   │   └── VisionOCRService.swift    // VNRecognizeTextRequest async wrapper
│   ├── VCard/
│   │   └── VCardParser.swift         // Tek impl + ParseSource enum
│   ├── ICS/
│   │   └── ICSGenerator.swift        // RFC 5545, UTType.calendarEvent
│   ├── Duplicate/
│   │   └── DuplicateDetector.swift   // Pure function, DB bağımlılığı yok
│   ├── Mail/
│   │   └── MailTemplateResolver.swift // [Token] → değer çözümleme
│   └── Validation/
│       ├── FieldLimits.swift
│       └── URLValidator.swift        // linkedin.com domain whitelist
│
├── Data/
│   ├── Persistence/
│   │   ├── Schema/
│   │   │   ├── SchemaV1.swift        // ContactModel + EmailTemplateModel @Model
│   │   │   └── SchemaV2.swift        // Migrasyon placeholder
│   │   ├── ContactStoreProtocol.swift
│   │   ├── ContactStore.swift        // @ModelActor; tüm DB operasyonları
│   │   └── ScanFlowActor.swift       // Swift actor; geçici tarama state'i
│   ├── Keychain/
│   │   ├── KeychainStore.swift       // Generic CRUD, Security framework
│   │   └── UserProfileStore.swift    // actor; UserProfile JSON encode/decode
│   ├── Contacts/
│   │   └── DeviceContactsService.swift // CNContactStore wrapper
│   ├── Calendar/
│   │   └── CalendarService.swift     // EKEventStore wrapper
│   ├── Photo/
│   │   └── PhotoStorage.swift        // Documents/photos/ file I/O
│   └── Permissions/
│       └── PermissionCoordinator.swift // @MainActor; kamera/kişiler/takvim izni
│
├── UI/
│   ├── Navigation/
│   │   ├── AppRoute.swift            // enum AppRoute: Hashable
│   │   └── RootNavigationView.swift  // NavigationStack<AppRoute> + TabView
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
│   │   ├── CameraView.swift          // Mode seçimi (kart/QR)
│   │   ├── CardCaptureView.swift     // AVFoundation kamera + overlay
│   │   ├── DataScannerView.swift     // DataScannerViewController UIViewControllerRepresentable
│   │   └── CameraViewModel.swift
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
│   │   ├── MailComposeViewModel.swift
│   │   └── MailComposeRepresentable.swift // MFMailComposeViewController wrapper
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
    │   ├── CardParserTests.swift          // 42+ test case
    │   ├── VCardParserTests.swift
    │   ├── ContactMergeTests.swift        // 24+ test case
    │   ├── ICSGeneratorTests.swift
    │   ├── URLValidatorTests.swift
    │   ├── DuplicateDetectorTests.swift
    │   ├── FieldLimitsTests.swift
    │   ├── ScanFlowActorTests.swift       // concurrent access testleri
    │   ├── MailTemplateResolverTests.swift
    │   └── Mocks/
    │       ├── MockContactStore.swift
    │       └── MockDependencyContainer.swift
    └── UI/
        ├── OnboardingUITests.swift
        ├── OCRHappyPathUITests.swift
        ├── DuplicateMergeUITests.swift
        ├── EventMatchUITests.swift
        ├── MailComposeUITests.swift
        └── PermissionDenialUITests.swift
```

---

## 6. Mimari Katmanlar & Bileşenler

### 6.1 ScanFlowActor (Geçici State — AppContainer'ın Yerini Alır)

```swift
// Data/Persistence/ScanFlowActor.swift
// Camera → Confirm → Duplicate → EventMatch akışının TÜM geçici state'ini tutar.
// Swift actor garantisiyle race condition imkânsız.
actor ScanFlowActor {
    private(set) var photoPaths:    [URL]       = []
    private(set) var parsedCard:    ParsedCard? = nil
    private(set) var contactID:     UUID?       = nil
    private(set) var incomingVCard: String?     = nil

    func setPhotoPaths(_ paths: [URL])    { photoPaths = paths }
    func setParsedCard(_ card: ParsedCard) { parsedCard = card }
    func setContactID(_ id: UUID)          { contactID = id }
    func setIncomingVCard(_ text: String)  { incomingVCard = text }

    // Akış tamamlanınca (başarı veya iptal) atomik sıfırlama
    func reset() {
        photoPaths    = []
        parsedCard    = nil
        contactID     = nil
        incomingVCard = nil
    }
}
```

### 6.2 ContactStore (@ModelActor)

```swift
// Data/Persistence/ContactStore.swift
@ModelActor
actor ContactStore: ContactStoreProtocol {
    func insert(_ contact: Contact) throws { ... }
    func update(_ contact: Contact) throws { ... }
    func delete(id: UUID) throws { ... }
    func fetchAll() throws -> [Contact] { /* updatedAt DESC sıralama */ }
    func fetchById(_ id: UUID) throws -> Contact? { ... }
    func search(query: String) throws -> [Contact] { /* Swift-side filter, LIKE yok */ }
    func findDuplicate(firstName: String, lastName: String, company: String,
                       phones: [String], emails: [String]) throws -> Contact? {
        // #Predicate ile == exact match; LIKE YASAK
        // phones/emails: fetchAll() -> Swift Array.contains ile kontrol
    }
}
```

**ÖNEMLİ:** Duplikat aramasında `#Predicate` içinde `LIKE` KULLANILMAZ. Telefon ve email karşılaştırmaları için tüm kişiler fetch edilir, Swift'te `Array.contains` ile kontrol edilir.

### 6.3 DependencyContainer

```swift
// App/DependencyContainer.swift
protocol DependencyContainer {
    var contactStore:          ContactStoreProtocol { get }
    var scanFlow:              ScanFlowActor { get }
    var permissionCoordinator: PermissionCoordinator { get }
    var userProfileStore:      UserProfileStore { get }
    var calendarService:       CalendarService { get }
    var deviceContactsService: DeviceContactsService { get }
    var photoStorage:          PhotoStorage { get }
}

final class LiveDependencyContainer: DependencyContainer {
    let contactStore:          ContactStoreProtocol
    let scanFlow:              ScanFlowActor
    let permissionCoordinator: PermissionCoordinator
    let userProfileStore:      UserProfileStore
    let calendarService:       CalendarService
    let deviceContactsService: DeviceContactsService
    let photoStorage:          PhotoStorage

    init(modelContainer: ModelContainer) {
        self.contactStore          = ContactStore(modelContainer: modelContainer)
        self.scanFlow              = ScanFlowActor()
        self.permissionCoordinator = PermissionCoordinator()
        self.userProfileStore      = UserProfileStore()
        self.calendarService       = CalendarService()
        self.deviceContactsService = DeviceContactsService()
        self.photoStorage          = PhotoStorage()
    }
}
```

### 6.4 AppRoute (Typed Navigation)

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

### 6.5 VCardParser (Tek İmplementasyon)

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
            guard data.count <= FieldLimits.maxVCard else { throw VCardError.tooLarge }
            raw = String(decoding: data, as: UTF8.self)
        case .string(let s):
            guard s.utf8.count <= FieldLimits.maxVCard else { throw VCardError.tooLarge }
            raw = s
        }
        return parseUnfolded(unfold(raw))
    }

    // RFC 6350 §3.2 — her iki source için de UYGULANIR
    private static func unfold(_ text: String) -> [String] {
        var lines: [String] = []
        for raw in text.components(separatedBy: "\n") {
            let trimmed = raw.hasSuffix("\r") ? String(raw.dropLast()) : raw
            if (trimmed.hasPrefix(" ") || trimmed.hasPrefix("\t")), !lines.isEmpty {
                lines[lines.endIndex - 1] += trimmed.dropFirst()
            } else { lines.append(trimmed) }
        }
        return lines
    }
    // parseUnfolded: FN, N, ORG, TITLE, TEL, EMAIL, ADR, URL parse eder
}
enum VCardError: Error { case tooLarge }
```

### 6.6 URLValidator

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

### 6.7 PermissionCoordinator

```swift
// Data/Permissions/PermissionCoordinator.swift
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

    func requestContacts() async -> PermResult { /* CNContactStore pattern */ }
    func requestCalendar() async -> PermResult { /* EKEventStore pattern */ }

    func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
```

### 6.8 ViewModel Şablonu

```swift
@MainActor
final class FooViewModel: ObservableObject {
    @Published private(set) var state: FooState = .loading
    private let dep: SomeDependencyProtocol  // init ile inject edilir, cast edilmez

    func load() async { ... }
}

enum FooState {
    case loading
    case ready(SomeData)
    case error(String)
}
```

### 6.9 SwiftData Şeması

```swift
// Data/Persistence/Schema/SchemaV1.swift
enum SchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] = [ContactModel.self, EmailTemplateModel.self]

    @Model final class ContactModel {
        @Attribute(.unique) var id: UUID
        var firstName:     String
        var lastName:      String
        var company:       String
        var title:         String
        var phonesJSON:    String   // JSON array string
        var emailsJSON:    String   // JSON array string
        var address:       String
        var notes:         String
        var linkedin:      String
        var eventID:       String?
        var eventName:     String?
        var photoURLsJSON: String   // JSON array string
        var deviceContactID: String?
        var createdAt:     Date
        var updatedAt:     Date
    }

    @Model final class EmailTemplateModel {
        @Attribute(.unique) var id: UUID
        var name:       String
        var iconName:   String
        var subject:    String
        var body:       String
        var isDefault:  Bool
        var sortOrder:  Int
    }
}
```

### 6.10 Keychain DB Şifrelemesi

```swift
// App/ModelContainerFactory.swift
func makeModelContainer() throws -> ModelContainer {
    let dbKey = try KeychainStore.loadOrCreate(key: "com.cardconnect.db.key", length: 32)
    let dbURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("cardconnect.store")
    let config = ModelConfiguration(url: dbURL, cloudKitDatabase: .none)
    // SQLite PRAGMA key ile şifreleme uygulanır
    return try ModelContainer(for: SchemaV1.ContactModel.self, SchemaV1.EmailTemplateModel.self,
                               configurations: config)
}
```

---

## 7. Bug Önleme Matrisi

Android uygulamasında bulunan her bug kategorisi için iOS mimarisi yapısal çözüm içerir.

| Android Bug | Köken | iOS Çözüm |
|-------------|-------|-----------|
| **Cat-1: Race condition** | `AppContainer.MutableList` birden fazla coroutine'den yazıldı | `ScanFlowActor` — Swift actor garantisi, dışarıdan mutasyon imkânsız |
| **Cat-2: Stale state** | `pendingParsedCard` akış bitiminde sıfırlanmadı | `ScanFlowActor.reset()` — akış tamamlanınca atomik sıfırlama |
| **Cat-3: String route crash** | Route string'lerinde typo runtime crash | `enum AppRoute: Hashable` — derleme hatası, runtime crash değil |
| **Cat-4: URI injection** | In-memory VCardParser domain kontrolü yapmadı | `URLValidator.validateLinkedIn()` parse anında çalışır; saklanan değer her zaman geçerli ya da "" |
| **Cat-5: SQL LIKE injection** | `LIKE '%' || :phone || '%'` — `%` tüm satırları eşleştirir | `#Predicate` ile `==`; phone/email için fetchAll + Swift `Array.contains` |
| **Cat-6: Field length** | Room entity sınır enforce etmedi | `Contact.init` her alanda `FieldLimits` uygular — override edilemez |
| **Cat-7: Permission loop** | `shouldShowRequestPermissionRationale` döngüsü | `PermissionCoordinator` status kontrolü yapar; `.permanentlyDenied` → Settings, yeniden istek ASLA |
| **Cat-8: Callback thread** | `OnSharedPreferenceChangeListener` herhangi thread'de tetiklendi | `@MainActor` isolasyon; Keychain erişimi actor'da |
| **Cat-9: Duplicate VCardParser** | İki ayrı impl zamanla uyumsuz hale geldi | Tek `VCardParser` + `ParseSource` enum; unfold her zaman uygulanır |
| **Cat-10: ICS MIME** | Android `message/rfc822` MIME yanlış; mail client tanımadı | `UIActivityViewController` + `ICSActivityItemSource` — `UTType.calendarEvent` |
| **#116: `[Etkinlik]` boşsa** | Bozuk metin yerine cümle kaldırıldı | `MailTemplateResolver`: token içeren cümleyi kaldırır; subject'taki çizgi temizlenir |
| **#119: Screenshot protection** | `FLAG_SECURE` iOS'ta yok | `ScreenshotProtectionModifier`: `scenePhase == .inactive` → siyah overlay |
| **#120: Root detection** | Android Build flags kolayca bypass edildi | `JailbreakDetector`: dosya varlığı + sandbox write + dyld kontrolleri |
| **#133: ICS silinmedi** | Contact silinince ICS dosyası kaldı | `ContactStore.delete` + `PhotoStorage.deleteICS(for: id)` koordineli çağrı |
| **#134: Notes overwrite** | Event match notes'u üzerine yazdı | `CalendarService.matchEvent` → `notes += "\n" + eventContext` (üzerine yazmaz) |
| **#135: Merge'de notes kayboldu** | `DuplicateDetector.merge` notes'u düşürdü | Notes birleştirme: concat + distinct satırlar |
| **#136: CNContact'a notes yazılmadı** | CNSaveRequest'te notes field eksikti | `DeviceContactsService` — `CNMutableContact.note` explicit set edilir |
| **#138: Back button broken** | `DuplicateView` NavigationController bozdu | `NavigationPath.removeLast()` — typed path, pop her zaman çalışır |
| **#139: Calendar SecurityException** | `EKAuthorizationStatus` kontrol edilmedi | `CalendarService.fetchEvents` → status `.fullAccess` değilse boş döner |
| **#141: Boş profil QR crash** | `fullName` boşken QR generate edildi | `ProfileView` QR butonu `fullName.isEmpty` iken disabled; guard eklendi |

---

## 8. Ekran Envanteri & Navigasyon

### 8.1 Ekran Listesi

| Ekran | ViewModel | Route |
|-------|-----------|-------|
| OnboardingView | — (stateless) | `.onboarding` |
| ProfileSetupView | ProfileSetupViewModel | `.profileSetup` |
| HomeView | HomeViewModel | `.home` |
| ContactsView | ContactsViewModel | `.contacts` |
| CameraView | CameraViewModel | `.camera` |
| ConfirmView | ConfirmViewModel | `.confirm` |
| DuplicateView | DuplicateViewModel | `.duplicate(contactID:)` |
| EventMatchView | EventMatchViewModel | `.eventMatch(contactID:)` |
| DetailView | DetailViewModel | `.detail(contactID:)` |
| ContactEditView | ContactEditViewModel | `.contactEdit(contactID:)` |
| TemplatesView | TemplatesViewModel | `.templates` |
| TemplateEditView | TemplateEditViewModel | `.templateEdit(templateID:)` |
| MailComposeView | MailComposeViewModel | `.mailCompose(contactID:)` |
| ProfileView | ProfileViewModel | `.profile` |
| SettingsView | — (stateless) | `.settings` |
| PrivacyPolicyView | — (stateless) | `.privacyPolicy` |

### 8.2 RootNavigationView Yapısı

```swift
struct RootNavigationView: View {
    @State private var path = NavigationPath()
    @State private var selectedTab: Tab = .home
    @EnvironmentObject private var deps: LiveDependencyContainer

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack(path: $path) {
                HomeView()
                    .navigationDestination(for: AppRoute.self) { route in
                        switch route {
                        case .contacts:           ContactsView()
                        case .camera:             CameraView(onComplete: { path.append(.confirm) })
                        case .confirm:            ConfirmView(onConfirmed: { id in path.append(.duplicate(contactID: id)) })
                        case .duplicate(let id):  DuplicateView(contactID: id, onContinue: { rid in path.append(.eventMatch(contactID: rid)) })
                        case .eventMatch(let id): EventMatchView(contactID: id, onDone: { path.removeLast(path.count) })
                        case .detail(let id):     DetailView(contactID: id)
                        case .contactEdit(let id): ContactEditView(contactID: id)
                        case .mailCompose(let id): MailComposeView(contactID: id)
                        case .templates:           TemplatesView()
                        case .templateEdit(let id): TemplateEditView(templateID: id)
                        case .templateNew:          TemplateEditView(templateID: nil)
                        case .profile:             ProfileView()
                        case .settings:            SettingsView()
                        case .privacyPolicy:       PrivacyPolicyView()
                        default:                   EmptyView()
                        }
                    }
            }
            .tabItem { Label("Ana Sayfa", systemImage: "house") }
            .tag(Tab.home)

            NavigationStack { ContactsView() }
                .tabItem { Label("Kişiler", systemImage: "person.2") }
                .tag(Tab.contacts)

            NavigationStack { MailComposeView(contactID: nil) }
                .tabItem { Label("Mail", systemImage: "envelope") }
                .tag(Tab.mail)
        }
    }
}
```

### 8.3 .vcf Dosyası Açma (Intent Eşdeğeri)

```swift
// App/CardConnectApp.swift
@main
struct CardConnectApp: App {
    @StateObject private var deps = LiveDependencyContainer(...)

    var body: some Scene {
        WindowGroup {
            RootNavigationView()
                .environmentObject(deps)
                .modifier(ScreenshotProtectionModifier())
                .onOpenURL { url in
                    guard url.pathExtension.lowercased() == "vcf" else { return }
                    Task {
                        if let parsed = try? VCardParser.parse(.file(url)) {
                            await deps.scanFlow.setParsedCard(parsed)
                            // NavigationPath'e .confirm ekle
                        }
                    }
                }
        }
    }
}
```

**Info.plist UTI kaydı:**
```xml
<key>CFBundleDocumentTypes</key>
<array>
    <dict>
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

## 9. Kullanıcı Akışları

### 9.1 Kartvizit OCR Akışı

```
[Kamera izni kontrolü]
    ↓ izin yok → PermissionRationaleSheet
    ↓ kalıcı red → Ayarlara Git butonu
    ↓ izin verildi
[CameraView — CardCaptureView]
    ↓ Shutter veya Galeri
[Ön fotoğraf çekildi] → "Arka yüz var mı?" dialog
    ├─ Evet → arka fotoğraf çekilir
    └─ Hayır → devam
[ScanFlowActor.setPhotoPaths([...]) — atomik]
    ↓
[ConfirmViewModel.runOCR()]
    → VisionOCRService.recognizeText(from: url) her fotoğraf için
    → metinler "\n---\n" ile birleştirilir
    → CardParser.parseCardText(merged) → ParsedCard
    → ScanFlowActor.setParsedCard(parsed)
    ↓
[ConfirmView — düzenlenebilir form]
    ↓ "Onayla ve Kaydet"
    → Contacts izni iste (PermissionCoordinator)
    → ContactStore.insert(contact)
    → ScanFlowActor.setContactID(contact.id)
    → opsiyonel: DeviceContactsService.add(contact)
    ↓
[DuplicateView(contactID:)]
    → ContactStore.findDuplicate(...)
    ├─ Duplikat yok → otomatik ilerle
    └─ Duplikat var → diff view → merge veya yeni kayıt
    ↓
[EventMatchView(contactID:)]
    → Takvim izni iste
    → CalendarService.fetchTodayEvents()
    ├─ Aktif etkinlik → tek kart
    ├─ Bugünkü etkinlikler → liste
    └─ Etkinlik yok → atla
    → Seçim: ContactStore.update(contact with eventID/eventName/notes)
    ↓
[HomeView — back stack tamamen temizlenir]
```

### 9.2 QR Tarama Akışı

```
[CameraView] → QR mod seçilir
[DataScannerViewController] → barkod algılandı
    ├─ "BEGIN:VCARD" ile başlıyor → VCardParser.parse(.string(...))
    │   → ScanFlowActor.setParsedCard(parsed)
    │   → ConfirmView'a git
    └─ vCard değil → uyarı mesajı göster, tara
```

### 9.3 .vcf Dosyası İmport Akışı

```
[Başka uygulamadan .vcf açılır]
    → onOpenURL tetiklenir
    → VCardParser.parse(.file(url))
    → ScanFlowActor.setParsedCard(parsed)
    → NavigationPath'e .confirm eklenir
    → ConfirmView kamera adımını atlayarak açılır
```

### 9.4 Duplikat Tespit Akışı

```
[DuplicateViewModel.checkDuplicate(contactID)]
    → ContactStore.findDuplicate(...)
    │   Kriter 1: firstName + lastName + company exact match (#Predicate ==)
    │   Kriter 2: phones — fetchAll → Swift contains
    │   Kriter 3: emails — fetchAll → Swift contains (lowercase)
    │   Yeni kişinin ID'si hariç tutulur
    ├─ Bulunamadı → otomatik EventMatch'e ilerle
    └─ Bulundu → diff view göster
        ├─ "Mevcut kaydı güncelle":
        │   → DuplicateDetector.merge(existing:incoming:)
        │   → ContactStore.update(merged)
        │   → ContactStore.delete(id: newContactID)
        │   → ScanFlowActor.setContactID(existingID)
        │   → EventMatch'e ilerle
        └─ "Yeni kayıt oluştur":
            → EventMatch'e ilerle (DB işlemi yok)
```

### 9.5 Mail Oluşturma Akışı

```
[MailComposeView(contactID:)]
    → opsiyonel: contactID nil ise ContactPicker göster
    → Şablonlar SwiftData'dan yüklenir
    → Şablon seçilir → MailTemplateResolver.resolve(template, contact, profile)
    │   [Etkinlik] boşsa: içeren cümle body'den kaldırılır
    │   Diğer eksik değişkenler: uyarı banner'ı
    ├─ "Toplantı Daveti Ekle" toggle ON:
    │   → Takvim izni iste
    │   → Tarih/saat seçici
    │   → Çakışan etkinlikleri yükle → kırmızı göster
    │   → "Gönder":
    │       ICSGenerator.generate(...) → tmp/invite_{id}.ics
    │       UIActivityViewController(items: [icsURL]) ile sun
    └─ Toggle OFF:
        → MFMailComposeViewController ile gönder
```

---

## 10. Email Şablonları

### 5 Varsayılan Türkçe Şablon

**1. Tanışma Sonrası**
- İkon: `hands.wave`
- Konu: `[Ad] ile Tanışmak Güzeldi`
- Gövde: `Merhaba [Ad],\n\nBugün [Etkinlik] etkinliğinde tanışmak çok güzeldi. Kısa da olsa sohbet etme fırsatı bulmamız benim için değerliydi.\n\nUmarım yakın zamanda tekrar görüşürüz.\n\nSaygılarımla,\n[Benim Adım]\n[Ünvanım] - [Şirketim]`

**2. İş Birliği Teklifi**
- İkon: `briefcase`
- Konu: `[Şirketim] - İş Birliği Teklifi`
- Gövde: `Sayın [Tam Ad],\n\n[Etkinlik] etkinliğinde tanıştıktan sonra, iki şirketimiz arasında olası bir iş birliği üzerine düşünüyorum.\n\nÖnerilerimizi paylaşmak üzere kısa bir görüşme ayarlayabilir miyiz?\n\nSaygılarımla,\n[Benim Adım]\n[Ünvanım] - [Şirketim]`

**3. Bilgi Talebi**
- İkon: `questionmark.circle`
- Konu: `Bilgi Talebi`
- Gövde: `Merhaba [Ad],\n\n[Etkinlik] etkinliğinde kısaca bahsettiğiniz konu hakkında daha fazla bilgi almak istiyorum.\n\nZamanınızı ayırıp yanıtlayabilir misiniz?\n\nTeşekkürler,\n[Benim Adım]\n[Ünvanım] - [Şirketim]`

**4. Takip Maili**
- İkon: `arrowshape.turn.up.left`
- Konu: `Takip: [Ad] ile Görüşme`
- Gövde: `Merhaba [Ad],\n\n[Etkinlik] etkinliğindeki görüşmemizi takiben, bahsettiğimiz konuları ilerletmek için yazıyorum.\n\nDüşüncelerinizi paylaşabilir misiniz?\n\nSaygılarımla,\n[Benim Adım]\n[Ünvanım] - [Şirketim]`

**5. Toplantı Daveti**
- İkon: `calendar`
- Konu: `Toplantı Daveti - [Şirketim]`
- Gövde: `Sayın [Tam Ad],\n\n[Etkinlik] etkinliğinde gerçekleştirdiğimiz görüşme sonrasında, konuyu daha ayrıntılı ele almak için bir toplantı düzenlemek istiyorum.\n\nToplantı davetini ekte bulabilirsiniz.\n\nSaygılarımla,\n[Benim Adım]\n[Ünvanım] - [Şirketim]`

### Şablon Değişken Çözümleme

```swift
// Domain/Mail/MailTemplateResolver.swift
struct MailTemplateResolver {
    static func resolve(template: EmailTemplate, contact: Contact, profile: UserProfile) -> (subject: String, body: String) {
        var subject = template.subject
        var body    = template.body

        let vars: [String: String] = [
            "[Ad]":         contact.firstName,
            "[Tam Ad]":     contact.fullName,
            "[Etkinlik]":   contact.eventName ?? "",
            "[Benim Adım]": profile.fullName,
            "[Ünvanım]":    profile.title,
            "[Şirketim]":   profile.company,
        ]

        for (token, value) in vars {
            if token == "[Etkinlik]" && value.isEmpty {
                // [Etkinlik] boşsa: içeren cümleyi body'den kaldır
                body    = removeEventSentence(from: body)
                subject = subject.replacingOccurrences(of: " - [Etkinlik]", with: "")
                          .replacingOccurrences(of: "[Etkinlik] - ", with: "")
                          .replacingOccurrences(of: "[Etkinlik]", with: "")
            } else {
                subject = subject.replacingOccurrences(of: token, with: value)
                body    = body.replacingOccurrences(of: token, with: value)
            }
        }
        return (subject, body)
    }

    private static func removeEventSentence(from text: String) -> String {
        // [Etkinlik] token'ını içeren cümleyi kaldır
        let pattern = #"[^.!?\n]*\[Etkinlik\][^.!?\n]*[.!?\n]?"#
        return (try? NSRegularExpression(pattern: pattern).stringByReplacingMatches(
            in: text, range: NSRange(text.startIndex..., in: text), withTemplate: ""
        )) ?? text
    }

    static func findMissingVars(template: EmailTemplate, contact: Contact, profile: UserProfile) -> [String] {
        let vals: [String: String] = [
            "[Benim Adım]": profile.fullName,
            "[Ünvanım]":    profile.title,
            "[Şirketim]":   profile.company,
        ]
        return vals.compactMap { token, value in
            (template.body.contains(token) || template.subject.contains(token)) && value.isEmpty ? token : nil
        }
    }
}
```

---

## 11. Güvenlik Katmanı

### 11.1 Screenshot Koruması

```swift
// Security/ScreenshotProtection.swift
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
// Kullanım: RootNavigationView'a .modifier(ScreenshotProtectionModifier()) uygulanır
```

### 11.2 Jailbreak Tespiti

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
        ["/Applications/Cydia.app", "/Library/MobileSubstrate/MobileSubstrate.dylib",
         "/bin/bash", "/usr/sbin/sshd", "/etc/apt", "/private/var/lib/apt/",
         "/usr/bin/ssh", "/private/var/lib/cydia"].contains {
            FileManager.default.fileExists(atPath: $0)
        }
    }

    private static func canWriteOutsideSandbox() -> Bool {
        let path = "/private/jb_test_\(UUID().uuidString)"
        do { try "t".write(toFile: path, atomically: true, encoding: .utf8)
             try FileManager.default.removeItem(atPath: path); return true
        } catch { return false }
    }

    private static func hasJailbreakDylibs() -> Bool {
        for i in 0..<_dyld_image_count() {
            if let n = _dyld_get_image_name(i), String(cString: n).contains("MobileSubstrate") { return true }
        }
        return false
    }
}
// Uyarı: non-blocking dialog — kullanıcı "Devam Et" veya "Çıkış" seçebilir
```

### 11.3 Backup Hariç Tutma

```swift
// PhotoStorage.swift veya AppDelegate.swift içinde
func excludeFromBackup(url: URL) {
    var values = URLResourceValues()
    values.isExcludedFromBackup = true
    try? (url as NSURL).setResourceValues(values)  // setResourceValues NSURLResourceKey API
}
// photos/, ics/, vcf/ dizinleri ilk açılışta hariç tutulur
```

### 11.4 Güvenlik Özeti

| Karar | Uygulama |
|-------|----------|
| DB şifreleme | SQLite PRAGMA key (32-byte Keychain key) |
| Profil depolama | Keychain JSON (UserDefaults değil) |
| Network | `NSAllowsArbitraryLoads = false`; hiç istek yok |
| Screenshot | `scenePhase == .inactive` → siyah overlay |
| Jailbreak | Dosya + sandbox + dylib kontrolleri (release only) |
| Backup | `photos/`, `ics/`, `vcf/` hariç; iCloud kapalı |
| URL güvenliği | `URLValidator` parse anında; `UIApplication.open()` öncesi kontrol |
| Dosya paylaşımı | `UIActivityViewController` — hiçbir zaman raw `file://` URI paylaşılmaz |
| Input limitleri | `Contact.init` + `VCardParser` + `CardParser` — 3 katmanda enforce |
| İzin | `PermissionCoordinator` — yeniden istek döngüsü imkânsız |

---

## 12. Test Stratejisi

### 12.1 Unit Test Hedefleri

| Dosya | Test Sayısı | Not |
|-------|-------------|-----|
| CardParserTests | 42+ | Android test case'lerini portla |
| VCardParserTests | 15+ | RFC 6350 fold, domain validation |
| ContactMergeTests | 24+ | Android merge test case'lerini portla |
| ICSGeneratorTests | 10+ | RFC 5545 escaping, 75-octet fold, UTC format |
| URLValidatorTests | 8+ | evil.com, intent://, http vs https |
| DuplicateDetectorTests | 12+ | name match, phone match, email match, self-exclude |
| FieldLimitsTests | 6+ | Contact.init truncates correctly |
| ScanFlowActorTests | 5+ | Concurrent Task erişimi — data race yok |
| MailTemplateResolverTests | 8+ | Boş [Etkinlik], eksik profil değerleri |

### 12.2 Örnek Test Yapıları

```swift
// Tests/Unit/CardParserTests.swift
final class CardParserTests: XCTestCase {
    func test_standardNameExtracted() {
        let r = CardParser.parseCardText("Ali Veli\nCEO\nTech A.Ş.\nali@tech.com")
        XCTAssertEqual(r.firstName, "Ali"); XCTAssertEqual(r.lastName, "Veli")
    }
    func test_inputClampedAt8192() {
        let long = "Ali Veli\n" + String(repeating: "x", count: 9000)
        XCTAssertEqual(CardParser.parseCardText(long).firstName, "Ali")
    }
    func test_phoneCappedAtThree() {
        let t = "Ali\n+90 555 001\n+90 555 002\n+90 555 003\n+90 555 004"
        XCTAssertLessThanOrEqual(CardParser.parseCardText(t).phones.count, 3)
    }
    func test_faxExcluded() {
        let t = "Ali\nTel: +90 555 111\n📠 +90 555 222"
        XCTAssertFalse(CardParser.parseCardText(t).phones.contains { $0.contains("222") })
    }
    func test_emailLowercased() {
        XCTAssertEqual(CardParser.parseCardText("Ali\nALI@TECH.COM").emails.first, "ali@tech.com")
    }
    func test_reversedName() {
        let r = CardParser.parseCardText("YILMAZ Ahmet\nEngineer")
        XCTAssertEqual(r.lastName, "Yilmaz"); XCTAssertEqual(r.firstName, "Ahmet")
    }
}
```

```swift
// Tests/Unit/ContactMergeTests.swift
final class ContactMergeTests: XCTestCase {
    func test_incomingFirstNameWins() {
        XCTAssertEqual(DuplicateDetector.merge(
            existing: Contact(firstName: "Eski"), incoming: Contact(firstName: "Yeni")
        ).firstName, "Yeni")
    }
    func test_existingPreservedWhenIncomingEmpty() {
        XCTAssertEqual(DuplicateDetector.merge(
            existing: Contact(firstName: "Korunan"), incoming: Contact(firstName: "")
        ).firstName, "Korunan")
    }
    func test_emailsUnionDeduped() {
        let merged = DuplicateDetector.merge(
            existing: Contact(emails: ["a@x.com", "b@x.com"]),
            incoming: Contact(emails: ["b@x.com", "c@x.com"])
        ).emails
        XCTAssertEqual(merged.count, 3)
    }
    func test_identicalNotesNotDuplicated() {
        let r = DuplicateDetector.merge(
            existing: Contact(notes: "Aynı"), incoming: Contact(notes: "Aynı")
        )
        XCTAssertEqual(r.notes, "Aynı")
    }
    func test_existingIDRetained() {
        let existing = Contact(); let incoming = Contact()
        XCTAssertEqual(DuplicateDetector.merge(existing: existing, incoming: incoming).id, existing.id)
    }
}
```

### 12.3 UI Test Hedefleri

| Dosya | Senaryo |
|-------|---------|
| OnboardingUITests | KVKK checkbox zorunluluğu; "Atla" akışı |
| OCRHappyPathUITests | Kamera → Confirm form → kaydet happy path |
| DuplicateMergeUITests | Duplikat dialog → merge → EventMatch'e geçiş |
| EventMatchUITests | Etkinlik seçimi → notes güncellenmesi → HomeView |
| MailComposeUITests | Şablon seçimi → boş [Etkinlik] uyarısı → gönder |
| PermissionDenialUITests | Kamera kalıcı red → Ayarlara Git görünür |

### 12.4 Test Coverage Kuralları

- `CardParser`, `VCardParser`, `DuplicateDetector`, `ICSGenerator`, `URLValidator` — %100 satır coverage (pure function, mock gerekmez)
- ViewModels — protocol mock implementasyonlarıyla init injection ile test edilir
- `ContactStore` — in-memory `ModelConfiguration` ile test edilir
- `ScanFlowActor` — `Task {}` concurrent erişimle data race olmaması doğrulanır

---

## 13. Kod Kuralları & Anti-Pattern'ler

### ✅ YAPILMASI GEREKEN

```swift
// actor ile state koruma
actor ScanFlowActor { ... }

// Typed navigation
enum AppRoute: Hashable { ... }
path.append(AppRoute.duplicate(contactID: id))

// Exact match predicate
#Predicate<ContactModel> { $0.id == targetID }

// Tek VCardParser
VCardParser.parse(.file(url))
VCardParser.parse(.string(qrText))

// URLValidator her zaman parse anında
URLValidator.validateLinkedIn(rawURL)

// FieldLimits Contact.init'te
String(firstName.prefix(FieldLimits.maxNameField))

// PermResult kontrolü
switch await permissionCoordinator.requestCamera() {
case .granted: ...
case .denied: // snackbar, bir daha isteme
case .permanentlyDenied: permissionCoordinator.openSettings()
}

// Profil Keychain'de
actor UserProfileStore { func save(_ p: UserProfile) async throws { ... } }

// iCloud backup hariç
var v = URLResourceValues(); v.isExcludedFromBackup = true
```

### ❌ YAPILMAMASI GEREKEN

```swift
// String route — YASAK
navigationController.push("duplicate/\(id)")  // ❌
path.append("confirm")                         // ❌

// LIKE wildcard — YASAK
#Predicate { $0.phonesJSON.contains(phone) }   // ❌ LIKE gibi davranır
// Bunun yerine: fetchAll() → Swift Array.contains

// İki VCardParser — YASAK
// domain/vcf/VCardParser.swift + domain/vcard/VCardParser.swift → YASAK

// Domain kontrolsüz URL aç — YASAK
UIApplication.shared.open(URL(string: contact.linkedin)!)  // ❌ validate et önce

// Kalıcı red sonrası tekrar istek — YASAK
if status == .denied { requestAccess() }  // ❌ döngü oluşturur

// Profil UserDefaults'ta — YASAK
UserDefaults.standard.set(userEmail, forKey: "profile_email")  // ❌ Keychain kullan

// Combine — YASAK
import Combine  // ❌ Swift Concurrency kullan

// @Published async mutation main actor dışında — dikkat
// Tüm ViewModel'lar @MainActor olmalı
```

### Concurrency Kuralları

1. **Tüm ViewModel'lar `@MainActor`** — thread safety garantisi
2. **DB işlemleri `@ModelActor`** — ContactStore
3. **Geçici state `actor ScanFlowActor`** — serialize, no races
4. **Keychain işlemleri `actor UserProfileStore`** — serialize
5. **`await` ile cross-actor erişim** — Swift compiler enforce eder
6. **`Task { }` ile `async` başlatma** — `DispatchQueue.global()` YASAK

---

## 14. Release & App Store Gereksinimleri

### 14.1 Bundle & Versioning

- Bundle ID: `com.veilion.cardconnect` (iOS için aynı brand)
- Deployment Target: iOS 17.0
- Swift Version: 5.10 (Swift 6 strict concurrency)
- Xcode: 16.0+

### 14.2 Info.plist Zorunlu Anahtarlar

```xml
<!-- İzin açıklamaları (Türkçe) -->
<key>NSCameraUsageDescription</key>
<string>Kartvizitlerinizi taramak için kameraya erişim gerekiyor.</string>

<key>NSContactsUsageDescription</key>
<string>Kişileri telefon rehberinize eklemek için erişim gerekiyor.</string>

<key>NSCalendarsUsageDescription</key>
<string>Etkinliklerle kişilerinizi eşleştirmek için takvime erişim gerekiyor.</string>

<key>NSPhotoLibraryUsageDescription</key>
<string>Galeriden kartvizit fotoğrafı seçmek için erişim gerekiyor.</string>

<!-- Network -->
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key><false/>
</dict>

<!-- vCard UTI kaydı -->
<key>CFBundleDocumentTypes</key>
<array>
    <dict>
        <key>LSItemContentTypes</key>
        <array>
            <string>public.vcard</string>
            <string>public.x-vcard</string>
        </array>
        <key>LSHandlerRank</key><string>Alternate</string>
    </dict>
</array>
```

### 14.3 App Icons

Gerekli icon boyutları (Xcode Asset Catalog `AppIcon`):
- 1024x1024 (App Store)
- 180x180 (iPhone @3x)
- 120x120 (iPhone @2x)
- 87x87, 80x80, 60x60, 58x58, 40x40, 29x29

### 14.4 CI/CD

- SwiftLint — PR'da zorunlu (unused `NSCameraUsageDescription` vb. lint kuralı)
- Unit test suite — PR'da zorunlu (%80+ coverage hedefi)
- TestFlight — internal test için
- App Store Connect — metadata, screenshots, review notları

### 14.5 App Store Metadata (Türkçe)

- **Ad:** Card Connect
- **Alt Başlık:** Kartvizit Tarayıcı & Yönetici
- **Açıklama:** Kartvizitleri saniyeler içinde dijitalleştirin. OCR ile otomatik alan çıkarımı, Türkçe mail şablonları, takvim etkinliği eşleştirme.
- **Anahtar Kelimeler:** kartvizit, tarayıcı, iş kartı, kişi, OCR, vCard
- **Kategori:** Business / Productivity
- **Ülke:** Türkiye (öncelikli); global

### 14.6 App Store Screenshots

Gerekli cihaz boyutları:
- 6.7" (iPhone 15 Pro Max)
- 6.5" (iPhone 14 Plus)
- 5.5" (iPhone 8 Plus)
- iPad Pro 12.9" (opsiyonel)

Temel ekranlar: Kamera/OCR, Kişi listesi, Kişi detayı, Mail şablonu, Profil QR

---

*Bu dosya Card Connect iOS projesinin tek kaynak gerçeğidir.*  
*Android projesine bir daha başvurmanıza gerek yoktur.*  
*Versiyon: 1.0 — 2026-06-24*
