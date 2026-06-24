# MASTER_INSTRUCTIONS.md
> Bu repository'de issue çözmeden önce oku.
> Kurallar mimari kararları değil, çalışma biçimini tanımlar.

---

## Referans Öncelik Sırası

Issue çözerken şüpheye düştüğünde bu sırayla oku:

1. `docs/iOS_ARCHITECTURE.md` — mimari kararlar burada, tartışılmaz
2. `docs/DOMAIN_MODEL.md` — alan tipleri, limitler, business rules
3. `docs/WORKFLOWS.md` — kullanıcı akışları, ekran geçişleri
4. `docs/PROJECT_CONTEXT.md` — Android'deki orijinal özellik listesi
5. `ai/ANDROID_LESSONS_LEARNED.md` — tekrar edilmeyecek hatalar
6. `ai/BUG_PREVENTION_MATRIX.md` — kontrol kriterleri

---

## Çalışma Kuralları

### Scope

Issue kapsamı dışına çıkma.
Issue'da yazmayan bir şeyi düzeltme, refactor etme, ekleme.
Yan etkisi olan değişiklik yapacaksan yorumda belirt, kendin yapma.

### Mimari

Yeni mimari icat etme.
iOS_ARCHITECTURE.md'de tanımlı pattern'ların dışına çıkma.
Mimariyle çelişen bir gereksinim varsa önce kullanıcıya sor.

### Android Bugları

Android'de tespit edilmiş bug kategorilerini tekrar etme.
LIKE tabanlı duplicate sorgusu yazma.
String route kullanma.
İki VCardParser implementasyonu yaratma.
Permission döngüsüne girecek kod yazma.
Stale state bırakan akış tasarıma.

### Acceptance Criteria

Issue'daki her Acceptance Criteria maddesi tamamlanmadan issue kapatılmaz.
"Çalışıyor gibi görünüyor" yeterli değil — test et.
Test yazılmadan AC tamamlandı sayılmaz.

### Test

Kod yazıldıktan sonra ilgili testleri çalıştır.
Pure function değiştirdiysen (CardParser, VCardParser, DuplicateDetector, URLValidator, ICSGenerator):
```
İlgili test dosyasını çalıştır.
Yeni davranış için test ekle.
```
ViewModel değiştirdiysen:
```
Mock ile unit test ekle.
```
Navigation değiştirdiysen:
```
İlgili UI test'i kontrol et.
```

### Commit

Commit üretmeden önce dosya bazında değişiklik özetini yaz:
```
Değişen dosyalar: X.swift, Y.swift
Sebep: Issue #N — [kısa açıklama]
Test: XTests.swift'e 3 test case eklendi
```

Commit mesajı formatı:
```
fix: [ekran/modül] — [ne düzeltildi]
feat: [ekran/modül] — [ne eklendi]
test: [XTests] — [ne test edildi]
```

---

## Kod Yazma Kuralları

### Actor Kullanımı

Geçici scan state → ScanFlowActor
DB işlemleri → ContactStore (@ModelActor)
Profil PII → UserProfileStore (actor)
Tüm ViewModel'lar → @MainActor

Actor dışından mutable state erişimi yoktur.

### Navigation

```swift
// DOĞRU
path.append(AppRoute.duplicate(contactID: id))
path.removeLast()
path.removeLast(path.count)

// YANLIŞ
path.append("duplicate")
path.append("\(id)")
```

### Persistence

```swift
// DOĞRU — exact match
#Predicate<ContactModel> { $0.id == targetID }

// YANLIŞ — wildcard riski
#Predicate<ContactModel> { $0.phonesJSON.contains(phone) }
```

### Field Limits

```swift
// Contact oluşturmanın HER yolunda FieldLimits uygulanır
// Contact.init bu garantiyi verir — ayrıca truncate yazmana gerek yok
let contact = Contact(firstName: rawFirstName, ...)  // init zaten kesiyor
```

### URL Güvenliği

```swift
// DOĞRU — parse anında validate
let linkedin = URLValidator.validateLinkedIn(raw) ? URLValidator.normalizeLinkedIn(raw) ?? "" : ""

// YANLIŞ — display anında validate
if contact.linkedin.contains("linkedin.com") { open(contact.linkedin) }
```

### ICS Gönderimi

```swift
// DOĞRU — UTType.calendarEvent
UIActivityViewController(activityItems: [ICSActivityItemSource(fileURL: icsURL)])

// YANLIŞ — MIME yanlış
mailVC.addAttachmentData(icsData, mimeType: "message/rfc822", fileName: "invite.ics")
```

### Permission

```swift
// DOĞRU — önce status kontrol
let result = await permissionCoordinator.requestCamera()
switch result {
case .granted:           startCamera()
case .denied:            showSnackbar("İzin reddedildi")
case .permanentlyDenied: showSettingsButton()
}

// YANLIŞ — loop
if authStatus == .denied { requestAccess() }  // tekrar istek — döngü
```

---

## Kod Review Checklist

Değişiklik göndermeden önce kontrol et:

- [ ] AppRoute'ta yeni case varsa navigationDestination'a eklendi mi?
- [ ] Yeni Contact oluşturma Contact.init üzerinden mi? (field limits garantisi)
- [ ] #Predicate içinde LIKE, CONTAINS veya substring operasyonu yok mu?
- [ ] LinkedIn veya harici URL URLValidator'dan geçiyor mu?
- [ ] İzin isteği authorizationStatus kontrolü sonrası mı yapılıyor?
- [ ] Actor dışından mutable shared state erişimi yok mu?
- [ ] VCard işleme tek VCardParser üzerinden mi (ParseSource enum)?
- [ ] Scan akışı tamamlanınca ScanFlowActor.reset() çağrılıyor mu?
- [ ] Silme akışı: SwiftData + fotoğraflar + ICS + CNContact sırasıyla yapılıyor mu?
- [ ] Yeni .swift dosyası açıldıysa AppRoute'ta veya başka bir route'ta karşılığı var mı?
- [ ] Info.plist'te sadece kullanılan izinler beyan edilmiş mi?
- [ ] Test eklenmediyse neden eklenmedi — yoruma yazdın mı?

---

## Karar Kılavuzu

### "Bu nasıl yapılmalı?" sorusu

1. iOS_ARCHITECTURE.md'de kod snippet'i var mı? → Onu kullan.
2. BUG_PREVENTION_MATRIX.md'de bu konu için kural var mı? → O kuralı uygula.
3. Android'de nasıl yapıldı? → ANDROID_LESSONS_LEARNED.md'de "iOS Uygulaması" bölümüne bak.
4. Hiçbirinde yok mu? → iOS_ARCHITECTURE.md mimarisiyle tutarlı çözüm üret, yorumda belirt.

### "Bu doğru mu?" sorusu

Kararsız kalırsan iOS_ARCHITECTURE.md doğrudur.
Android kodu referans değildir — hatalar için kayıt.

### "Issue'da yazmıyor ama görüyorum" durumu

Scope dışı bug veya iyileştirme gördüysen:
```
Kodu değiştirme.
Issue yorumuna yaz: "Bu dosyada X sorunu var, ayrı issue açılabilir."
```

---

*Versiyon: 1.0 — 2026-06-24*
