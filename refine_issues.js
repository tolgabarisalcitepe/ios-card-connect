#!/usr/bin/env node
const { spawnSync } = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');

const REPO = 'tolgabarisalcitepe/ios-card-connect';
const PROJECT_ID = 'PVT_kwHOAXyKK84Bbj1K';

// Field IDs
const F = {
  epic:     'PVTSSF_lAHOAXyKK84Bbj1KzhWTjRk',
  priority: 'PVTSSF_lAHOAXyKK84Bbj1KzhWTjX0',
  status:   'PVTSSF_lAHOAXyKK84Bbj1KzhWThYA',
  estimate: 'PVTF_lAHOAXyKK84Bbj1KzhWTjX8',
  depends:  'PVTF_lAHOAXyKK84Bbj1KzhWTjYU',
};

// Option IDs
const EPIC = {
  foundation: 'fbc97807', ocr:      '32b009b6', storage:  '3680f3eb',
  duplicate:  'fb067348', events:   '5ef2f900', mail:     '5718a494',
  profile:    '6a722ef1', security: '81f50243',
  release: null, // will be set after field update
};
const PRI  = { p0: '8d881b2d', p1: '568a3d40', p2: '28784745' };
const STA  = { todo: 'f75ad846', inprogress: '47fc9ee4', done: '98236657' };

// ─── helpers ────────────────────────────────────────────────────────────────

function gh(...args) {
  const r = spawnSync('gh', args, { encoding: 'utf8', windowsHide: true });
  if (r.error) { console.error('  gh error:', r.error.message); return ''; }
  return (r.stdout || '').trim();
}

function gql(query) {
  const tmp = path.join(os.tmpdir(), `cc_gql_${Date.now()}.graphql`);
  fs.writeFileSync(tmp, query, { encoding: 'utf8', bom: false });
  const r = spawnSync('gh', ['api', 'graphql', '-F', `query=@${tmp}`],
    { encoding: 'utf8', windowsHide: true });
  try { fs.unlinkSync(tmp); } catch {}
  if (r.stderr && r.stderr.includes('error')) console.error('  gql err:', r.stderr.slice(0, 200));
  return (r.stdout || '').trim();
}

function createIssue(title, labels, body, milestone) {
  const tmp = path.join(os.tmpdir(), `cc_body_${Date.now()}.md`);
  fs.writeFileSync(tmp, body, 'utf8');
  const args = ['issue', 'create', '--repo', REPO,
    '--title', title, '--body-file', tmp, '--label', labels];
  if (milestone) args.push('--milestone', milestone);
  try {
    const url = gh(...args);
    return { url, num: url ? url.split('/').pop() : '?' };
  } finally {
    try { fs.unlinkSync(tmp); } catch {}
  }
}

function closeIssue(num) {
  gh('issue', 'close', String(num), '--repo', REPO,
     '--comment', 'Kapatıldı: daha küçük granüler issue\'lara bölündü.');
}

function addToProject(nodeId) {
  const r = gql(`mutation { addProjectV2ItemById(input: { projectId: "${PROJECT_ID}" contentId: "${nodeId}" }) { item { id } } }`);
  try { return JSON.parse(r).data.addProjectV2ItemById.item.id; } catch { return null; }
}

function getNodeId(issueNum) {
  return gh('api', `repos/${REPO}/issues/${issueNum}`, '--jq', '.node_id');
}

function setFields(itemId, epicOpt, priOpt, estimate, depends) {
  const setSelect = (fid, opt) => gql(
    `mutation { updateProjectV2ItemFieldValue(input: { projectId: "${PROJECT_ID}" itemId: "${itemId}" fieldId: "${fid}" value: { singleSelectOptionId: "${opt}" } }) { projectV2Item { id } } }`
  );
  const setText = (fid, txt) => gql(
    `mutation { updateProjectV2ItemFieldValue(input: { projectId: "${PROJECT_ID}" itemId: "${itemId}" fieldId: "${fid}" value: { text: "${txt}" } }) { projectV2Item { id } } }`
  );
  if (epicOpt)  setSelect(F.epic, epicOpt);
  if (priOpt)   setSelect(F.priority, priOpt);
  setSelect(F.status, STA.todo);
  if (estimate) setText(F.estimate, estimate);
  if (depends)  setText(F.depends, depends);
}

function make(title, labels, body, milestone, epicOpt, priOpt, estimate, depends) {
  const { url, num } = createIssue(title, labels, body, milestone);
  const nodeId = getNodeId(num);
  const itemId = addToProject(nodeId);
  if (itemId) setFields(itemId, epicOpt, priOpt, estimate, depends);
  console.log(`  ✓ #${num} [${estimate||'—'}] ${title.substring(0,65)}`);
  return num;
}

// ─── STEP 1: Epic 8 label + milestone ────────────────────────────────────────
console.log('\n▶ Epic 8 label + milestone + project option oluşturuluyor...');

gh('label', 'create', 'epic:8-release', '--color', 'f4a261',
   '--description', 'Epic 8 — Release & App Store', '--repo', REPO, '--force');
gh('label', 'create', 'type:ui-test', '--color', 'c8e6c9',
   '--description', 'UI / Smoke test', '--repo', REPO, '--force');

const ms9raw = gh('api', `repos/${REPO}/milestones`, '-X', 'POST',
  '-f', 'title=Epic 8 — Release & App Store',
  '-f', 'description=App Icons, Launch Screen, TestFlight, App Store, Crash Reporting');
const ms9match = ms9raw.match(/"number":\s*(\d+)/);
const MS8 = ms9match ? ms9match[1] : '9';
console.log(`  Milestone #${MS8} — Epic 8 — Release & App Store`);

// Add "Release & App Store" option to Epic field
const addOptRaw = gql(`mutation {
  updateProjectV2Field(input: {
    projectId: "${PROJECT_ID}"
    fieldId: "${F.epic}"
    singleSelectOptions: [
      {name: "Foundation",        color: BLUE,   description: "Epic 0"}
      {name: "OCR Pipeline",      color: YELLOW, description: "Epic 1"}
      {name: "Contact Storage",   color: GREEN,  description: "Epic 2"}
      {name: "Duplicate Flow",    color: RED,    description: "Epic 3"}
      {name: "Event Matching",    color: PURPLE, description: "Epic 4"}
      {name: "Mail + Templates",  color: BLUE,   description: "Epic 5"}
      {name: "Profile + QR",      color: PINK,   description: "Epic 6"}
      {name: "Security",          color: GRAY,   description: "Epic 7"}
      {name: "Release & App Store", color: ORANGE, description: "Epic 8"}
    ]
  }) { projectV2Field { ... on ProjectV2SingleSelectField { id options { id name } } } }
}`);

try {
  const opts = JSON.parse(addOptRaw).data.updateProjectV2Field.projectV2Field.options;
  const rel = opts.find(o => o.name === 'Release & App Store');
  if (rel) { EPIC.release = rel.id; console.log(`  Release option id: ${rel.id}`); }
} catch (e) { console.error('  Option parse hatası:', e.message); }

// ─── STEP 2: Büyük issue'ları kapat ─────────────────────────────────────────
console.log('\n▶ 2h+ issue\'lar kapatılıyor...');

// #3 SwiftData stack (4h), #6 NavStack (3h), #8 Permission (2h), #9 Onboarding (4h)
// #11 CameraView (6h), #13 CardParser (5h), #14 VCardParser (4h), #15 ConfirmView (6h)
// #20 ContactsView (5h), #21 DetailView (4h), #22 ContactEditView (5h)
// #29 EventMatchView (4h), #32 TemplatesView (4h), #34 MailComposeView (5h)
// #37 ProfileView (4h)
const toClose = [3,6,8,9,11,13,14,15,20,21,22,29,32,34,37];
for (const n of toClose) { closeIssue(n); process.stdout.write('.'); }
console.log('\n  ✓ Kapatıldı');

// ─── STEP 3: Epic 0 — Foundation (granüler) ──────────────────────────────────
console.log('\n▶ Epic 0 — Foundation (granüler issue\'lar)...');
const LBL_F0 = 'epic:0-foundation,ios';

make('feat(foundation): CardConnectApp.swift — @main entry, scene config, onOpenURL',
  LBL_F0+',type:infra', `## Özet
\`@main\` giriş noktası. \`WindowGroup\`, \`ModelContainer\` enjeksiyonu, \`.vcf\` için \`onOpenURL\` handler, \`DependencyContainer\` oluşturma.

## Beklened Davranış
Uygulama derlenip çalışıyor. \`.vcf\` dosyasına tap → \`ScanFlowActor.setIncomingVCard\` çağrılıyor.

\`\`\`swift
@main struct CardConnectApp: App {
    @StateObject private var deps = LiveDependencyContainer()
    var body: some Scene {
        WindowGroup {
            RootNavigationView()
                .environmentObject(deps)
                .onOpenURL { url in Task { await deps.scanFlow.setIncomingVCard(...) } }
        }
    }
}
\`\`\`

## İlgili Dosyalar
- \`App/CardConnectApp.swift\`

## Tahmini Süre
**Uygulama:** ~30dk

## Doğrulama Checklist
- [ ] **Navigation** — uygulama açılıyor, crash yok
- [ ] **Local Storage** — N/A
- [ ] **Permissions** — N/A
`, '1', EPIC.foundation, PRI.p0, '30m', '');

make('feat(foundation): Info.plist — UTI (.vcf), privacy strings, entitlements',
  LBL_F0+',type:infra', `## Özet
\`Info.plist\`'e \`com.apple.mobileconfiguration.profile\` UTI (.vcf import), Türkçe privacy description string'leri (kamera, rehber, takvim). \`CardConnect.entitlements\` — Keychain Access Groups.

## Beklened Davranış
.vcf dosyasına tap → uygulama intent listesinde görünüyor. Privacy string eksikse App Store reddi.

## İlgili Dosyalar
- \`Info.plist\`
- \`CardConnect.entitlements\`

## Tahmini Süre
**Uygulama:** ~20dk

## Doğrulama Checklist
- [ ] **Navigation** — .vcf → uygulama intent'te görünüyor
- [ ] **Permissions** — Tüm permission string'leri Türkçe mevcut
`, '1', EPIC.foundation, PRI.p0, '20m', '');

make('feat(foundation): SchemaV1 — ContactModel @Model',
  LBL_F0+',type:infra', `## Özet
\`ContactModel\` SwiftData \`@Model\`. Tüm alanlar (firstName, lastName, company, title, phones[], emails[], address, linkedIn, notes, photoURLs[], eventName, createdAt, updatedAt).

## Beklened Davranış
\`ModelContainer(for: ContactModel.self)\` başarıyla init ediliyor.

## İlgili Dosyalar
- \`Data/Persistence/Schema/SchemaV1.swift\`

## Tahmini Süre
**Uygulama:** ~30dk

## Doğrulama Checklist
- [ ] **Local Storage** — In-memory container insert round-trip geçiyor
`, '1', EPIC.foundation, PRI.p0, '30m', '');

make('feat(foundation): SchemaV1 — EmailTemplateModel @Model',
  LBL_F0+',type:infra', `## Özet
\`EmailTemplateModel\` SwiftData \`@Model\`. Alanlar: id, name, subject, body, isDefault, order. 5 default seed kaydı.

## Beklened Davranış
İlk açılışta 5 Türkçe default şablon mevcut.

## İlgili Dosyalar
- \`Data/Persistence/Schema/SchemaV1.swift\`

## Tahmini Süre
**Uygulama:** ~30dk

## Doğrulama Checklist
- [ ] **Local Storage** — fetchAll 5 kayıt döndürüyor
`, '1', EPIC.foundation, PRI.p0, '30m', '');

make('feat(foundation): SwiftData ModelContainer + DB şifreleme key setup',
  LBL_F0+',type:infra', `## Özet
\`ModelContainer\` factory: Keychain'den 32-byte key okunuyor; yoksa üretilip kaydediliyor. \`ModelConfiguration(url:, cloudKitDatabase: .none)\`. DB dosyasına \`isExcludedFromBackup = true\`.

## Beklened Davranış
İlk açılışta Keychain'de key yok → üretiliyor. İkinci açılışta aynı key → DB erişiliyor.

## İlgili Dosyalar
- \`App/ModelContainerFactory.swift\`

## Tahmini Süre
**Uygulama:** ~45dk

## Doğrulama Checklist
- [ ] **Local Storage** — DB isExcludedFromBackup=true; key Keychain round-trip OK
`, '1', EPIC.foundation, PRI.p0, '45m', '');

make('feat(foundation): ContactStoreProtocol — CRUD protocol tanımı',
  LBL_F0+',type:infra', `## Özet
\`ContactStoreProtocol\`: insert, update, delete, fetchAll, fetchById, search, findDuplicate. Mock implementasyon test için.

## İlgili Dosyalar
- \`Data/Persistence/ContactStoreProtocol.swift\`
- \`Tests/Mocks/MockContactStore.swift\`

## Tahmini Süre
**Uygulama:** ~20dk
`, '1', EPIC.foundation, PRI.p0, '20m', '');

make('feat(foundation): ContactStore @ModelActor — CRUD implementasyonu',
  LBL_F0+',type:infra', `## Özet
\`ContactStore\` \`@ModelActor\`. insert/update/delete/fetchAll/fetchById/search. \`findDuplicate\`: \`#Predicate ==\` exact match (LIKE yok, Cat-5 fix). modelContext.save() her mutasyondan sonra.

## Beklened Davranış
\`ContactStoreTests\` 15 test geçiyor. % wildcard injection testi geçiyor.

## İlgili Dosyalar
- \`Data/Persistence/ContactStore.swift\`
- \`Tests/Unit/ContactStoreTests.swift\`

## Tahmini Süre
**Uygulama:** ~45dk

## Doğrulama Checklist
- [ ] **Local Storage** — insert→fetchById round-trip; findDuplicate("%" ) null döndürüyor
`, '1', EPIC.foundation, PRI.p0, '45m', '#contactstoreprotocol');

make('feat(foundation): KeychainStore — generic save/load/delete',
  LBL_F0+',type:infra', `## Özet
\`KeychainStore\` generic CRUD: \`save(key:data:)\`, \`load(key:) -> Data?\`, \`delete(key:)\`. \`kSecClassGenericPassword\`, \`kSecAttrAccessibleAfterFirstUnlock\`.

## Beklened Davranış
save→load round-trip geçiyor. load(bilinmeyen key) → nil, throw değil.

## İlgili Dosyalar
- \`Data/Keychain/KeychainStore.swift\`
- \`Tests/Unit/KeychainStoreTests.swift\`

## Tahmini Süre
**Uygulama:** ~45dk
`, '1', EPIC.foundation, PRI.p0, '45m', '');

make('feat(foundation): UserProfileStore actor — Keychain JSON encode/decode',
  LBL_F0+',type:infra', `## Özet
\`UserProfileStore\` Swift actor. \`save(_ p: UserProfile)\`, \`load() -> UserProfile\`. JSON → Keychain. PII UserDefaults'a gitmiyor.

## İlgili Dosyalar
- \`Data/Keychain/UserProfileStore.swift\`

## Tahmini Süre
**Uygulama:** ~30dk

## Doğrulama Checklist
- [ ] **Local Storage** — save→load round-trip; PII UserDefaults'ta yok
`, '1', EPIC.foundation, PRI.p0, '30m', '#keychainstore');

make('feat(foundation): DependencyContainer protocol + LiveDependencyContainer',
  LBL_F0+',type:infra', `## Özet
\`DependencyContainer\` protocol: contactStore, scanFlow, permissionCoordinator, userProfileStore, calendarService. \`LiveDependencyContainer: ObservableObject\` — tüm servisleri init'te oluşturuyor. \`MockDependencyContainer\` test için.

## Beklened Davranış
Herhangi bir ViewModel \`MockDependencyContainer\` ile init → unit test çalışıyor.

## İlgili Dosyalar
- \`App/DependencyContainer.swift\`
- \`Tests/Mocks/MockDependencyContainer.swift\`

## Tahmini Süre
**Uygulama:** ~30dk
`, '1', EPIC.foundation, PRI.p0, '30m', '#contactstore,#userprofilestore');

make('feat(foundation): AppRoute enum — tüm ekran case\'leri, Hashable',
  LBL_F0+',type:feat', `## Özet
\`enum AppRoute: Hashable\` — onboarding, profileSetup, home, contacts, camera, confirm, duplicate(contactID:UUID), eventMatch(contactID:UUID), detail(contactID:UUID), contactEdit(contactID:UUID), mailCompose(contactID:UUID?), templates, profile, settings, privacyPolicy.

## Beklened Davranış
Typo → compile error. Associated value ile \`Hashable\` uyumu — UUID Hashable.

## İlgili Dosyalar
- \`UI/Navigation/AppRoute.swift\`

## Tahmini Süre
**Uygulama:** ~20dk
`, '1', EPIC.foundation, PRI.p0, '20m', '');

make('feat(foundation): RootNavigationView — NavigationStack<[AppRoute]>',
  LBL_F0+',type:feat', `## Özet
\`NavigationStack(path: \$path)\` + \`.navigationDestination(for: AppRoute.self)\`. TabView: Contacts / Home / Profile. onAppear'da onboarding kontrolü.

## İlgili Dosyalar
- \`UI/Navigation/RootNavigationView.swift\`

## Tahmini Süre
**Uygulama:** ~30dk

## Doğrulama Checklist
- [ ] **Navigation** — Her AppRoute case bir view'a map ediliyor; tab bar çalışıyor
`, '1', EPIC.foundation, PRI.p0, '30m', '#approute');

make('feat(foundation): PermissionCoordinator — kamera izni',
  LBL_F0+',type:feat', `## Özet
\`requestCamera() async -> PermResult\`. AVCaptureDevice.authorizationStatus kontrolü. notDetermined → requestAccess. permanentlyDenied → Settings yönlendirme.

## İlgili Dosyalar
- \`Data/Permissions/PermissionCoordinator.swift\`

## Tahmini Süre
**Uygulama:** ~30dk

## Doğrulama Checklist
- [ ] **Permissions** — permanentlyDenied sonrası requestAccess çağrılmıyor
`, '1', EPIC.foundation, PRI.p0, '30m', '');

make('feat(foundation): PermissionCoordinator — rehber ve takvim izni',
  LBL_F0+',type:feat', `## Özet
\`requestContacts()\`, \`requestCalendar()\`. CNContactStore + EKEventStore authorization. Denial @AppStorage sayacı. \`openSettings()\` helper.

## İlgili Dosyalar
- \`Data/Permissions/PermissionCoordinator.swift\`
- \`UI/Components/PermissionRationaleSheet.swift\`

## Tahmini Süre
**Uygulama:** ~30dk
`, '1', EPIC.foundation, PRI.p0, '30m', '#permcoord-camera');

make('feat(foundation): OnboardingView — 3 sayfalık TabView(.page)',
  LBL_F0+',type:feat', `## Özet
3 sayfa: Hoş Geldin / Nasıl Çalışır / KVKK. Son sayfada Toggle — onaylanmadan "Başla" butonu disabled. \`onboarding_done\` ve \`privacy_accepted\` @AppStorage'a yazılıyor.

## İlgili Dosyalar
- \`UI/Onboarding/OnboardingView.swift\`

## Tahmini Süre
**Uygulama:** ~45dk

## Doğrulama Checklist
- [ ] **Navigation** — 3. sayfada checkbox onaylanmadan ilerlenemiyor
`, '1', EPIC.foundation, PRI.p0, '45m', '#rootnav');

make('feat(foundation): ProfileSetupView — ilk kez profil oluşturma',
  LBL_F0+',type:feat', `## Özet
Ad, soyad, şirket, ünvan, e-posta form. Kaydet → \`UserProfileStore.save()\`. Zorunlu alan boşsa Kaydet disabled.

## İlgili Dosyalar
- \`UI/ProfileSetup/ProfileSetupView.swift\`
- \`UI/ProfileSetup/ProfileSetupViewModel.swift\`

## Tahmini Süre
**Uygulama:** ~30dk
`, '1', EPIC.foundation, PRI.p0, '30m', '#userprofilestore,#rootnav');

make('feat(foundation): HomeView — boş state, tab bar, kamera CTA',
  LBL_F0+',type:feat', `## Özet
Boş state illustration + "İlk kartı tara" CTA butonu → CameraView. Tab bar: Kişiler / Ana Sayfa / Profil. ScreenshotProtectionModifier uygulanıyor.

## İlgili Dosyalar
- \`UI/Home/HomeView.swift\`

## Tahmini Süre
**Uygulama:** ~30dk
`, '1', EPIC.foundation, PRI.p0, '30m', '#rootnav,#screenshotprotect');

make('feat(foundation): ScreenshotProtectionModifier — inactive overlay',
  LBL_F0+',type:feat', `## Özet
\`scenePhase == .inactive\` → \`Color.black.ignoresSafeArea()\` overlay. RootNavigationView'e \`.modifier(ScreenshotProtectionModifier())\` uygulanıyor. App switcher thumbnail'da içerik görünmüyor.

## İlgili Dosyalar
- \`Security/ScreenshotProtection.swift\`

## Tahmini Süre
**Uygulama:** ~20dk
`, '1', EPIC.foundation, PRI.p0, '20m', '');

console.log('✓ Epic 0 granüler issue\'lar tamamlandı');

// ─── STEP 4: Epic 1 — OCR Pipeline splits ────────────────────────────────────
console.log('\n▶ Epic 1 — OCR Pipeline splits...');
const LBL_F1 = 'epic:1-ocr,ios';

// #11 CameraView (6h) → 5 issue
make('feat(ocr): AVCaptureSession setup — preview layer + session config',
  LBL_F1+',type:feat', `## Özet
\`AVCaptureSession\` konfigürasyonu: \`.photo\` preset, \`AVCaptureVideoPreviewLayer\`, arka kamera default. UIViewRepresentable wrapper.

## İlgili Dosyalar
- \`UI/Camera/CameraPreviewView.swift\`

## Tahmini Süre
**Uygulama:** ~30dk
`, '2', EPIC.ocr, PRI.p0, '30m', '#permcoord-camera');

make('feat(ocr): CardCaptureView — ön/arka fotoğraf çekimi, "---" merge',
  LBL_F1+',type:feat', `## Özet
1. fotoğraf → "Arka yüzü tara" prompt → 2. fotoğraf. İkisi "---" separator ile merge. ScanFlowActor.setPhotoPaths([]) kaydı. Galeri PhotosPicker alternatifi.

## İlgili Dosyalar
- \`UI/Camera/CardCaptureView.swift\`
- \`UI/Camera/CameraViewModel.swift\`

## Tahmini Süre
**Uygulama:** ~45dk
`, '2', EPIC.ocr, PRI.p0, '45m', '#avcapture');

make('feat(ocr): DataScannerView — QR mod, UIViewControllerRepresentable',
  LBL_F1+',type:feat', `## Özet
\`DataScannerViewController\` wrapper. \`.barcode(symbologies: [.qr])\`. Tespit edilen string callback → CameraViewModel. Non-vCard → \`.alert\`.

## İlgili Dosyalar
- \`UI/Camera/DataScannerView.swift\`

## Tahmini Süre
**Uygulama:** ~30dk
`, '2', EPIC.ocr, PRI.p0, '30m', '#permcoord-camera');

make('feat(ocr): CameraView — mod switch (card/QR), permission gate, galeri',
  LBL_F1+',type:feat', `## Özet
CardCaptureView / DataScannerView mod toggle. İzin yoksa PermissionRationaleSheet. Üst toolbar: galeri + mod switch butonu.

## İlgili Dosyalar
- \`UI/Camera/CameraView.swift\`

## Tahmini Süre
**Uygulama:** ~30dk
`, '2', EPIC.ocr, PRI.p0, '30m', '#cardcapture,#datascanner');

// #13 CardParser (5h) → 4 issue
make('feat(ocr): CardParser — isim, ünvan, şirket regex',
  LBL_F1+',type:feat', `## Özet
NSRegularExpression: firstName/lastName (düz ve ters SOYAD Ad), company suffix (A.Ş./Ltd./Inc.), title. Türkçe Unicode-aware pattern'ler.

## İlgili Dosyalar
- \`Domain/OCR/CardParser.swift\`

## Tahmini Süre
**Uygulama:** ~45dk
`, '2', EPIC.ocr, PRI.p0, '45m', '');

make('feat(ocr): CardParser — telefon, e-posta, faks hariç',
  LBL_F1+',type:feat', `## Özet
Telefon regex: +90, 0xxx, dahili. Faks satırı tanıma ve hariç bırakma. E-posta RFC 5321 pattern. max 3 telefon, max 3 e-posta (\`FieldLimits\`).

## İlgili Dosyalar
- \`Domain/OCR/CardParser.swift\`

## Tahmini Süre
**Uygulama:** ~30dk
`, '2', EPIC.ocr, PRI.p0, '30m', '#cardparser-name');

make('feat(ocr): CardParser — LinkedIn, website, adres normalizasyonu',
  LBL_F1+',type:feat', `## Özet
linkedin.com/in/xxx pattern. URLValidator.normalizeLinkedIn. Web sitesi (http/https). Kalan satırlar → adres concat.

## İlgili Dosyalar
- \`Domain/OCR/CardParser.swift\`
- \`Domain/Validation/URLValidator.swift\`

## Tahmini Süre
**Uygulama:** ~30dk
`, '2', EPIC.ocr, PRI.p0, '30m', '#cardparser-phone');

make('test(ocr): CardParserTests — 42 Android test case port',
  LBL_F1+',type:test', `## Özet
Android \`CardParserTest.kt\`'deki 42 case birebir Swift. İsim, telefon, faks hariç, ters isim, clamp, Türkçe karakter, boş input testleri.

## İlgili Dosyalar
- \`Tests/Unit/CardParserTests.swift\`

## Tahmini Süre
**Uygulama:** ~45dk
`, '2', EPIC.ocr, PRI.p1, '45m', '#cardparser-linkedin');

// #14 VCardParser → 3 issue
make('feat(ocr): VCardParser — RFC 6350 unfold + field extraction',
  LBL_F1+',type:feat', `## Özet
RFC 6350 line unfolding (CRLF + whitespace). FN, N, ORG, TITLE, TEL, EMAIL, ADR, URL, NOTE parse. ParseSource enum: .file(URL) ve .string(String) aynı kod path'i.

## İlgili Dosyalar
- \`Domain/VCard/VCardParser.swift\`

## Tahmini Süre
**Uygulama:** ~45dk
`, '2', EPIC.ocr, PRI.p0, '45m', '');

make('feat(ocr): URLValidator — LinkedIn domain whitelist, URL sanitize',
  LBL_F1+',type:feat', `## Özet
\`validateLinkedIn(url:)\`: linkedin.com veya www.linkedin.com domain kontrolü. \`sanitizeURL()\`: scheme prefix garantisi. evil.com → nil dönüyor (Cat-4 fix).

## İlgili Dosyalar
- \`Domain/Validation/URLValidator.swift\`
- \`Tests/Unit/URLValidatorTests.swift\`

## Tahmini Süre
**Uygulama:** ~30dk
`, '2', EPIC.ocr, PRI.p0, '30m', '');

make('test(ocr): VCardParserTests + URLValidatorTests',
  LBL_F1+',type:test', `## Özet
VCardParser: RFC 6350 unfold, UTF-8 encoding, boyut limiti (16384 byte), malformed vCard. URLValidator: evil.com red, geçerli linkedin.com kabul, scheme prefix.

## İlgili Dosyalar
- \`Tests/Unit/VCardParserTests.swift\`
- \`Tests/Unit/URLValidatorTests.swift\`

## Tahmini Süre
**Uygulama:** ~30dk
`, '2', EPIC.ocr, PRI.p1, '30m', '#vcardparser,#urlvalidator');

// #15 ConfirmView → 4 issue
make('feat(ocr): ConfirmView UI — fotoğraf TabView, form layout, QR banner',
  LBL_F1+',type:feat', `## Özet
Üst: fotoğraf TabView pager (ScanFlowActor.photoPaths). Alt: form alanları scroll. QR kaynak → sarı banner. Toolbar: "Yeniden Çek" + "Kaydet".

## İlgili Dosyalar
- \`UI/Confirm/ConfirmView.swift\`

## Tahmini Süre
**Uygulama:** ~45dk
`, '2', EPIC.ocr, PRI.p0, '45m', '#cameraview');

make('feat(ocr): ConfirmViewModel — parsedCard yükleme, kaydet, @SceneStorage draft',
  LBL_F1+',type:feat', `## Özet
\`ScanFlowActor.parsedCard\` → form state. \`save()\`: Contact init (FieldLimits), ContactStore.insert. \`@SceneStorage\` ile draft — process kill sonrası form korunuyor (Cat-3 fix).

## İlgili Dosyalar
- \`UI/Confirm/ConfirmViewModel.swift\`

## Tahmini Süre
**Uygulama:** ~45dk
`, '2', EPIC.ocr, PRI.p0, '45m', '#confirmview-ui,#contactstore');

make('feat(ocr): PhoneEmailRowView — dinamik satır ekle/sil',
  LBL_F1+',type:feat', `## Özet
Telefon ve e-posta için dinamik ForEach satırları. "+" ile yeni satır (FieldLimits.maxPhones=3'e kadar). Swipe-to-delete. Keyboard type: .phonePad / .emailAddress.

## İlgili Dosyalar
- \`UI/Components/PhoneEmailRowView.swift\`

## Tahmini Süre
**Uygulama:** ~30dk
`, '2', EPIC.ocr, PRI.p0, '30m', '');

console.log('✓ Epic 1 splits tamamlandı');

// ─── STEP 5: Epic 2 — Contact Storage splits ──────────────────────────────────
console.log('\n▶ Epic 2 — Contact Storage splits...');
const LBL_F2 = 'epic:2-storage,ios';

// #20 ContactsView → 4 issue
make('feat(storage): ContactsView — List, InitialsAvatar, row layout',
  LBL_F2+',type:feat', `## Özet
\`List\` render. InitialsAvatarView (isim baş harfleri, deterministik renk). Row: avatar + ad + şirket + son tarih. AsyncStream ile ContactStore live update.

## İlgili Dosyalar
- \`UI/Contacts/ContactsView.swift\`
- \`UI/Components/InitialsAvatarView.swift\`

## Tahmini Süre
**Uygulama:** ~30dk
`, '3', EPIC.storage, PRI.p0, '30m', '#contactstore');

make('feat(storage): ContactsView — searchable + 200ms debounce',
  LBL_F2+',type:feat', `## Özet
\`.searchable(text: \$query)\` modifier. \`Task\` içinde 200ms \`sleep\` debounce. Arama in-memory: isim + şirket + e-posta \`.localizedCaseInsensitiveContains\`.

## İlgili Dosyalar
- \`UI/Contacts/ContactsViewModel.swift\`

## Tahmini Süre
**Uygulama:** ~20dk
`, '3', EPIC.storage, PRI.p0, '20m', '#contactsview-list');

make('feat(storage): ContactsView — swipeActions (sil onay, LinkedIn/mail)',
  LBL_F2+',type:feat', `## Özet
Sola: destructive "Sil" → confirmationDialog. Sağa: LinkedIn varsa Safari, yoksa MailCompose. Silme: ContactStore.delete + CNContactStore + ICS dosyası (#133 fix).

## İlgili Dosyalar
- \`UI/Contacts/ContactsView.swift\`

## Tahmini Süre
**Uygulama:** ~30dk
`, '3', EPIC.storage, PRI.p0, '30m', '#contactsview-search');

// #21 DetailView → 3 issue
make('feat(storage): DetailView UI — tappable fields, fotoğraf TabView',
  LBL_F2+',type:feat', `## Özet
Fotoğraf TabView. Tıklanabilir: telefon (tel://), e-posta (mailto:), adres (maps://). URLValidator sonrası LinkedIn openURL. Sections: İletişim / Profesyonel / Not.

## İlgili Dosyalar
- \`UI/Detail/DetailView.swift\`

## Tahmini Süre
**Uygulama:** ~30dk
`, '3', EPIC.storage, PRI.p0, '30m', '#contactsview-swipe');

make('feat(storage): DetailView — vCard export + Rehbere Ekle',
  LBL_F2+',type:feat', `## Özet
vCard üretimi (RFC 6350, UTF-8, PHOTO;ENCODING=BASE64). UIActivityViewController ile paylaşım. "Rehbere Ekle" → WRITE_CONTACTS izin → CNContactStore.

## İlgili Dosyalar
- \`UI/Detail/DetailViewModel.swift\`
- \`Domain/VCard/VCardExporter.swift\`

## Tahmini Süre
**Uygulama:** ~30dk
`, '3', EPIC.storage, PRI.p0, '30m', '#detailview-ui');

make('feat(storage): DetailViewModel — ContactStore live binding, delete',
  LBL_F2+',type:feat', `## Özet
\`@Published var contact\`: ContactStore'dan canlı okuma. delete: ContactStore + CNContactStore + PhotoStorage + ICS. navigate back on delete.

## İlgili Dosyalar
- \`UI/Detail/DetailViewModel.swift\`

## Tahmini Süre
**Uygulama:** ~20dk
`, '3', EPIC.storage, PRI.p0, '20m', '#detailview-ui');

// #22 ContactEditView → 5 issue
make('feat(storage): ContactEditView UI — form, dinamik satırlar',
  LBL_F2+',type:feat', `## Özet
Mevcut contact'ı düzenleme formu. PhoneEmailRowView yeniden kullanımı. Fotoğraf kamera/galeri değişimi. Toolbar: İptal / Kaydet.

## İlgili Dosyalar
- \`UI/Edit/ContactEditView.swift\`

## Tahmini Süre
**Uygulama:** ~30dk
`, '3', EPIC.storage, PRI.p1, '30m', '#contactsview-list');

make('feat(storage): ContactEditViewModel — validasyon, ContactStore.update',
  LBL_F2+',type:feat', `## Özet
Form state ← Contact. save: FieldLimits validate → ContactStore.update → DeviceContactsService.update. Hata alert.

## İlgili Dosyalar
- \`UI/Edit/ContactEditViewModel.swift\`

## Tahmini Süre
**Uygulama:** ~30dk
`, '3', EPIC.storage, PRI.p1, '30m', '#contacteditview-ui,#contactstore');

make('feat(storage): DeviceContactsService — CNContactStore add/update/delete',
  LBL_F2+',type:feat', `## Özet
\`add(_ contact: Contact)\`: CNMutableContact + CNSaveRequest. \`update\`: delete + re-insert (identifier tracking). \`delete\`. notes alanı ekleniyor (#136 fix). İzin yoksa silently skip.

## İlgili Dosyalar
- \`Data/Contacts/DeviceContactsService.swift\`

## Tahmini Süre
**Uygulama:** ~45dk

## Doğrulama Checklist
- [ ] **Local Storage** — notes alanı Rehber'de görünüyor (#136 fix)
`, '3', EPIC.storage, PRI.p1, '45m', '#permcoord-contacts');

console.log('✓ Epic 2 splits tamamlandı');

// ─── STEP 6: Epic 4 Events split ─────────────────────────────────────────────
console.log('\n▶ Epic 4 — Event Matching split...');

// #29 EventMatchView → 3 issue
make('feat(events): EventMatchView UI — 3 state, pagination, "Daha fazla"',
  'epic:4-events,ios,type:feat', `## Özet
State: aktif etkinlik / bugün listesi / yok. Row: etkinlik adı + saat + konum. "Daha fazla yükle" butonu (getEventsBefore pagination). "Atla" toolbar.

## İlgili Dosyalar
- \`UI/EventMatch/EventMatchView.swift\`

## Tahmini Süre
**Uygulama:** ~30dk
`, '5', EPIC.events, PRI.p1, '30m', '#calendarservice,#duplicateview');

make('feat(events): EventMatchViewModel — seçim, notes append, review trigger',
  'epic:4-events,ios,type:feat', `## Özet
Etkinlik seçimi → contact.eventName güncelleniyor. notes: mevcut + "\\n[Etkinlik: ...]" append (overwrite değil, #134 fix). İlk kayıtta SKStoreReviewController. İzin yoksa view skip (#139 fix).

## İlgili Dosyalar
- \`UI/EventMatch/EventMatchViewModel.swift\`

## Tahmini Süre
**Uygulama:** ~30dk
`, '5', EPIC.events, PRI.p1, '30m', '#eventmatchview-ui');

console.log('✓ Epic 4 split tamamlandı');

// ─── STEP 7: Epic 5 Mail splits ───────────────────────────────────────────────
console.log('\n▶ Epic 5 — Mail + Templates splits...');

// #32 TemplatesView → 4 issue
make('feat(mail): TemplatesView — liste, swipe-to-delete, swipe-to-reset',
  'epic:5-mail,ios,type:feat', `## Özet
List: şablon adı + önizleme. Swipe sol: destructive sil. Swipe sağ: default sıfırla (default ise). Yeni şablon FAB butonu.

## İlgili Dosyalar
- \`UI/Templates/TemplatesView.swift\`
- \`UI/Templates/TemplatesViewModel.swift\`

## Tahmini Süre
**Uygulama:** ~30dk
`, '6', EPIC.mail, PRI.p1, '30m', '#emailtemplate-seed');

make('feat(mail): TemplateEditView UI — TextEditor + token chip scroll',
  'epic:5-mail,ios,type:feat', `## Özet
TextEditor: konu + gövde. Alt toolbar: token chip'leri yatay scroll (Ad, Soyad, Şirket, Etkinlik, Tarih, vb.). Chip tap → cursor pozisyonuna token insert.

## İlgili Dosyalar
- \`UI/Templates/TemplateEditView.swift\`

## Tahmini Süre
**Uygulama:** ~45dk
`, '6', EPIC.mail, PRI.p1, '45m', '#templatesview');

make('feat(mail): TemplateEditViewModel — AttributedString render, CRUD',
  'epic:5-mail,ios,type:feat', `## Özet
Token → AttributedString highlight. save → EmailTemplateStore.insert/update. isim boşsa Kaydet disabled.

## İlgili Dosyalar
- \`UI/Templates/TemplateEditViewModel.swift\`

## Tahmini Süre
**Uygulama:** ~30dk
`, '6', EPIC.mail, PRI.p1, '30m', '#templateeditview-ui');

// #34 MailComposeView → 4 issue
make('feat(mail): MailTemplateResolver — değişken çözümleme, [Etkinlik] boş guard',
  'epic:5-mail,ios,type:feat', `## Özet
Template body'deki \`{Ad}\`, \`{Soyad}\`, \`{Etkinlik}\` vb. token'ları Contact + UserProfile değerleriyle replace. \`{Etkinlik}\` boşken ilgili cümle siliniyor (#116 fix). Eksik değişken → Set<Token> döndürüyor.

## İlgili Dosyalar
- \`Domain/Mail/MailTemplateResolver.swift\`
- \`Tests/Unit/MailTemplateResolverTests.swift\`

## Tahmini Süre
**Uygulama:** ~30dk
`, '6', EPIC.mail, PRI.p1, '30m', '');

make('feat(mail): MailComposeView UI — şablon seçici, önizleme, uyarı banner',
  'epic:5-mail,ios,type:feat', `## Özet
Üst: şablon chip scroll. Orta: çözümlenmiş önizleme. Eksik değişken → turuncu banner. Takvim çakışma → kırmızı highlight. Alt: ICS ekle toggle + Gönder.

## İlgili Dosyalar
- \`UI/Mail/MailComposeView.swift\`

## Tahmini Süre
**Uygulama:** ~30dk
`, '6', EPIC.mail, PRI.p1, '30m', '#templateresolver');

make('feat(mail): MFMailComposeViewController wrapper + ICS attachment',
  'epic:5-mail,ios,type:feat', `## Özet
UIViewControllerRepresentable. konu + gövde set. ICS toggle açıksa \`addAttachmentData\` (UTType.calendarEvent, Cat-10 fix). Dismiss callback.

## İlgili Dosyalar
- \`UI/Mail/MailComposeRepresentable.swift\`

## Tahmini Süre
**Uygulama:** ~30dk
`, '6', EPIC.mail, PRI.p1, '30m', '#mailcomposeview-ui,#icsgenerator');

console.log('✓ Epic 5 splits tamamlandı');

// ─── STEP 8: Epic 6 Profile splits ───────────────────────────────────────────
console.log('\n▶ Epic 6 — Profile + QR splits...');

// #37 ProfileView → 3 issue
make('feat(profile): ProfileView UI — form, avatar, kaydet',
  'epic:6-profile,ios,type:feat', `## Özet
Ad, soyad, şirket, ünvan, e-posta form. Avatar: büyük yuvarlak görsel, tap → PhotosPicker/kamera. Kaydet butonu async (UserProfileStore.save).

## İlgili Dosyalar
- \`UI/Profile/ProfileView.swift\`

## Tahmini Süre
**Uygulama:** ~30dk
`, '7', EPIC.profile, PRI.p1, '30m', '#userprofilestore');

make('feat(profile): ProfileViewModel — load/save, OCR self-scan',
  'epic:6-profile,ios,type:feat', `## Özet
onAppear: UserProfileStore.load(). save: validate → UserProfileStore.save(). OCR self-scan: CameraView → VisionOCRService → CardParser → form alanları dolduruluyor.

## İlgili Dosyalar
- \`UI/Profile/ProfileViewModel.swift\`

## Tahmini Süre
**Uygulama:** ~30dk
`, '7', EPIC.profile, PRI.p1, '30m', '#profileview-ui,#visionocr');

console.log('✓ Epic 6 splits tamamlandı');

// ─── STEP 9: Epic 8 — Release & App Store ────────────────────────────────────
console.log('\n▶ Epic 8 — Release & App Store...');
const LBL_F8 = 'epic:8-release,ios';
const MS = MS8;

make('Epic 8 — Release & App Store', LBL_F8+',epic', `## Özet
App Store'a submit için gereken tüm hazırlıklar: ikonlar, launch screen, screenshots, metadata, TestFlight, versioning, crash reporting. Android'de Play Store sürecinde sonradan uğraşılan konuların iOS karşılığı.

## Android → iOS Karşılaştırma
| Özellik | Android | iOS |
|---|---|---|
| İkonlar | ✅ adaptive-icon | ❌ AppIcon.xcassets (tüm boyutlar + dark/tinted) yapılacak |
| Splash | ✅ SplashActivity | ❌ LaunchScreen yapılacak |
| Beta dağıtım | ✅ Firebase App Distribution | ❌ TestFlight yapılacak |
| Store metadata | ✅ Play Console | ❌ App Store Connect yapılacak |
| Versioning | ✅ versionCode / versionName | ❌ CFBundleVersion / CFBundleShortVersionString yapılacak |
| Crash reporting | ✅ Firebase Crashlytics | ❌ Xcode Organizer / 3rd party yapılacak |

## İlgili Dosyalar
- \`Assets.xcassets/AppIcon.appiconset\`
- \`LaunchScreen.storyboard\`
- \`fastlane/\` veya \`scripts/increment_build.sh\`

## Tahmini Süre
**Uygulama:** ~3 gün
**Review:** ~2 saat

## Doğrulama Checklist (Kapatmadan Önce)
- [ ] **Navigation** — LaunchScreen → Home geçişi pürüzsüz
- [ ] **App Store** — Tüm screenshot boyutları yüklendi; metadata TR+EN
- [ ] **TestFlight** — Build başarıyla yüklendi ve test grubu erişebiliyor
- [ ] **Crash Reporting** — Test crash yakalanıp raporlanıyor
- [ ] **Versioning** — Build number CI'da auto-increment
`, MS, EPIC.release, PRI.p1, '', '');

make('chore(release): App Icons — tüm boyutlar, dark, tinted',
  LBL_F8+',type:chore', `## Özet
AppIcon.xcassets: 1024x1024 (App Store), 60x60@2x/3x, 40x40@2x/3x, 20x20@2x/3x. Dark mode ve tinted varyantlar. Android adaptive-icon'dan türetilecek.

## Beklened Davranış
Xcode build uyarısız. Simulator ve cihazda ikon görünüyor.

## İlgili Dosyalar
- \`Assets.xcassets/AppIcon.appiconset/Contents.json\`

## Tahmini Süre
**Uygulama:** ~30dk
`, MS, EPIC.release, PRI.p0, '30m', '');

make('chore(release): LaunchScreen — splash, brand mark',
  LBL_F8+',type:chore', `## Özet
LaunchScreen.storyboard veya Info.plist bazlı (UILaunchScreen). Marka logosu + arka plan rengi. Dark mode uyumu.

## İlgili Dosyalar
- \`LaunchScreen.storyboard\`

## Tahmini Süre
**Uygulama:** ~20dk
`, MS, EPIC.release, PRI.p0, '20m', '');

make('chore(release): App Store Connect — bundle ID, capabilities, app kaydı',
  LBL_F8+',type:chore', `## Özet
com.veilion.cardconnect bundle ID Apple Dev Portal'da kayıtlı. Capabilities: Keychain Sharing. App Store Connect'te app kaydı oluşturuldu.

## Tahmini Süre
**Uygulama:** ~30dk
`, MS, EPIC.release, PRI.p0, '30m', '');

make('chore(release): Versioning — SemVer + build number auto-increment',
  LBL_F8+',type:chore', `## Özet
\`CFBundleShortVersionString\` = semantic (1.0.0). \`CFBundleVersion\` = CI build counter. \`scripts/increment_build.sh\` veya fastlane \`increment_build_number\`. GitHub Actions'ta otomatik.

## İlgili Dosyalar
- \`scripts/increment_build.sh\`
- \`.github/workflows/build.yml\`

## Tahmini Süre
**Uygulama:** ~30dk
`, MS, EPIC.release, PRI.p1, '30m', '');

make('chore(release): TestFlight Build — GitHub Actions CI pipeline',
  LBL_F8+',type:chore', `## Özet
GitHub Actions: build → test → archive → upload to TestFlight. Secrets: APPLE_CERTIFICATE, PROVISIONING_PROFILE, APP_STORE_CONNECT_API_KEY. Main branch push → otomatik build.

## İlgili Dosyalar
- \`.github/workflows/testflight.yml\`

## Tahmini Süre
**Uygulama:** ~2h
`, MS, EPIC.release, PRI.p1, '2h', '#versioning');

make('chore(release): App Store Screenshots — 6.7", 6.5", 5.5"',
  LBL_F8+',type:chore', `## Özet
Her boyut için 5-6 screenshot: Home, Kart Tarama, Kişi Detay, Mail Compose, QR. Türkçe caption overlay. Simulator screenshot workflow.

## İlgili Dosyalar
- \`fastlane/screenshots/\`

## Tahmini Süre
**Uygulama:** ~1h
`, MS, EPIC.release, PRI.p1, '1h', '#homeview');

make('chore(release): App Store Metadata — TR açıklama, anahtar kelimeler',
  LBL_F8+',type:chore', `## Özet
Türkçe app açıklaması (4000 char), promotional text (170 char), anahtar kelimeler (100 char). App Store Connect'e yükleme veya fastlane deliver.

## Tahmini Süre
**Uygulama:** ~45dk
`, MS, EPIC.release, PRI.p1, '45m', '');

make('chore(release): Privacy Nutrition Labels — PrivacyInfo.xcprivacy tamamlama',
  LBL_F8+',type:chore', `## Özet
PrivacyInfo.xcprivacy: NSFileSystemAPI, NSUserDefaultsAPI beyan. App Store Connect Privacy section: Data Not Collected (ağ yok, 3rd party yok). Export compliance (Keychain AES → EAR exempt).

## İlgili Dosyalar
- \`PrivacyInfo.xcprivacy\`

## Tahmini Süre
**Uygulama:** ~30dk
`, MS, EPIC.release, PRI.p1, '30m', '');

make('chore(release): Crash Reporting — Xcode Organizer + symbolicasyon',
  LBL_F8+',type:chore', `## Özet
dSYM upload GitHub Actions'ta. Xcode Organizer'da crash raporları. Test crash (fatalError) ile doğrulama. İsteğe bağlı: Firebase Crashlytics (network-free build için dikkat).

## Tahmini Süre
**Uygulama:** ~30dk
`, MS, EPIC.release, PRI.p2, '30m', '#testflight-ci');

console.log('✓ Epic 8 tamamlandı');

// ─── STEP 10: UI Tests ────────────────────────────────────────────────────────
console.log('\n▶ UI Tests...');
const LBL_UI = 'type:ui-test,ios';

make('test(ui): Onboarding → ProfileSetup → Home happy path',
  LBL_UI+',epic:0-foundation', `## Özet
XCUITest. App launch → Onboarding 3 sayfa swipe → KVKK toggle on → Başla → ProfileSetup form doldur → Kaydet → Home görünüyor. Crash yok. onboarding_done=true.

## İlgili Dosyalar
- \`Tests/UI/OnboardingUITests.swift\`

## Tahmini Süre
**Uygulama:** ~30dk
`, '1', EPIC.foundation, PRI.p1, '30m', '#homeview,#profilesetupview');

make('test(ui): OCR Happy Path — kamera → confirm → kaydet → liste',
  LBL_UI+',epic:1-ocr', `## Özet
XCUITest. Kamera izni grant (launchArguments). Galeri mock image inject. ConfirmView alanları dolu. Kaydet → ContactsView'de yeni kayıt görünüyor.

## İlgili Dosyalar
- \`Tests/UI/OCRHappyPathUITests.swift\`

## Tahmini Süre
**Uygulama:** ~45dk
`, '2', EPIC.ocr, PRI.p1, '45m', '#confirmviewmodel,#contactsview-list');

make('test(ui): Duplicate Merge Flow — aynı kişiyi tekrar tara → merge',
  LBL_UI+',epic:3-duplicate', `## Özet
ContactStore'da mevcut kişi. Aynı kişiyi tara → DuplicateView görünüyor → "Mevcut Güncelle" → DetailView'de merge edilmiş data. notes kaybolmuyor.

## İlgili Dosyalar
- \`Tests/UI/DuplicateMergeUITests.swift\`

## Tahmini Süre
**Uygulama:** ~30dk
`, '4', EPIC.duplicate, PRI.p1, '30m', '#duplicateview');

make('test(ui): Event Match Flow — takvim izni, etkinlik seç, notes append',
  LBL_UI+',epic:4-events', `## Özet
Takvim izni grant. Kart kaydet → EventMatchView'de bugünkü etkinlik görünüyor. Seç → Contact.notes "\\n[Etkinlik: ...]" içeriyor. Skip → Home.

## İlgili Dosyalar
- \`Tests/UI/EventMatchUITests.swift\`

## Tahmini Süre
**Uygulama:** ~30dk
`, '5', EPIC.events, PRI.p1, '30m', '#eventmatchviewmodel');

make('test(ui): Mail Compose Flow — şablon seç → ICS ekle → gönder',
  LBL_UI+',epic:5-mail', `## Özet
Mevcut kişi. Mail Compose aç. Şablon seç → önizleme doluyor. ICS toggle on. Gönder → MFMailComposeViewController görünüyor (UI test dismiss). [Etkinlik] boşken bozuk metin yok.

## İlgili Dosyalar
- \`Tests/UI/MailComposeUITests.swift\`

## Tahmini Süre
**Uygulama:** ~30dk
`, '6', EPIC.mail, PRI.p1, '30m', '#mailcomposerepresentable');

make('test(ui): Permission denial flows — kamera/rehber permanentlyDenied → Settings',
  LBL_UI+',epic:0-foundation', `## Özet
launchArguments ile permission reddini simüle. CameraView aç → PermissionRationaleSheet görünüyor → "Ayarlara Git" butonu mevcut. Rehber reddi → DeviceContactsService skip, crash yok.

## İlgili Dosyalar
- \`Tests/UI/PermissionDenialUITests.swift\`

## Tahmini Süre
**Uygulama:** ~30dk
`, '1', EPIC.foundation, PRI.p1, '30m', '#permcoord-camera,#permcoord-contacts');

console.log('✓ UI Tests tamamlandı');

console.log(`
============================================================
✅ Refinement tamamlandı!

Kapatılan issue'lar: ${toClose.join(', ')}
Yeni granüler issue'lar + Epic 8 + UI Tests → project'e eklendi.

https://github.com/${REPO}/issues
https://github.com/users/tolgabarisalcitepe/projects/1
============================================================
`);
