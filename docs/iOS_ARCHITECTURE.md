# IOS_ARCHITECTURE.md

> Technical Architecture Specification
> Card Connect iOS

Bu doküman sistemin teknik mimarisini tanımlar.

İş kuralları:
- PROJECT_CONTEXT.md
- DOMAIN_MODEL.md
- WORKFLOWS.md

içerisinde bulunur.

---

# Architecture Principles

## Offline First

Tüm temel özellikler internet bağlantısı olmadan çalışmalıdır.

## Privacy First

Kullanıcı verileri varsayılan olarak cihaz içerisinde tutulur.

## Actor First

Paylaşılan mutable state kullanılmaz.

## Single Source Of Truth

Her sorumluluk tek katmanda bulunur.

## Dependency Injection

ViewModel'lar global singleton kullanmaz.

---

# Tech Stack

| Concern | Choice |
|----------|----------|
| Language | Swift 6 |
| UI | SwiftUI |
| Persistence | SwiftData |
| Navigation | NavigationStack |
| OCR | VisionKit |
| QR | DataScannerViewController |
| Contacts | Contacts Framework |
| Calendar | EventKit |
| Mail | MFMailComposeViewController |
| Security | Keychain + CryptoKit |
| Async | Swift Concurrency |
| Testing | XCTest |
| Lint | SwiftLint |

---

# Project Structure

CardConnect/

App/
Domain/
Data/
UI/
Security/
Tests/

---

# Layer Responsibilities

## App Layer

Sorumluluklar:

- Dependency injection
- App lifecycle
- Root navigation
- Application startup

---

## Domain Layer

Sorumluluklar:

- Contact
- ParsedCard
- EmailTemplate
- Event
- UserProfile

Kurallar:

- Framework bağımlılığı içermez
- UI içermez
- Persistence içermez

---

## Data Layer

Sorumluluklar:

- SwiftData
- Keychain
- Calendar access
- Contacts access
- File storage

Kurallar:

- Domain nesnelerini saklar
- UI bilmez

---

## UI Layer

Sorumluluklar:

- SwiftUI ekranları
- ViewModels
- Navigation

Kurallar:

- Persistence erişimi Store üzerinden yapılır

---

## Security Layer

Sorumluluklar:

- Jailbreak detection
- Screenshot protection
- Encryption
- Backup exclusion

---

# Persistence Architecture

## SwiftData

Tüm kalıcı veriler SwiftData içerisinde tutulur.

Örnek:

- Contact
- EmailTemplate

---

## Keychain

Sadece hassas veriler:

- UserProfile
- Encryption keys

---

## AppStorage

Sadece hassas olmayan ayarlar:

- onboarding_done
- privacy_accepted
- swipe_hint_shown

---

# Navigation Architecture

## Typed Routes

String route kullanımı yasaktır.

Tüm navigation:

AppRoute

üzerinden yapılır.

---

## NavigationStack

Root navigation yapısı:

NavigationStack
→ AppRoute

---

## Deep Link Handling

Desteklenen girişler:

- vcf file
- qr card
- share sheet

---

# State Management

## Actor Based State

Scan sürecindeki geçici state:

ScanFlowActor

içerisinde tutulur.

---

## ViewModel Rules

Her ekran:

- bir View
- bir ViewModel

içerir.

---

## Forbidden

Yasak:

- Shared mutable singleton
- Global mutable state

---

# OCR Architecture

## Card Scan

Card Image
↓
Vision OCR
↓
CardParser
↓
ParsedCard

---

## QR Scan

QR
↓
VCardParser
↓
ParsedCard

---

## Import VCF

VCF
↓
VCardParser
↓
ParsedCard

---

# Duplicate Detection

Öncelik sırası:

1. Name + Company
2. Phone
3. Email

İş kuralı DOMAIN_MODEL.md'de tanımlanır.

Implementasyon DuplicateDetector içerisindedir.

---

# Permission Architecture

## Camera

Tarama için kullanılır.

---

## Contacts

Rehber senkronizasyonu için kullanılır.

---

## Calendar

Etkinlik eşleştirme için kullanılır.

---

## Rule

Tüm izinler:

PermissionCoordinator

üzerinden yönetilir.

---

# Security Architecture

## Keychain

Hassas veriler Keychain içerisinde tutulur.

---

## ATS

Arbitrary loads kapalıdır.

---

## Backup Exclusion

Aşağıdaki klasörler yedekleme dışıdır:

- photos/
- vcf/
- ics/

---

## Jailbreak Detection

Uygulama başlangıcında kontrol edilir.

---

## Screenshot Protection

Arka plana geçildiğinde içerik gizlenir.

---

# File Storage

## Photos

Documents/photos/

---

## VCF

temporary/

---

## ICS

temporary/

---

# Testing Strategy

## Unit Tests

Zorunlu:

- CardParserTests
- VCardParserTests
- DuplicateDetectorTests
- ContactMergeTests
- URLValidatorTests
- ICSGeneratorTests

---

## UI Tests

Zorunlu:

- OnboardingUITests
- ScanFlowUITests

---

## Coverage Rules

Aşağıdaki modüller yüksek coverage gerektirir:

- CardParser
- VCardParser
- DuplicateDetector
- URLValidator
- ICSGenerator

---

# Anti Patterns

## Yasak

- String routes
- Shared mutable state
- Multiple VCard parsers
- Raw URL usage
- Wildcard duplicate detection
- Permission loops
- UserProfile in UserDefaults
- Destructive migrations
- Dead permissions
- God objects

---

# Required Components

Aşağıdaki bileşenler bulunmalıdır:

- DependencyContainer
- ScanFlowActor
- ContactStore
- UserProfileStore
- PermissionCoordinator
- DuplicateDetector
- CardParser
- VCardParser
- ICSGenerator
- URLValidator

---

# Architecture References

İş Kuralları:
- DOMAIN_MODEL.md
- WORKFLOWS.md

Mimari Kararlar:
- DECISIONS.md

AI Çalışma Kuralları:
- CLAUDE_RULES.md