// PrivacyPolicyView.swift
// CardConnect

import SwiftUI

struct PrivacyPolicyView: View {

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ForEach(sections, id: \.title) { section in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(section.title)
                            .font(.headline)
                        Text(section.body)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(24)
        }
        .navigationTitle("Gizlilik Politikası")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Content

    private struct Section {
        let title: String
        let body: String
    }

    private let sections: [Section] = [
        Section(
            title: "1. Veri Sorumlusu",
            body: "6698 sayılı Kişisel Verilerin Korunması Kanunu (KVKK) kapsamında veri sorumlusu sıfatını taşıyan CardConnect uygulaması, kişisel verilerinizi aşağıda açıklanan amaç ve yöntemlerle işlemektedir."
        ),
        Section(
            title: "2. Toplanan Veriler",
            body: "Uygulama; kartvizit tarama yoluyla elde edilen ad, soyad, şirket, unvan, telefon, e-posta ve adres bilgilerini yalnızca cihazınızda saklar. Profil oluşturma sürecinde girdiğiniz kişisel bilgiler ve avatar fotoğrafı da cihaz dışına çıkarılmaz."
        ),
        Section(
            title: "3. Verilerin İşlenme Amacı",
            body: "Toplanan veriler; kişi yönetimi, takip e-postası gönderimi ve takvim etkinliği eşleştirmesi amaçlarıyla kullanılır. Veriler reklam, profil oluşturma veya üçüncü taraf paylaşımı amacıyla kullanılmaz."
        ),
        Section(
            title: "4. Verilerin Saklanması",
            body: "Tüm veriler yalnızca cihazınızda şifreli olarak saklanır (SwiftData + Keychain). iCloud yedeklemesi devre dışıdır; kartvizit fotoğrafları, ICS dosyaları ve kişi veritabanı iCloud Drive'a aktarılmaz."
        ),
        Section(
            title: "5. Üçüncü Taraf Paylaşımı",
            body: "Kişisel verileriniz hiçbir üçüncü tarafla paylaşılmaz, satılmaz veya kiralanmaz. Uygulama herhangi bir analitik SDK veya reklam kütüphanesi içermez."
        ),
        Section(
            title: "6. KVKK Kapsamındaki Haklarınız",
            body: "KVKK'nın 11. maddesi uyarınca verilerinize erişme, düzeltme, silme ve işlenmesine itiraz etme haklarına sahipsiniz. Bu hakları kullanmak için uygulama ayarlarından tüm verileri silebilirsiniz."
        ),
        Section(
            title: "7. Değişiklikler",
            body: "Bu politika zaman zaman güncellenebilir. Önemli değişikliklerde uygulama içi bildirim yapılacaktır. Güncel politika her zaman uygulama içinden erişilebilir."
        ),
        Section(
            title: "8. İletişim",
            body: "Gizlilik politikamıza ilişkin sorularınız için uygulama destek kanallarını kullanabilirsiniz."
        ),
    ]
}
