# BUG_PREVENTION_MATRIX.md
> Android projesinde açılan issue'lardan türetilen iOS kontrol matrisi.
> Her issue için: Android problemi → iOS kuralı → doğrulama kriterleri.

---

## Cat-1 — Race Condition (Shared Mutable State)

**Android Issue:** AppContainer — pendingPhotoPaths/pendingParsedCard process death'te sıfırlanıyor, Camera→Confirm arası veri kaybı [KRİTİK]

Android Problemi:
AppContainer.pendingPhotoPaths bir MutableList idi.
CameraViewModel ve ConfirmViewModel aynı listeye eş zamanlı yazıyordu.
clear() ve addAll() arasında ConfirmViewModel okursa boş liste görüyordu.

iOS Kuralı:
ScanFlowActor tek erişim noktasıdır.
Dışarıdan doğrudan mutasyon yoktur.
Tüm yazma işlemleri actor metotları üzerinden yapılır.

Yasak:
- `var photoPaths: [URL]` bir class'ta public mutable field olarak tanımlamak
- İki farklı Task'tan aynı anda `scanFlow.photoPaths.append(...)` çağırmak

Kontrol:
- `setPhotoPaths` çağrısı actor boundary geçer, Swift compiler izole eder
- Concurrent Task'lardan erişim testi → data race alamazsın (ScanFlowActorTests)

---

## Cat-2 — Stale State

**Android Issue:** DuplicateViewModel — güncelleme sırasında yeni telefon replace değil listeye ekleniyor

Android Problemi:
pendingParsedCard akış bittikten sonra sıfırlanmıyordu.
Yeni tarama eski kart state'iyle karışıyordu.
Kullanıcı geri dönüp yeni kart tarayınca eski duplikat verisi karşısına çıkıyordu.

iOS Kuralı:
Her başarılı save sonrası ScanFlowActor.reset() çağrılmalı.
Akış iptal edilince de (ConfirmViewModel.onDisappear) reset() çağrılmalı.

Kontrol:
- Save sonrası `await scanFlow.parsedCard == nil`
- Yeni scan öncesi `await scanFlow.photoPaths.isEmpty`
- Reset sonrası tüm alanlar sıfır değerinde (ScanFlowActorTests)

---

## Cat-3 — String Route Crash

**Android Issue:** fix: ui/list/ListScreen.kt — NavGraph'ta hiçbir route'a bağlı değil, ContactsScreen ile çakışan dead code

Android Problemi:
String route sabitleri NavGraph ile manuel senkronize tutuluyordu.
Typo veya refactor sonrası route string'i değişince runtime crash.
Dead code ekranlar NavGraph'a bağlanmadan bırakıldı.

iOS Kuralı:
AppRoute enum'u dışında hiçbir navigasyon yapılmaz.
Yeni ekran eklenince önce AppRoute'a case eklenir, sonra navigationDestination'a.

Yasak:
- `path.append("confirm")` — string navigation
- `navigationController.push("duplicate/\(id)")` — string interpolation

Kontrol:
- AppRoute'ta olmayan bir case derlenmez
- Tüm ekranlar RootNavigationView'daki switch içinde karşılık bulur

---

## Cat-4 — URI Injection / Open Redirect

**Android Issue:** fix: LinkedIn URL scheme injection — DetailScreen ve ContactsScreen
**Android Issue:** fix: VCardParser — QR'dan gelen vCard içeriği doğrulanmıyor, oltalama kişi enjeksiyonu mümkün [YÜKSEK ABUSE RİSKİ]

Android Problemi:
In-memory VCardParser URL alanını domain kontrolü yapmadan saklıyordu.
Sadece file-based parser `contains("linkedin.com")` kontrolü yapıyordu.
`https://evil.com/linkedin` gibi URL'ler http/https scheme kontrolünü geçiyordu.

iOS Kuralı:
URLValidator.validateLinkedIn() parse anında çağrılır.
Contact.init'te linkedin alanı ya geçerli ya "".
UIApplication.open() öncesi tekrar kontrol.

Yasak:
- Parse sonrası ham URL doğrudan saklamak
- Display'de URL'yi ilk kez doğrulamak (çok geç)
- `url.scheme == "https"` yeterliymiş gibi davranmak (host da kontrol edilmeli)

Kontrol:
- `https://evil.com/linkedin` → `contact.linkedin == ""`
- `intent://...` → `contact.linkedin == ""`
- `https://linkedin.com/in/handle` → saklanır
- `http://linkedin.com/in/handle` → saklanmaz (https zorunlu)

---

## Cat-5 — LIKE Wildcard Injection

**Android Issue:** fix: ContactDao — findByPhone/findByEmail LIKE substring eşleşme yanlış duplicate tespiti yapıyor

Android Problemi:
Telefon veya email içinde % karakteri yanlış eşleşmelere sebep oluyordu.
`WHERE phones LIKE '%"%"'` sorgusu `%` içeren phone ile tüm satırları döndürüyordu.
JSON array string olarak saklanan değerlerde LIKE metacharacter'lar escape edilmemişti.

iOS Kuralı:
Duplicate kontrolünde exact match kullanılmalı.
#Predicate içinde LIKE, CONTAINS, wildcard tabanlı sorgu yapılmaz.
Telefon ve email karşılaştırması için fetchAll() → Swift Array.contains.

Yasak:
- `#Predicate { $0.phonesJSON.contains(phone) }` — LIKE gibi davranır
- `LIKE '%' + phone + '%'` — wildcard injection
- SwiftData `#Predicate` içinde string substring operasyonu

Kontrol:
- `phone = "%"` → hiçbir kişiyle eşleşmemeli
- `phone = "555"` → sadece tam 555 numarası olan kişiyle eşleşmeli (substring değil)
- `email = "%@%.%"` → hiçbir kişiyle eşleşmemeli

---

## Cat-6 — Field Length Limits

**Android Issue:** fix: VCardParser ve CardParser — maksimum field uzunluğu kontrolü yok, aşırı büyük QR/vCard girdisi bellek tüketimine yol açıyor [ORTA]

Android Problemi:
Room entity'de maxLength yoktu.
Kullanıcı çok uzun not yapıştırabiliyordu.
Aşırı büyük vCard dosyası parse ediliyordu.
ICSGenerator çok büyük notes alanıyla MB boyutunda .ics üretiyordu.

iOS Kuralı:
Contact.init her alanda FieldLimits uygular — override edilemez.
VCardParser.parse() dosya boyutunu FieldLimits.maxVCard ile kontrol eder.
CardParser.parseCardText() girdi metnini FieldLimits.maxOCRInput ile keser.

Sınırlar:
- firstName/lastName: 100 char
- company/title/address: 300 char
- phone (her biri): 30 char
- email (her biri): 254 char
- notes: 2000 char
- vCard dosya: 16.384 byte
- OCR girdi: 8.192 char

Kontrol:
- 101 char firstName → Contact.firstName.count == 100
- 16.385 byte vCard → VCardError.tooLarge throw edilmeli
- 8.193 char OCR metni → parse sonucu 8.192 char'dan türetilmeli

---

## Cat-7 — Permission Loop

**Android Issue:** fix: CameraScreen — kamera izni kalıcı reddedilince PermissionRationale döngüye giriyor, Ayarlara Git akışı yok [ORTA]
**Android Issue:** fix: ConfirmScreen / DetailScreen / EventMatchScreen — WRITE_CONTACTS ve READ_CALENDAR izinleri için rationale UI yok

Android Problemi:
shouldShowRequestPermissionRationale() loop oluşturuyordu.
Kalıcı reddedilen kamera izni için Settings yönlendirmesi yoktu.
WRITE_CONTACTS ve READ_CALENDAR izin rationale UI yoktu.

iOS Kuralı:
PermissionCoordinator.request*() authorizationStatus kontrolü yapar.
.permanentlyDenied → openSettings() → bir daha requestAccess ASLA çağrılmaz.
Rationale sheet her zaman PermissionRationaleSheet component'i kullanır.

Yasak:
- `authorizationStatus == .denied` iken `requestAccess()` çağırmak
- İzin reddini sessizce yutmak (kullanıcıya bildirim şart)
- Camera kalıcı red → uygulama kilitlenmesi

Kontrol:
- Kamera kalıcı red → "Ayarlara Git" butonu görünür (PermissionDenialUITests)
- Takvim red → EventMatch ekranı "atla" seçeneği gösterir, kilitlenmez
- Kişiler red → Kişi SwiftData'ya kaydedilir, rehbere eklenmez (graceful skip)

---

## Cat-8 — Thread Safety (Callback on Any Thread)

**Android Issue:** fix: Room DB ve DataStore şifrelenmeden saklanıyor — root cihazlarda veri açık [P1-06]

Android Problemi:
OnSharedPreferenceChangeListener herhangi thread'de tetikleniyordu.
callbackFlow içinde trySend() main thread garantisi olmadan çağrılıyordu.
EncryptedSharedPreferences'a IO dispatcher dışından erişim thread-unsafe davranış üretiyordu.

iOS Kuralı:
Tüm ViewModel'lar @MainActor.
UserProfileStore actor — serileştirilmiş Keychain erişimi.
@AppStorage sadece main thread'den kullanılır.

Kontrol:
- ViewModel'da @MainActor olmayan @Published yoktur
- UserProfileStore'dan concurrent Task erişimi → veri tutarlı

---

## Cat-9 — Duplicate VCardParser

**Android Issue:** fix: QR vCard — parseVCardFile() Kotlin implementasyonu [2/2]
**Android Issue:** fix: QR vCard pipeline — scan → ConfirmScreen doğrulaması [1/2]

Android Problemi:
domain/vcf/VCardParser (dosya tabanlı, RFC 6350 unfold) ve
domain/vcard/VCardParser (in-memory, unfold yok) iki ayrı implementasyon.
In-memory parser katlanmış (folded) satırları işleyemiyordu.
Zamanla iki parser birbirinden iyice ayrıştı.

iOS Kuralı:
Tek VCardParser — ParseSource enum ile kaynak ayrımı.
RFC 6350 unfold her zaman uygulanır (string veya file fark etmez).

Yasak:
- `QRVCardParser`, `FileVCardParser` gibi ayrı class'lar
- Unfold'u sadece file source için yapmak

Kontrol:
- `VCardParser.parse(.string(foldedText))` → doğru parse (VCardParserTests)
- `VCardParser.parse(.file(foldedFile))` → aynı sonuç
- Tek class, iki test case

---

## Cat-10 — ICS MIME Type

**Android Issue:** fix: ICS CRLF/header injection — IcsGenerator

Android Problemi:
Android ACTION_SEND_MULTIPLE ile .ics dosyasına özel MIME tipi atanamıyordu.
Mail client dosya uzantısından MIME'i tahmin etmeye çalışıyordu.
Bazı mail client'ları ICS ekini takvim daveti olarak tanımıyordu.

iOS Kuralı:
UIActivityViewController + ICSActivityItemSource kullanılır.
UTType.calendarEvent doğru MIME'i sağlar.
MFMailComposeViewController varsa addAttachmentData(_:mimeType:fileName:) ile "text/calendar".

Kontrol:
- ICS dosyası Calendar uygulamasına teklif edilir (activity sheet'te görünür)
- Mail ile paylaşımda MIME "text/calendar" gönderilir

---

## Bug #106–#115 — CardParser OCR Hataları

**Android Issue:** fix: CardParser — 10/12 test kartında isim/şirket/adres/ünvan/mail parsing hataları (KV1 KV3 KV4 KV6 KV7 KV9 KV10 KV12)
**Android Issue:** fix: CardParser — isim/soyisim hatalı ayrıştırma (all-caps metin ve kısaltma sorunları)
**Android Issue:** fix: CardParser — dahili (extension) numaralar ana telefon listesine karışıyor
**Android Issue:** fix: CardParser — ünvan eksik veya noktalama/köşeli parantez içeriyor
**Android Issue:** fix: CardParser — e-posta adresi bazı kartvizitlerde ayrıştırılamıyor
**Android Issue:** fix: CardParser — adres bilgisi alınamıyor veya birden fazla adres yanlış birleştiriliyor
**Android Issue:** fix: CardParser — 3 veya daha fazla telefon numarasında hatalı ayrıştırma
**Android Issue:** fix: CardParser — fallback title atamasında looksLikeName guard eksik

Android Problemi:
12 test kartının 10'unda alan parsing hataları vardı.
All-caps metinde büyük/küçük harf normalizasyonu yoktu.
Faks ve dahili numaralar (ext., dahili) telefon olarak işaretleniyordu.
3+ telefon varlığında yanlış ayrıştırma oluyordu.
Adres satırları yanlış birleştiriliyordu.

iOS Kuralı:
CardParser.parseCardText() NSRegularExpression ile Kotlin versiyonunun birebir portu.
Faks etiket regex'i: `(?i)(faks?|fax|📠|f\.?)` — bu etiket varsa telefon sayılmaz.
Dahili regex: `(?i)(ext\.?|dahili|pbx)\s*\d+` — telefon listesine eklenmez.
All-caps tespit: `word == word.uppercased() && word.count > 1` → `.capitalized`.
Maksimum 3 telefon: `.prefix(3)` ile kesilir.

Kontrol (CardParserTests — 42+ test):
- KV1: Standart Türkçe kartvizit → doğru ad/soyad/şirket
- KV3: All-caps soyad → normalize edilmiş format
- KV4: Faks numarası hariç tutulur
- KV6: Dahili numara hariç tutulur
- KV7: 4 telefon → maksimum 3 alınır
- KV9: Email @ işareti ile doğru parse
- KV10: Tek adres satırı
- KV12: Ünvan noktalama temizlenir

---

## Bug #116 — `[Etkinlik]` Boşken Bozuk Metin

**Android Issue:** fix: MailComposeScreen — eventName boş iken etkinlik içeren şablon seçilince bozuk metin geliyor, etkinliksiz versiyon açılmalı

Android Problemi:
`[Etkinlik]` token'ı olan şablonda eventName boşken
" etkinliğinde tanıştık" gibi yarım cümleler body'de görünüyordu.
Subject'te " - " ile başlayan veya biten bozuk metin oluşuyordu.

iOS Kuralı:
MailTemplateResolver: `[Etkinlik]` boşsa içeren cümle body'den tamamen kaldırılır.
Subject'teki " - [Etkinlik]" ve "[Etkinlik] - " kalıpları temizlenir.

Kontrol:
- eventName = "" → body'de "etkinlik" kelimesi geçen cümle yok
- eventName = "" → subject'te " - " veya "---" kalıntısı yok
- eventName = "TechDay" → "[Etkinlik]" → "TechDay" ile değiştirilir

---

## Bug #119 — Screenshot Koruması

**Android Issue:** fix: MainActivity — FLAG_SECURE eksik, kişi ve kartvizit verileri task-switcher thumbnail'ine açık [SEC-02]

Android Problemi:
MainActivity.window.addFlags(FLAG_SECURE) eklenmemişti.
Uygulama task switcher'da kişi listesi görüntülüyordu.
Screenshot ve ekran kaydı kişi verilerini açığa çıkarıyordu.

iOS Kuralı:
ScreenshotProtectionModifier: scenePhase == .inactive → siyah overlay.
RootNavigationView'a .modifier(ScreenshotProtectionModifier()) uygulanır.

Kontrol:
- App background'a alınınca kişi listesi görünmez (siyah overlay)
- App switcher thumbnail'inde kişi verisi yok

---

## Bug #120 — Root/Jailbreak Tespiti

**Android Issue:** fix: root/emülatör tespiti yok — MainActivity / AppContainer

Android Problemi:
Root edilmiş cihazlarda SQLCipher key okunabilirdi.
Emülatörde test bypass'ı yapılabiliyordu.
Build.TAGS ve Build.FINGERPRINT kontrolleri eksikti.

iOS Kuralı:
JailbreakDetector: hasSuspiciousFiles() + canWriteOutsideSandbox() + hasJailbreakDylibs().
Simulator'da her zaman false döner (#if targetEnvironment(simulator)).
Release build'de CardConnectApp.init'te kontrol edilir.

Kontrol:
- Simulator → JailbreakDetector.isJailbroken == false
- Release build, Cydia path'i → true (unit test ile mock)
- Uyarı dialog'u non-blocking: kullanıcı devam edebilir

---

## Bug #133 — ICS Dosyası Silinmedi

**Android Issue:** fix: ContactsViewModel.delete() — kişi silinince ICS davet dosyası temizlenmiyor [ORTA]

Android Problemi:
Contact.delete() Room kaydını ve fotoğrafları siliyordu.
Documents/ics/invite_{id}.ics dosyası diskte kalıyordu.
Uygulama kullandıkça ics/ dizini doluyordu.

iOS Kuralı:
ContactStore.delete(id:) → PhotoStorage.deleteICS(for: id) koordineli çağrılır.
Delete akışı: SwiftData sil → fotoğraflar sil → ICS sil → CNContact sil (deviceContactID varsa).

Kontrol:
- Contact silinince ics/invite_{uuid}.ics dosyası yok
- Contact silinince photos/ klasöründeki fotoğraflar yok

---

## Bug #134 — Notes Üzerine Yazılıyor

**Android Issue:** fix: EventMatchViewModel.selectEvent() — kişinin mevcut notes alanı etkinlik kaydında üzerine yazılıyor [ORTA]

Android Problemi:
`contact.notes = eventContext` — mevcut notun üzerine yazıyordu.
Kullanıcının Confirm ekranında girdiği not kaybediyordu.

iOS Kuralı:
Etkinlik seçimi notes alanını her zaman append eder, üzerine yazmaz.
`contact.notes = [existing, eventContext].filter { !$0.isEmpty }.joined(separator: "\n")`

Kontrol:
- Kullanıcı not girdi → etkinlik seçildi → her iki metin de notes'ta mevcut
- Notes boşsa → sadece etkinlik bağlamı eklenir

---

## Bug #135 — Merge'de Notes Kaybı

**Android Issue:** fix: DuplicateViewModel.mergeIntoExisting() — birleştirmede yeni kişinin notes alanı kayboluyor [ORTA]

Android Problemi:
Merge sırasında existing.notes kullanılıyor, incoming.notes atılıyordu.
Yeni taranan karttaki not tamamen kaybediliyordu.

iOS Kuralı:
DuplicateDetector.merge(): notes concat + distinct.
`[existing.notes, incoming.notes].filter { !$0.isEmpty }.uniqued().joined(separator: "\n")`

Kontrol:
- existing.notes = "A", incoming.notes = "B" → merged.notes = "A\nB"
- existing.notes = "A", incoming.notes = "A" → merged.notes = "A" (tekrar yok)
- existing.notes = "", incoming.notes = "B" → merged.notes = "B"

---

## Bug #136 — CNContact'a Notes Yazılmadı

**Android Issue:** fix: ContactsRepository.updateContact() — notes parametresi eksik, cihaz rehberindeki not hiç güncellenmiyor [MAJOR]

Android Problemi:
ContentValues'a notes eklenmemişti.
Kullanıcının girdiği notlar telefon rehberinde görünmüyordu.

iOS Kuralı:
DeviceContactsService: CNMutableContact.note = contact.notes explicit set edilir.
addContact() ve updateContact() her ikisinde de note field dahil edilir.

Kontrol:
- Kişi rehbere eklenince CNContact.note == contact.notes
- Kişi güncellenince CNContact.note güncellenir

---

## Bug #138 — Back Button Broken

**Android Issue:** fix: DuplicateScreen — merge öncesi alan karşılaştırma önizlemesi ve geri butonu yok [ORTA]

Android Problemi:
NavController pop işlemi DuplicateScreen'den sonra beklenmedik ekrana gidiyordu.
Back stack yönetimi string route ile tutarsız davranıyordu.

iOS Kuralı:
NavigationPath.removeLast() ile geri dönüş.
EventMatch'ten HomeView'a dönüş: path.removeLast(path.count) — back stack tamamen temizlenir.

Kontrol:
- DuplicateView → Confirm'e geri dönüş çalışmalı (DuplicateMergeUITests)
- EventMatch tamamlanınca back stack boş olmalı (HomeView görünmeli)

---

## Bug #139 — Calendar SecurityException

**Android Issue:** fix: EventMatchScreen — takvim izni reddedilince kullanıcıya bildirim yapılmadan onDone() çağrılıyor [ORTA]
**Android Issue:** fix: EventMatchScreen — READ_CALENDAR reddedilince etkinsiz adım atlanmalı, loading kilitlenmemeli [P0-03]

Android Problemi:
READ_CALENDAR izni kontrol edilmeden CalendarContract sorgusu yapılıyordu.
SecurityException runtime'da fırlatılıyordu.
İzin reddedilince loading state'te takılı kalıyordu.

iOS Kuralı:
CalendarService.fetchTodayEvents(): EKAuthorizationStatus kontrol eder.
.fullAccess değilse boş array döner — crash yok, kilitlenme yok.
EventMatchViewModel: izin red → Snackbar göster → onDone() çağır.

Kontrol:
- Takvim izni red → EventMatch ekranı "Atla" gösterir, kilitlenmez
- EKEventStore sorgusu izinsiz yapılmaz

---

## Bug #141 — Boş Profil QR Crash

**Android Issue:** fix: HomeScreen — profil dolmamışken QR dialog uyarısız açılıyor, eksik bilgilerle vCard üretiliyor [ORTA]

Android Problemi:
UserProfile.fullName boşken ZXing QR generate ediyordu.
Boş vCard QR kodu anlamsız ve potansiyel crash noktasıydı.

iOS Kuralı:
ProfileView'da QR butonu: `profile.fullName.isEmpty ? .disabled : .enabled`.
QR generate öncesi guard check: `guard !profile.fullName.isEmpty else { return }`.

Kontrol:
- Profil boşken QR butonu disabled
- Profil doluyken QR üretilir, görüntülenir
- Boş vCard QR generate edilmez

---

## Bug #Backup — Hassas Dosyalar Yedekleniyor

**Android Issue:** fix: backup_rules.xml ve data_extraction_rules.xml boş — hassas veriler yedeğe dahil oluyor [P0-02]
**Android Issue:** fix: backup_rules.xml — ICS ve avatar dosyaları yedekten dışlanmamış, üçüncü kişi verileri Google Drive'a sızıyor [SEC-01]

Android Problemi:
backup_rules.xml boştu — tüm dosyalar yedekleniyordu.
Kişi fotoğrafları, ICS dosyaları ve avatar Google Drive'a gidiyordu.
Üçüncü taraf kişi verilerinin yedeği KVKK uyumsuzluğuydu.

iOS Kuralı:
photos/, ics/, vcf/ dizinleri isExcludedFromBackup = true ile işaretlenir.
İlk uygulama açılışında (AppDelegate veya CardConnectApp.init) uygulanır.
iCloud CloudKit container yok (ModelConfiguration cloudKitDatabase: .none).

Kontrol:
- photos/ dizini → URLResourceValues.isExcludedFromBackup == true
- ics/ dizini → URLResourceValues.isExcludedFromBackup == true
- iCloud Drive'da kişi fotoğrafı görünmez

---

## Bug #DestructiveMigration — Veri Kaybı

**Android Issue:** fix: AppDatabase fallbackToDestructiveMigration=true — güncelleme sırasında tüm veri siliniyor [P1-01]

Android Problemi:
Room migration yazılmamış, fallbackToDestructiveMigration=true idi.
Uygulama güncellenince tüm kullanıcı verisi siliniyordu.

iOS Kuralı:
SwiftData VersionedSchema + MigrationStage.custom kullanılır.
SchemaV2 için custom migration stage yazılır (boş bile olsa placeholder şarttır).
Destructive migration asla kullanılmaz.

Kontrol:
- SchemaV1 → SchemaV2 geçişinde ContactModel verileri korunur
- Migration öncesi ve sonrası kişi sayısı eşit

---

## Bug #PhotoCleanup — Geçici Fotoğraflar Kalmıyor

**Android Issue:** fix: PhotoStorage — ConfirmScreen iptal edilince temp OCR fotoğrafları silinmiyor, disk sızıntısı [ORTA]

Android Problemi:
Kullanıcı Confirm ekranından geri dönünce çekilen fotoğraflar diskte kalıyordu.
Zamanla photos/ dizini gereksiz dosyalarla doluyordu.

iOS Kuralı:
ConfirmViewModel: kayıt başarılı olmadan deinit/onDisappear → fotoğraflar silinir.
`deinit { if !saved { Task { await photoStorage.deleteAll(paths: photoPaths) } } }`

Kontrol:
- Confirm → iptal/geri dön → photos/ klasöründe o scan'ın fotoğrafları yok
- Confirm → kaydet → fotoğraflar korunur

---

## Bug #KVKK — Gizlilik Uyumsuzluğu

**Android Issue:** feat: Privacy Policy ve KVKK aydınlatma metni eksik — Play Store yayını engellenebilir [P0-01]
**Android Issue:** fix: OnboardingScreen — 'Atla' butonu privacyAccepted'i atlayarak KVKK onay alınmadan ilerliyor [MAJOR]
**Android Issue:** fix: PrivacyPolicyScreen — 'veri aktarımı yok' beyanı DataStore Google Drive yedeğiyle çelişiyor [YÜKSEK]

Android Problemi:
Onboarding'de "Atla" butonu privacy consent'i bypass ediyordu.
Gizlilik politikası iCloud yedekleme yapılmadığını belirtiyordu ama backup kuralları boştu.
KVKK onayı timestamp'i kaydedilmiyordu.

iOS Kuralı:
Onboarding son sayfasında KVKK checkbox olmadan "Profili Kur" tıklanamaz.
"Atla" butonu sayfa 1 ve 2'de — consent'i bypass edemez (sayfa 3'e geçilmez).
privacy_accepted timestamp @AppStorage'da saklanır.
Gizlilik politikası backup dışlamayla tutarlı olmalı.

Kontrol:
- Onboarding sayfa 1-2 "Atla" → doğrudan HomeView (consent olmadan)
- Onboarding sayfa 3 checkbox işaretli değilken "Profili Kur" → disabled
- privacy_accepted @AppStorage key set edilmiş

---

## Bug #DeadCode — Kullanılmayan Ekranlar

**Android Issue:** fix: ui/detail/ContactEditScreen.kt — ui/edit/ ile çakışan kopya dosya, NavGraph'ta kullanılmıyor

Android Problemi:
ContactEditScreen iki farklı dizinde iki kopya olarak vardı.
Biri NavGraph'a bağlıydı, diğeri dead code'du.
Farklı bug fix'leri yanlış dosyaya uygulandı.

iOS Kuralı:
Her ekran için tek .swift dosyası.
Tüm ekranlar AppRoute'ta bir case'e karşılık gelir.
Kullanılmayan dosya yoktur — SwiftLint bunu enforce eder.

Kontrol:
- AppRoute case sayısı == navigationDestination switch case sayısı
- Hiçbir View dosyası AppRoute'ta karşılıksız değil

---

## Bug #CameraPermLoop — İzin Döngüsü

**Android Issue:** fix: CameraScreen — kamera izni kalıcı reddedilince PermissionRationale döngüye giriyor, Ayarlara Git akışı yok [ORTA]

Android Problemi:
shouldShowRequestPermissionRationale() false döndürünce ne yapılacağı belli değildi.
Kalıcı reddedilen izin tekrar tekrar isteniyordu.
Ayarlara yönlendirme sadece kameraya uygulansa da WRITE_CONTACTS ve READ_CALENDAR için yoktu.

iOS Kuralı:
PermissionCoordinator.request*() fonksiyonu AVCaptureDevice.authorizationStatus kontrol eder.
.denied veya .restricted ise requestAccess() çağrılmaz — .permanentlyDenied döner.
Her izin tipi için ayrı rationale metin PermissionRationaleSheet'te tanımlanır.

Kontrol:
- Kamera: .denied → .permanentlyDenied → "Ayarlara Git" gösterilir (PermissionDenialUITests)
- Kişiler: .denied → graceful skip → contact SwiftData'ya eklenir, CNContact'a eklenmez
- Takvim: .denied → EventMatch atlanır, snackbar gösterilir

---

*Son güncelleme: 2026-06-24*
*Android issue referansları: tolgabarisalcitepe/and-card-connect #1–#169*
