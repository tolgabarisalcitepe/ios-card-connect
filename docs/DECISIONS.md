# DECISIONS.md
> Architecture Decision Record (ADR)
> Bu doküman iOS Card Connect projesinde alınan mimari kararları ve gerekçelerini içerir.

---

# ADR-001 — SwiftUI First

Karar:
Uygulama tamamen SwiftUI ile geliştirilecektir.

Gerekçe:
- Modern Apple geliştirme standardı
- NavigationStack entegrasyonu
- Daha düşük boilerplate
- AI tarafından daha tutarlı üretilebilir mimari

Sonuç:
UIKit yalnızca Apple API zorunluluğu olan yerlerde kullanılabilir.

---

# ADR-002 — SwiftData Persistence

Karar:
Yerel veri saklama için SwiftData kullanılacaktır.

Alternatifler:
- CoreData
- Realm
- SQLite wrapper

Gerekçe:
- Native Apple çözümü
- SwiftUI entegrasyonu
- Migration desteği

Sonuç:
Tüm kalıcı modeller SwiftData üzerinden yönetilir.

---

# ADR-003 — NavigationStack + AppRoute

Karar:
String tabanlı navigation yasaktır.

Gerekçe:
Android projesinde string route kaynaklı bakım ve hata problemleri yaşandı.

Sonuç:
Tüm ekranlar AppRoute enum'una bağlıdır.

---

# ADR-004 — Actor Based State Management

Karar:
Geçici scan state ScanFlowActor içinde tutulacaktır.

Gerekçe:
Shared mutable state ve stale state riskini azaltmak.

Sonuç:
ViewModel'lar state paylaşmaz.

---

# ADR-005 — Actor Based Persistence

Karar:
Veri erişimi actor tabanlı store katmanları üzerinden yapılacaktır.

Örnek:
- ContactStore
- UserProfileStore

Gerekçe:
Thread safety
Deterministic erişim

Sonuç:
Store dışından doğrudan mutable veri erişimi yapılmaz.

---

# ADR-006 — Exact Match Duplicate Detection

Karar:
Duplicate tespitinde fuzzy veya wildcard eşleşme kullanılmaz.

Gerekçe:
Yanlış pozitif eşleşme riski.

Sonuç:
Telefon, email ve şirket alanları exact match ile değerlendirilir.

---

# ADR-007 — Single VCard Pipeline

Karar:
Tek VCardParser kullanılacaktır.

Gerekçe:
Birden fazla parser zamanla davranış farklılığı üretir.

Sonuç:
Dosya, QR ve metin kaynakları aynı parsing pipeline'ından geçer.

---

# ADR-008 — Parse-Time Validation

Karar:
URL ve dış veri doğrulaması parse aşamasında yapılır.

Gerekçe:
Model katmanına geçersiz veri girmemelidir.

Sonuç:
Model içinde yalnızca doğrulanmış veri tutulur.

---

# ADR-009 — Permission Coordinator

Karar:
Tüm izin yönetimi PermissionCoordinator üzerinden yapılacaktır.

Gerekçe:
Tutarlı UX
Merkezi kontrol
Kolay test edilebilirlik

Sonuç:
View'lar doğrudan sistem izin API'lerini çağırmaz.

---

# ADR-010 — Privacy First

Karar:
Gizlilik ve veri koruma gereksinimleri geliştirme başlangıcında uygulanacaktır.

Kapsam:
- Privacy Manifest
- Backup Exclusion
- KVKK Onayı
- Cloud Sync Disabled

Sonuç:
Kullanıcı verileri varsayılan olarak minimum paylaşım prensibiyle işlenir.

---

# ADR-011 — Migration Required

Karar:
Destructive migration yasaktır.

Gerekçe:
Kullanıcı verisi kaybı kabul edilemez.

Sonuç:
Her schema değişikliğinde migration tanımlanır.

---

# ADR-012 — Security By Default

Karar:
Güvenlik özellikleri varsayılan olarak açık olacaktır.

Kapsam:
- Screenshot koruması
- Jailbreak kontrolü
- ATS zorlaması
- Kullanılmayan izinlerin yasaklanması

Sonuç:
Release build güvenli varsayılanlarla başlar.

---

# ADR-013 — Test Driven Regression Prevention

Karar:
Android'de hata çıkmış alanlar testsiz bırakılmaz.

Öncelikli Modüller:
- CardParser
- VCardParser
- DuplicateDetector
- ContactMerge
- URLValidator
- ICSGenerator

Sonuç:
Regresyon riski azaltılır.

---

# ADR-014 — Offline First

Karar:
Uygulama tamamen offline çalışacak şekilde tasarlanacaktır.

Gerekçe:
- KVKK uyumluluğu
- Daha düşük operasyon maliyeti
- Basit mimari

Sonuç:
Sunucu bağımlılığı yoktur.
Analytics varsayılan olarak kapalıdır.

---

# ADR-015 — Single Source of Truth

Karar:
Her iş kuralı yalnızca tek yerde tanımlanır.

Örnek:
- Field limits → DOMAIN_MODEL.md
- Navigation → IOS_ARCHITECTURE.md
- User flows → WORKFLOWS.md

Sonuç:
Aynı kural birden fazla dosyada tekrar edilmez.