# GitHub Issue Standartları — Card Connect Android

Bu belge, projede açılacak tüm issue'ların uyması gereken format ve kurallları tanımlar.

---

## Başlık Formatı

```
<tip>: <ne eksik / ne bozuk> — <ekran veya bileşen>
```

| Tip | Kullanım |
|-----|----------|
| `fix:` | Mevcut bir özellik bozuk veya eksik davranıyor |
| `feat:` | Yeni bir özellik eklenmesi gerekiyor |

**Örnekler**
```
fix: QR vCard — parseVCardFile() Kotlin implementasyonu [2/2]
feat: ContactEditScreen — alanlar + Room kayıt [2/2]
fix: profil kaydedilince kullanıcıya geri bildirim (Snackbar) yok
```

**Kurallar**
- Teknik ve geliştirici odaklı yaz; UI tarafındaki kullanıcı ifadelerini değil, kod seviyesindeki sorunu tanımla
- Birden fazla adıma bölünen işlerde `[1/2]`, `[2/2]` son eki kullan
- Label: `bug` (fix) veya `enhancement` (feat)

---

## Body Formatı

Her issue aşağıdaki bölümleri **bu sırayla** içermeli:

---

### 1. `## Özet`
Sorunun teknik tanımı. Hangi ViewModel / Screen / Repository etkileniyor, neden kritik, kullanıcı etkisi nedir.

```markdown
## Özet
`ConfirmViewModel`'de `.vcf` dosyası parse edilmiyor. QR tarandıktan sonra
`storeQrVCard()` ile yazılan dosya okunmuyor; kullanıcı kişi kaydetme
ekranına ulaşamıyor.
```

---

### 2. `## RN vs Android — Feature Fark Analizi`
React Native referans uygulaması ile Android implementasyonunu karşılaştıran tablo.  
✅ = çalışıyor / mevcut, ❌ = eksik / çalışmıyor, ⚠️ = araştırılacak / kısmi

```markdown
## RN vs Android — Feature Fark Analizi
| Davranış | React Native | Android |
|---|---|---|
| vCard parse | ✅ `parseVCard.ts` | ❌ `parseVCardFile()` yok |
| ConfirmScreen yönlendirme | ✅ navigator.push | ⚠️ araştırılacak |
```

---

### 3. `## Beklenen Davranış`
Ne yapılması gerektiğini açıkla. Gerekirse Kotlin kod örneği ekle.

````markdown
## Beklenen Davranış
`CameraViewModel.storeQrVCard()` → dosya yolu `ConfirmViewModel`'e iletilmeli:

```kotlin
fun parseVCardFile(path: String): Contact {
    val lines = File(path).readLines()
    // FN, TEL, EMAIL, ORG satırlarını map et
}
```
````

---

### 4. `## Kök Neden Araştırması` *(opsiyonel)*
Sorunun tam olarak nerede olduğundan emin değilsen, araştırılması gereken noktaları listele.

```markdown
## Kök Neden Araştırması (uygulamadan önce doğrula)
1. `EventMatchViewModel.kt` → `saveEvent()` `notes` alanını Room'a yazıyor mu?
2. `toDomain()` / `toEntity()` mapping'de alan kaybı var mı?
```

---

### 5. `## İlgili Dosyalar`
Değiştirilmesi beklenen dosyaları ve sorumlulukları listele.

```markdown
## İlgili Dosyalar
- `ui/confirm/ConfirmViewModel.kt` — vCard okuma + alan mapping
- `ui/camera/CameraViewModel.kt` — `storeQrVCard()` dönüş yolu
- `domain/model/Contact.kt` — domain model alanları
```

---

### 6. `## Bağımlılık` *(varsa)*
Bu issue'nun önce tamamlanmasını beklediği başka issue'ları belirt.

```markdown
## Bağımlılık
- **#3 (LinkedIn alanı)** tamamlanmadan LinkedIn URL QR'a eklenemez
```

---

### 7. `## Tahmini Süre`

```markdown
## Tahmini Süre
**Uygulama:** ~40 dk
**Review:** ~10 dk
```

---

### 8. `## Referans`
React Native karşılığını dosya + satır düzeyinde göster.

```markdown
## Referans
React Native: `src/utils/parseVCard.ts` — vCard alanları
React Native: `src/screens/ConfirmScreen.tsx` — kayıt akışı
```

---

### 9. `## Doğrulama Checklist (Kapatmadan Önce)`
Her item için durumu `[ ]` (açık) veya `[x]` (tamamlandı) olarak işaretle.  
İlgili olmayan maddeler için `N/A` yaz, maddeyi silme.

```markdown
## Doğrulama Checklist (Kapatmadan Önce)
- [ ] **Navigation** — ilgili ekran geçişleri çalışıyor; back stack doğru
- [ ] **OCR** — kamera / ML Kit tarama davranışı etkilenmediyse N/A
- [ ] **API Calls** — network çağrısı varsa response ve hata durumları test edildi
- [ ] **Local Storage** — Room / DataStore okuma-yazma doğrulandı; alan kaybı yok
- [ ] **Error Handling** — edge case'lerde (boş alan, null, IOException) crash yok
- [ ] **Loading States** — async işlemler süresince UI bloke olmuyor; buton disabled
- [ ] **Analytics** — event log gerekiyorsa eklendi; yoksa N/A
- [ ] **Permissions** — gerekli runtime izinler isteniyor; reddedilince graceful davranış
```

---

## Tam Şablon

Yeni issue açarken aşağıdaki şablonu kopyala:

````markdown
## Özet
<!-- Hangi ekran / ViewModel / Repository etkileniyor, sorun nedir -->

## RN vs Android — Feature Fark Analizi
| Davranış | React Native | Android |
|---|---|---|
| <!-- özellik --> | <!-- ✅ / ❌ / ⚠️ --> | <!-- ✅ / ❌ / ⚠️ --> |

## Beklenen Davranış
<!-- Ne yapılmalı? Kotlin kodu varsa ekle -->

```kotlin
// örnek kod
```

## Kök Neden Araştırması (uygulamadan önce doğrula)
<!-- Belirsizlik varsa araştırılacak noktaları listele; yoksa bu bölümü sil -->

## İlgili Dosyalar
- `path/to/File.kt` — sorumluluk

## Bağımlılık
<!-- Bağımlı issue yoksa bu bölümü sil -->

## Tahmini Süre
**Uygulama:** ~X dk  
**Review:** ~X dk

## Referans
React Native: `src/path/to/file.tsx` — açıklama

## Doğrulama Checklist (Kapatmadan Önce)
- [ ] **Navigation** —
- [ ] **OCR** —
- [ ] **API Calls** —
- [ ] **Local Storage** —
- [ ] **Error Handling** —
- [ ] **Loading States** —
- [ ] **Analytics** —
- [ ] **Permissions** —
````

---

## Kural Özeti

| Kural | Detay |
|-------|-------|
| Başlık dili | Türkçe, teknik terimler İngilizce (ViewModel, Room vb.) |
| Label | `bug` veya `enhancement` — ikisi birden olmaz |
| Bölüm sırası | Özet → RN Fark → Beklenen → Dosyalar → Süre → Referans → Checklist |
| Opsiyonel bölümler | Kök Neden, Bağımlılık — anlamsızsa sil, boş bırakma |
| Checklist | Her madde doldurulmalı; ilgisiz olanlar `N/A` ile işaretlenmeli |
| Kotlin kodu | Beklenen Davranış bölümünde pseudocode değil gerçek implementasyon taslağı |
