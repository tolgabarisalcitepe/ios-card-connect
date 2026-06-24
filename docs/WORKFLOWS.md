# WORKFLOWS.md

## Amaç

Bu doküman Card Connect uygulamasındaki kullanıcı akışlarını tanımlar.

Teknik implementasyon detayları IOS_ARCHITECTURE.md içerisinde yer alır.

---

# 1. Business Card Scan

## Amaç

Fiziksel kartviziti dijital kişiye dönüştürmek.

## Akış

User
↓
Card Scan
↓
OCR
↓
Confirm & Edit
↓
Duplicate Check
↓
Event Match
↓
Save Contact

## Sonuç

Yeni kişi oluşturulur veya mevcut kişi güncellenir.

---

# 2. QR vCard Scan

## Amaç

QR kod içindeki vCard bilgisini içeri aktarmak.

## Akış

User
↓
QR Scan
↓
vCard Parse
↓
Confirm & Edit
↓
Duplicate Check
↓
Event Match
↓
Save Contact

## Sonuç

Yeni kişi oluşturulur veya mevcut kişi güncellenir.

---

# 3. VCF Import

## Amaç

Harici .vcf dosyasını sisteme aktarmak.

## Akış

User
↓
Open VCF File
↓
Parse
↓
Confirm & Edit
↓
Duplicate Check
↓
Event Match
↓
Save Contact

## Sonuç

Yeni kişi oluşturulur veya mevcut kişi güncellenir.

---

# 4. Duplicate Detection

## Amaç

Aynı kişinin tekrar oluşturulmasını önlemek.

## Tetikleme

Kaydetme öncesi veya sonrasında.

## Eşleşme Kuralları

1. Ad + Soyad + Şirket
2. Telefon
3. Email

## Kararlar

Duplicate bulundu

↓

Merge Existing

veya

Create New

## Sonuç

Veri kaybı olmadan tekil kişi listesi korunur.

---

# 5. Contact List

## Amaç

Kayıtlı kişileri görüntülemek ve yönetmek.

## Akış

User
↓
Contact List
↓
Search
↓
Open Contact

Ek işlemler:

- Delete
- Edit
- Send Mail
- Open LinkedIn

---

# 6. Contact Detail

## Amaç

Kişi detaylarını görüntülemek.

## İşlemler

- Telefon ara
- Email gönder
- Adres aç
- LinkedIn aç
- Düzenle
- Sil
- VCF paylaş
- Rehbere ekle

---

# 7. Contact Edit

## Amaç

Kişi bilgilerini güncellemek.

## Akış

Contact
↓
Edit
↓
Validate
↓
Save

## Sonuç

Kişi kaydı güncellenir.

---

# 8. Event Matching

## Amaç

Kişiyi takvim etkinliği ile ilişkilendirmek.

## Akış

Contact
↓
Read Calendar
↓
Select Event
↓
Attach Event
↓
Save

## Sonuç

Contact.eventId
Contact.eventName

alanları güncellenir.

---

# 9. Email Templates

## Amaç

Takip e-postalarını hızlandırmak.

## Akış

Contact
↓
Select Template
↓
Resolve Variables
↓
Preview
↓
Send

## Desteklenen Değişkenler

- [Ad]
- [Tam Ad]
- [Etkinlik]
- [Benim Adım]
- [Ünvanım]
- [Şirketim]

---

# 10. Meeting Invitation

## Amaç

Takvim daveti göndermek.

## Akış

Contact
↓
Create Invitation
↓
Generate ICS
↓
Send Mail

## Sonuç

Alıcı takvim daveti alır.

---

# 11. User Profile

## Amaç

Kullanıcının kendi kartvizitini yönetmek.

## İşlemler

- Profil oluştur
- OCR ile doldur
- Avatar ekle
- QR üret
- Profil güncelle

## Kullanım Alanları

- Email template değişkenleri
- QR paylaşımı

---

# 12. Onboarding

## Amaç

İlk kullanım deneyimini tamamlamak.

## Akış

Welcome
↓
Feature Introduction
↓
Privacy Consent
↓
Profile Setup
↓
Home

## Kurallar

- KVKK onayı olmadan onboarding tamamlanamaz.
- Profil kurulumu önerilir.

---

# 13. Settings

## İşlemler

- Privacy Policy
- KVKK Bilgilendirmesi
- Uygulamayı Paylaş

---

# 14. Permission Strategy

## Camera

Amaç:
Kartvizit ve QR tarama.

Reddedilirse:
Tarama başlatılamaz.

---

## Contacts

Amaç:
Cihaz rehberi senkronizasyonu.

Reddedilirse:
Uygulama çalışmaya devam eder.

---

## Calendar

Amaç:
Etkinlik eşleştirme.

Reddedilirse:
Etkinlik adımı atlanır.

---

# Workflow Principles

## Offline First

Tüm akışlar internet olmadan çalışmalıdır.

## Privacy First

Veriler varsayılan olarak cihazda kalır.

## Fast Capture

Kartvizitten kayda giden yol minimum adım içermelidir.

## Data Preservation

Merge ve güncelleme işlemleri veri kaybına neden olmamalıdır.