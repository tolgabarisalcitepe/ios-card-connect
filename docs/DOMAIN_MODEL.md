# DOMAIN_MODEL.md

## Amaç

Bu doküman Card Connect uygulamasının iş alanını (domain) tanımlar.

Teknik implementasyon detayları IOS_ARCHITECTURE.md içerisinde yer alır.

---

# Core Entities

## Contact

Sistemin temel varlığıdır.

Taratılan veya manuel oluşturulan iş kişisini temsil eder.

### Fields

- id
- source
- status
- firstName
- lastName
- company
- title
- phones[]
- emails[]
- address
- notes
- linkedin
- photoPaths[]
- eventId
- eventName
- deviceContactId
- createdAt
- updatedAt

### Computed

- fullName

### Source Values

- businessCard
- qrCode
- vcfImport
- manual

### Status Values

- new
- contacted
- followedUp
- archived

### Business Purpose

Kartvizitten veya vCard'dan oluşturulan kalıcı kişi kaydıdır.

---

## ParsedCard

OCR veya vCard parse işlemi sonucunda oluşan geçici veri modelidir.

Kalıcı olarak saklanmaz.

### Fields

- firstName
- lastName
- company
- title
- phones[]
- emails[]
- address
- linkedin
- notes

### Business Purpose

Kaydetme öncesindeki doğrulama ekranını besler.

---

## EmailTemplate

Tekrar kullanılabilir e-posta şablonudur.

### Fields

- id
- name
- iconName
- subject
- body
- isDefault
- sortOrder

### Business Purpose

Takip maili oluşturmayı hızlandırır.

---

## Event

Takvim etkinliğini temsil eder.

### Fields

- id
- name
- startTime
- endTime

### Business Purpose

Kişi ile tanışılan etkinliği ilişkilendirir.

---

## UserProfile

Uygulama sahibinin kendi profilidir.

### Fields

- firstName
- lastName
- company
- title
- phone
- email
- linkedin
- website
- avatarPath
- frontCardPath
- backCardPath

### Computed

- fullName
- initials

### Business Purpose

- QR üretimi
- Mail şablonları
- ICS davetleri

için kaynak veri sağlar.

---

# Relationships

UserProfile
→ EmailTemplate Variables

UserProfile
→ QR Generation

UserProfile
→ ICS Organizer

ParsedCard
→ Contact

Contact
→ Event (optional)

Contact
→ Device Contact (optional)

Contact
→ Photos (0..n)

EmailTemplate
→ Mail Compose

Mail Compose
→ Contact

Mail Compose
→ ICS Invitation (optional)

---

# Business Rules

## Contact Rules

- id oluşturulduktan sonra değişmez.
- createdAt yalnızca oluşturulurken set edilir.
- updatedAt her güncellemede yenilenir.
- eventId ve eventName birlikte set edilir.
- Kişi silindiğinde ilişkili dosyalar temizlenir.
- Contact uygulamanın tek kişi kaynağıdır.

---

## Duplicate Detection Rules

Öncelik sırası:

1. Phone
2. Email
3. FirstName + LastName + Company

İlk güçlü eşleşme geçerlidir.

---

## Merge Rules

### Scalar Fields

Aşağıdaki alanlarda:

- firstName
- lastName
- company
- title
- address
- linkedin

Yeni değer boş değilse kazanır.

---

### Collections

phones
→ union

emails
→ union

photoPaths
→ union

---

### Notes

- Veri kaybı yasaktır.
- Notlar birleştirilir.
- Tekrarlayan satırlar kaldırılır.

---

## Email Template Rules

- Default template silinemez.
- Custom template silinebilir.
- sortOrder görüntüleme sırasını belirler.

---

# Domain Invariants

## Contact Integrity

Bir Contact aşağıdaki alanlardan en az birini içermelidir:

- phone
veya
- email
veya
- company

Tamamen boş kişi oluşturulamaz.

---

## Data Preservation

Merge işlemleri veri kaybına neden olmamalıdır.

---

## Single Contact Identity

Aynı kişi mümkün olduğunca tek kayıt olarak tutulmalıdır.

---

## Event Consistency

eventId ve eventName ayrık durumda bulunamaz.

---

## Profile Consistency

UserProfile uygulama sahibinin tek profilidir.

---

## Offline First

Tüm domain nesneleri internet olmadan çalışmalıdır.

---

## Privacy First

Domain nesneleri varsayılan olarak cihaz içerisinde tutulur.

---

## Single Source Of Truth

Contact uygulamadaki kişi bilgisinin tek kaynağıdır.

Device Contacts yalnızca senkronizasyon hedefidir.

ParsedCard yalnızca geçici veri modelidir.