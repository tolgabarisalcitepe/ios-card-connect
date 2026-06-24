# ANDROID_LESSONS_LEARNED.md
> Android geliştirme sürecinde (issue #1–#169) ortaya çıkan hatalardan çıkarılmış mühendislik kuralları.
> iOS implementasyonu sırasında bu kurallar ihlal edilmemelidir.

---

## 1. State Management

### Kural
Workflow tamamlandıktan sonra geçici state atomik olarak temizlenmelidir.

### Android'de Yaşanan Problem
AppContainer üzerindeki pendingPhotoPaths ve pendingParsedCard alanları
scan → confirm → duplicate → eventMatch akışı bittikten sonra sıfırlanmıyordu.
Yeni taramada eski kart state'i leak ediyordu.
Kullanıcı geri dönüp yeni kart tararsa önceki duplikat verisi çıkıyordu.

### iOS Uygulaması
Save sonrası:
```
ScanFlowActor.reset()
```
Confirm iptal edilirse (geri tuşu, dismiss):
```
ScanFlowActor.reset()
```
Actor metodları Swift tarafından seri çalıştırılır — race condition imkânsız.

---

## 2. Duplicate Detection

### Kural
Duplicate kontrolünde wildcard veya fuzzy eşleşme kullanılmaz.
Exact match her zaman daha güvenlidir.

### Android'de Yaşanan Problem
Room DAO'sunda LIKE sorguları kullanılıyordu:
```sql
WHERE phones LIKE '%"' || :phone || '"%'
```
Phone değeri "%" içeriyorsa sorgu tüm kayıtları döndürüyordu.
JSON array string olarak saklanan alanda LIKE metacharacter escape edilmemişti.

### iOS Uygulaması
Ad + Soyad + Şirket:
```
#Predicate ile == exact match
```
Telefon:
```
fetchAll() → Swift Array.contains(phone)
```
Email:
```
fetchAll() → Swift Array.contains(email.lowercased())
```
LIKE, CONTAINS, wildcard tabanlı sorgu kesinlikle kullanılmaz.

---

## 3. Merge Rules

### Kural
Birleştirme işlemi hiçbir alanda veri kaybetmemelidir.
Her alan için "kazanan" kuralı açıkça tanımlanmalıdır.

### Android'de Yaşanan Problem
DuplicateViewModel.mergeIntoExisting() yeni kişinin notes alanını düşürüyordu.
EventMatchViewModel.selectEvent() mevcut notes üzerine yazıyordu.
Sonuç: Kullanıcının girdiği notlar sessizce siliniyor.

### iOS Uygulaması
notes:
```
concat + distinct
[existing.notes, incoming.notes]
  .filter { !$0.isEmpty }
  .uniqued()
  .joined(separator: "\n")
```
phones:
```
gelen liste doluysa kazanır, boşsa mevcut korunur
```
emails:
```
union + deduplicate
```
photoURLs:
```
union + deduplicate
```
id, createdAt:
```
her zaman existing kişinin değerleri
```

---

## 4. Navigation

### Kural
Her ekranda geri dönüş yolu derleme zamanında doğrulanmalıdır.
String-based navigation kullanılmaz.

### Android'de Yaşanan Problem
String route sabitleri NavGraph ile manuel senkronize tutuluyordu.
ContactsScreen ile ListScreen aynı işi yapan iki ayrı ekran oluştu (dead code).
DuplicateScreen'den geri tuşu beklenmedik ekrana gidiyordu.
EventMatchScreen'den back stack tamamen temizlenmesi gerekiyordu ama temizlenmiyordu.

### iOS Uygulaması
Tüm navigasyon:
```swift
enum AppRoute: Hashable { ... }
path.append(AppRoute.duplicate(contactID: id))
path.removeLast()                  // Bir ekran geri
path.removeLast(path.count)        // Tamamen temizle (EventMatch → Home)
```
AppRoute'ta olmayan case derlenmez.
Dead code ekran imkânsız — her View bir AppRoute case'ine bağlıdır.

---

## 5. Permission Handling

### Kural
İzin reddi crash'e veya sonsuz döngüye neden olmamalıdır.
Her izin için graceful fallback tanımlanmalıdır.

### Android'de Yaşanan Problem
shouldShowRequestPermissionRationale() döngü oluşturuyordu.
READ_CALENDAR reddedilince EventMatchScreen loading state'te kilitleniyordu.
WRITE_CONTACTS kalıcı reddinde Settings yönlendirmesi yoktu.
Rationale dialog camera için vardı ama contacts ve calendar için yoktu.

### iOS Uygulaması
Kamera:
```
.denied → "Ayarlara Git" butonu göster
requestAccess() bir daha çağrılmaz
```
Kişiler (WRITE_CONTACTS):
```
.denied → graceful skip
contact SwiftData'ya kaydedilir
CNContact'a eklenmez
```
Takvim (READ_CALENDAR):
```
.denied → EventMatch adımı atlanır
Kullanıcıya snackbar gösterilir
onDone() çağrılır (kilitlenme yok)
```
Her izin tipi için PermissionRationaleSheet — tutarlı UX.

---

## 6. Input Validation

### Kural
Field limitleri model seviyesinde uygulanmalıdır.
UI seviyesinde maxLength yeterli değildir — programatic yazma da truncate edilmelidir.

### Android'de Yaşanan Problem
Room entity'de maxLength kısıtlaması yoktu.
Çok uzun vCard (>16KB) parse ediliyordu, bellek tüketimi artıyordu.
ICSGenerator çok büyük notes alanıyla MB boyutunda .ics dosyası üretiyordu.
Kullanıcı çok uzun metin yapıştırınca sorun çıkıyordu.

### iOS Uygulaması
Contact.init her alanda FieldLimits uygular:
```swift
firstName: .prefix(100)
company:   .prefix(300)
phone:     .prefix(30)
email:     .prefix(254)
notes:     .prefix(2000)
```
VCardParser: dosya 16.384 byte'ı aşarsa VCardError.tooLarge throw edilir.
CardParser: girdi metni 8.192 karakterde kesilir.
Bu limitler Contact oluşturmanın her yolunda çalışır (OCR, vCard, manuel).

---

## 7. URL Security

### Kural
Kullanıcıdan veya dış kaynaktan gelen URL doğrudan açılmaz.
Domain whitelist, parse anında uygulanır — display anında değil.

### Android'de Yaşanan Problem
In-memory VCardParser URL alanını domain kontrolü olmadan saklıyordu.
File-based VCardParser `contains("linkedin.com")` kontrolü yapıyordu.
İki implementasyon tutarsız güvenlik davranışı sergiliyordu.
`https://evil.com/something?linkedin` gibi URL'ler http/https kontrolünü geçiyordu.

### iOS Uygulaması
URLValidator.validateLinkedIn() kullanılır:
```swift
host.lowercased() ∈ {"linkedin.com", "www.linkedin.com"}
scheme == "https"
```
Contact.init: `linkedin = URLValidator.validateLinkedIn(raw) ? raw : ""`
UIApplication.shared.open() öncesi tekrar kontrol.
Saklanan değer her zaman geçerli URL veya "".

---

## 8. Contacts Synchronization

### Kural
SwiftData ve Device Contacts senkronizasyonu veri kaybetmemelidir.
Her iki kaynağa yazılan tüm alanlar açıkça belirtilmelidir.

### Android'de Yaşanan Problem
ContactsRepository.updateContact() notes parametresini dahil etmiyordu.
Telefon rehberindeki not hiç güncellenmiyor, hep boş kalıyordu.
addContact() idempotent değildi: deviceContactId doluyken tekrar çağrılabiliyordu.
Kişi silinince telefon rehberindeki karşılığı kalmaya devam ediyordu.

### iOS Uygulaması
DeviceContactsService.addContact():
```
guard contact.deviceContactID == nil else { return }
CNMutableContact.note = contact.notes  // explicit
```
DeviceContactsService.updateContact():
```
Tüm alanlar: givenName, familyName, organizationName,
jobTitle, phoneNumbers, emailAddresses, postalAddresses,
note, urlAddresses — hepsi dahil
```
DeviceContactsService.deleteContact():
```
CNSaveRequest.delete(cnContact)
```

---

## 9. File & Resource Cleanup

### Kural
Uygulama oluşturduğu her geçici dosyadan sorumludur.
Workflow iptal edilince veya kişi silinince ilgili dosyalar temizlenir.

### Android'de Yaşanan Problem
Confirm ekranı iptal edilince geçici OCR fotoğrafları photos/ klasöründe kalıyordu.
Kişi silinince ICS davet dosyası (ics/invite_{id}.ics) diskte kalıyordu.
Zamanla uygulama depolama alanı gereksiz dosyalarla doluyordu.

### iOS Uygulaması
ConfirmViewModel:
```swift
deinit {
    if !saved {
        Task { await photoStorage.deleteAll(paths: photoPaths) }
    }
}
```
ContactStore.delete(id:):
```
1. SwiftData kaydını sil
2. photoURLs'deki tüm fotoğrafları sil
3. ics/invite_{id}.ics varsa sil
4. deviceContactID varsa CNContact'ı sil
```

---

## 10. Privacy & Store Compliance

### Kural
Store gereksinimleri release sonunda değil geliştirme başında uygulanmalıdır.
Backup kuralları ve gizlilik beyanı tutarlı olmalıdır.

### Android'de Yaşanan Problem
backup_rules.xml boştu — tüm dosyalar yedekleniyordu.
Gizlilik politikasında "veri aktarımı yok" beyanı Google Drive yedeğiyle çelişiyordu.
KVKK aydınlatma metni "Atla" butonu nedeniyle bypass edilebiliyordu.
Play Store için harici privacy policy URL'si yoktu.

### iOS Uygulaması
Privacy Manifest (PrivacyInfo.xcprivacy):
```
NSPrivacyTracking: false
NSPrivacyCollectedDataTypes: []
```
Backup Dışlama (ilk açılışta):
```swift
photos/, ics/, vcf/ → isExcludedFromBackup = true
```
iCloud:
```
ModelConfiguration cloudKitDatabase: .none
```
KVKK Onayı:
```
Sayfa 3 checkbox zorunlu
"Profili Kur" butonu sadece onay verilince aktif
privacy_accepted + timestamp @AppStorage'a kaydedilir
```
Gizlilik Politikası:
```
Harici URL (GitHub Pages veya web sitesi)
Info.plist: NSPrivacyPolicyURL
```

---

## 11. Schema Migration

### Kural
Database migration destructive olamaz.
Her şema değişikliği için migration stage yazılmalıdır.

### Android'de Yaşanan Problem
Room'da fallbackToDestructiveMigration=true ayarlıydı.
Uygulama güncellenince tüm kullanıcı verisi siliniyordu.
v1→v2 (email_templates) ve v2→v3 (linkedin kolonu) migration'ları sonradan eklendi.

### iOS Uygulaması
```swift
enum SchemaV1: VersionedSchema { ... }
enum SchemaV2: VersionedSchema { ... }

let migrationPlan = SchemaMigrationPlan(
    schemas: [SchemaV1.self, SchemaV2.self],
    stages: [.custom(fromVersion: SchemaV1.self, toVersion: SchemaV2.self) { context in
        // veri dönüşümü
    }]
)
```
Destructive migration: asla.
Her schema bump → yeni SchemaVN + custom migration stage.

---

## 12. Test Strategy

### Kural
Android'de bug çıkmış her alan iOS'ta testsiz bırakılmaz.
Pure function'lar için %100 satır coverage hedeflenir.

### Android'de Yaşanan Problem
CardParser 12 test kartından 10'unda hata verdi.
Test kapsamı yoktu, regression'lar production'da fark edildi.
ViewModel merge logic ve Room migration testi yazılmamıştı.

### iOS Öncelikli Test Alanları

CardParser:
```
42+ test case — Android KV1-KV12 test kartları portlanır
```
VCardParser:
```
RFC 6350 fold, domain validation, tooLarge throw
```
DuplicateDetector:
```
name match, phone match, email match, self-exclusion, merge rules
```
ContactMerge:
```
24+ case — notes concat, email union, photo union, ID retention
```
ICSGenerator:
```
RFC 5545 escaping, 75-octet line fold, UTC format, email validation
```
URLValidator:
```
evil.com, intent://, http vs https, subdomain, path variants
```
ScanFlowActor:
```
concurrent Task erişimi — Swift data race detection (–sanitize=thread)
```

---

## 13. ICS & Calendar Integration

### Kural
Takvim ve ICS işlemleri izin kontrolü olmadan yapılmaz.
ICS MIME tipi doğru belirtilmelidir.

### Android'de Yaşanan Problem
READ_CALENDAR izni kontrol edilmeden CalendarContract sorgusu yapılıyordu.
SecurityException runtime'da fırlatılıyordu.
ICS dosyası ACTION_SEND_MULTIPLE ile gönderilirken MIME tipi yanlıştı.
Mail client dosyayı takvim daveti olarak tanımıyordu.

### iOS Uygulaması
```swift
guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else {
    return []
}
```
ICS gönderimi:
```swift
UIActivityViewController(activityItems: [ICSActivityItemSource(fileURL: icsURL)])
// UTType.calendarEvent → doğru MIME
```

---

## 14. OCR Pipeline

### Kural
OCR sonucu ham metin olarak işlenmez.
Her parsing adımında validasyon ve normalizasyon uygulanır.

### Android'de Yaşanan Problem
CardParser birçok edge case'de yanlış sonuç verdi:
- All-caps metinde büyük/küçük harf normalizasyonu yoktu
- Faks numaraları telefon listesine giriyordu
- Dahili numaralar (ext., dahili) ana telefon olarak işaretleniyordu
- 3+ telefon varlığında yanlış ayrıştırma
- Adres satırları yanlış birleştiriliyordu

### iOS Uygulaması
CardParser kuralları:
```
Giriş: .prefix(FieldLimits.maxOCRInput) — 8.192 char
All-caps kelime: .lowercased().capitalized
Faks regex: (?i)(faks?|fax|📠|f\.?) — bu etikette telefon değil
Dahili regex: (?i)(ext\.?|dahili|pbx)\s*\d+ — hariç tut
Maksimum telefon: .prefix(3)
Email: .lowercased()
```
Çift yüz OCR: front + "\n---\n" + back → tek metin olarak parse.

---

## 15. Mail Compose

### Kural
Mail intent'i sistem mail uygulamasına doğru parametrelerle gönderilmelidir.
Template değişken çözümlemesi gönderim öncesi tamamlanmış olmalıdır.

### Android'de Yaşanan Problem
ACTION_SENDTO ile subject/body Gmail ve diğer mail uygulamalarına aktarılmıyordu.
`[Etkinlik]` boşken şablon seçilince bozuk metin oluşuyordu.
Tanımsız şablon değişkenleri için kullanıcıya uyarı verilmiyordu.
Mail gönderildikten sonra başarı mesajı gösterilmiyordu.

### iOS Uygulaması
MFMailComposeViewController:
```swift
vc.setSubject(resolvedSubject)
vc.setMessageBody(resolvedBody, isHTML: false)
```
[Etkinlik] boşsa:
```
İçeren cümle body'den kaldırılır
Subject'teki " - " kalıntısı temizlenir
```
Eksik değişkenler:
```
[Benim Adım], [Ünvanım], [Şirketim] boşsa → uyarı banner
[Etkinlik] boşsa → sessizce kaldırılır (uyarı yok)
```
Mail gönderimi sonrası:
```
MailComposeResult.sent → Snackbar "Mail gönderildi" → onBack()
MailComposeResult.failed → Snackbar "Gönderilemedi"
```

---

## 16. VCard Pipeline

### Kural
vCard işleme tek bir parser üzerinden yapılmalıdır.
Her kaynak (dosya, QR, URL) aynı parsing mantığını kullanmalıdır.

### Android'de Yaşanan Problem
İki ayrı VCardParser implementasyonu zamanla birbirinden ayrıştı.
domain/vcf/VCardParser: dosya tabanlı, RFC 6350 unfold uyguluyor.
domain/vcard/VCardParser: in-memory, unfold yok.
QR'dan gelen katlanmış vCard in-memory parser'da yanlış parse ediliyordu.
URL alanı in-memory parser'da ignore ediliyordu, LinkedIn kaydedilmiyordu.

### iOS Uygulaması
```swift
enum ParseSource { case file(URL); case string(String) }

struct VCardParser {
    static func parse(_ source: ParseSource) throws -> ParsedCard {
        // Her iki kaynak için RFC 6350 unfold uygulanır
    }
}
```
ParsedCard.linkedin: her zaman URLValidator.normalizeLinkedIn() ile normalize edilir.

---

## 17. Security Defaults

### Kural
Güvenlik özellikleri varsayılan olarak açık olmalıdır.
Sonradan ekleme değil, başlangıçtan itibaren uygulanmalıdır.

### Android'de Yaşanan Problem
FLAG_SECURE MainActivity'ye geç eklendi.
Root/emülatör tespiti sonradan eklendi.
file_provider_paths.xml gereksiz geniş cache dizinini açıyordu.
READ_CONTACTS izni beyan edildi ama hiç kullanılmadı (Play Store reddi riski).

### iOS Uygulaması
Başlangıçtan itibaren:
```
ScreenshotProtectionModifier → RootNavigationView'da
JailbreakDetector → CardConnectApp.init'te (release build)
NSAppTransportSecurity → NSAllowsArbitraryLoads: false
Info.plist → sadece kullanılan izinler beyan edilir
```
Kullanılmayan izin beyanı → SwiftLint kuralı ile CI'da yakalanır.

---

## 18. Onboarding & First Launch

### Kural
İlk açılış deneyimi doğru sırada permission'ları istemeli.
Consent ve onboarding bayrakları kalıcı olarak kaydedilmelidir.

### Android'de Yaşanan Problem
WRITE_CONTACTS ve READ_CALENDAR izinleri LaunchedEffect ile early request yapıyordu.
Just-in-time değil, ekran açılır açılmaz isteniyordu (kötü UX).
Onboarding "Atla" butonu KVKK onayını bypass ediyordu.

### iOS Uygulaması
Just-in-time permission:
```
Kamera: CameraView açılınca
Kişiler: "Onayla ve Kaydet" tıklanınca
Takvim: EventMatchView açılınca
```
Onboarding:
```
onboarding_done: @AppStorage
privacy_accepted: @AppStorage
privacy_accepted_at: @AppStorage (timestamp)
```
Sayfa 1-2 "Atla" → doğrudan HomeView (consent sayfa 3'te)
Sayfa 3 → consent zorunlu → "Profili Kur" aktif

---

*Son güncelleme: 2026-06-24*
*Kaynak: tolgabarisalcitepe/and-card-connect issue #1–#169 (tüm CLOSED issue'lar)*
