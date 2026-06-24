# PROJECT_CONTEXT.md

# Card Connect

Card Connect, fiziksel kartvizitleri dijital ortama aktarmayı ve profesyonel kişi yönetimini kolaylaştırmayı amaçlayan offline-first bir iOS uygulamasıdır.

Kullanıcı bir kartviziti tarar, OCR ile bilgileri çıkarır, doğrular ve yerel veritabanına kaydeder. İsteğe bağlı olarak cihaz rehberi ile senkronizasyon yapılabilir.

---

# Product Vision

Kartvizit toplama sürecini:

Kartvizit
→ Tarama
→ Doğrulama
→ Kişi Kaydı
→ Takip Maili

akışına dönüştürmek.

Amaç:

* Kartvizit kaybını önlemek
* Manuel veri girişini azaltmak
* Takip iletişimini hızlandırmak
* Kullanıcı verisini cihazda tutmak

---

# Target Users

Birincil hedef kitle:

* CEO
* Genel Müdür
* Genel Müdür Yardımcısı
* Kurucu Ortak
* İş Geliştirme Direktörü
* Satış Direktörü
* Kurumsal Satış Uzmanı

İkincil hedef kitle:

* Freelancer
* Danışman
* İş geliştirme uzmanı
* Networking odaklı profesyoneller

---

# Ideal Customer Profile (ICP)

Card Connect, yüksek hacimli son kullanıcı uygulaması değildir.

Amaç:

1000 aktif profesyonel kullanıcıya ulaşmaktır.

Tipik kullanıcı:

* Düzenli olarak konferanslara katılır
* Fiziksel kartvizit toplar
* Follow-up e-postaları gönderir
* LinkedIn üzerinden iletişim kurar
* CRM kullanmasa bile kişi yönetimi ihtiyacı vardır
* Zamanı veri girişinden daha değerlidir

Not Target:

* Öğrenciler
* Genel sosyal kullanıcılar
* Sosyal ağ uygulaması arayanlar
* Milyonlarca son kullanıcıya yönelik viral kullanım senaryoları

---

# Core User Journey

1. Kartvizit tara
2. OCR ile bilgileri çıkar
3. Bilgileri doğrula
4. Duplicate kontrolü yap
5. Etkinlik ilişkilendir
6. Kaydet
7. Takip maili gönder

---

# MVP Scope

## Contact Capture

* Business card scanning
* QR vCard scanning
* VCF import
* OCR extraction
* Manual correction

## Contact Management

* Contact list
* Contact detail
* Contact edit
* Contact delete
* Search

## Duplicate Handling

* Duplicate detection
* Merge flow
* Create new flow

## Event Integration

* Calendar event matching
* Event tagging

## Communication

* Email templates
* Meeting invitation (.ics)
* Mail compose

## Profile

* User profile
* QR generation
* Self card scan

## Privacy

* Offline storage
* Local database
* Device contacts sync

---

# Success Criteria

Bir kullanıcı:

* Kartviziti 30 saniyeden kısa sürede sisteme aktarabilmeli
* Duplicate kayıt oluşturmadan kişi yönetebilmeli
* Kartvizit sonrası takip maili gönderebilmeli
* Verilerinin cihaz dışına çıkmadığını bilmeli

---

# Success Metrics

Birincil hedef:

* 1000 aktif profesyonel kullanıcı

İkincil hedefler:

* Konferans ve etkinliklerde aktif kullanım
* Kartvizitten kişiye dönüşüm oranının yüksek olması
* Follow-up mail kullanımının yüksek olması
* Kullanıcıların kişisel ağlarını yönetmek için uygulamayı tekrar kullanması

Önemli Not:

1000 aktif hedef kullanıcı,
1.000.000 pasif kullanıcıdan daha değerlidir.

---

# Out Of Scope

Bu sürümde yok:

* Cloud sync
* CRM entegrasyonu
* Çok kullanıcılı çalışma
* Web paneli
* AI contact enrichment
* Analytics dashboard
* Push notification sistemi
* Sosyal ağ özellikleri
* Feed sistemi
* Mesajlaşma sistemi

---

# Product Principles

## Offline First

Tüm temel özellikler internet olmadan çalışmalıdır.

## Privacy First

Kullanıcı verisi varsayılan olarak cihazda kalır.

## Fast Capture

Kartvizitten kayda giden akış minimum adım içermelidir.

## Executive Focus

Ürün kararları üst düzey profesyonellerin ihtiyaçlarına göre alınır.

## Low Maintenance

Mimari gereksiz karmaşıklık içermemelidir.

## Single Source Of Truth

İş kuralları ilgili dokümanlarda tanımlanır:

* DOMAIN_MODEL.md
* WORKFLOWS.md
* IOS_ARCHITECTURE.md
* DECISIONS.md

---

# Product Decision Filter

Yeni bir özellik önerildiğinde aşağıdaki sırayla değerlendirilir:

1. Hedef kullanıcıya değer katıyor mu?
2. Kartvizitten follow-up sürecini hızlandırıyor mu?
3. Executive kullanıcı için zaman kazandırıyor mu?
4. MVP kapsamına uygun mu?
5. Bakım maliyetini artırıyor mu?

Bu filtreyi geçemeyen özellikler MVP kapsamına alınmaz.
