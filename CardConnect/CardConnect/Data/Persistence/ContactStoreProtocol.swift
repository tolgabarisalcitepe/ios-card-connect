import Foundation

/// Kişi depolama katmanı için sözleşme.
/// SwiftData implementasyonu Epic 2 #89'da sağlanacak.
protocol ContactStoreProtocol {

    /// Yeni kişi ekler.
    func insert(_ contact: Contact) throws

    /// Mevcut kişiyi günceller.
    func update(_ contact: Contact) throws

    /// Verilen id'ye sahip kişiyi siler.
    func delete(id: UUID) throws

    /// Tüm kişileri `updatedAt` azalan sırada döner.
    func fetchAll() throws -> [Contact]

    /// Verilen id'ye sahip kişiyi döner; bulunamazsa nil.
    func fetchById(_ id: UUID) throws -> Contact?

    /// `query` ifadesini ad, soyad, şirket, telefon ve e-posta alanlarında Swift-side filtreler.
    func search(query: String) throws -> [Contact]

    /// Duplikat kontrolü — Swift-side eşleştirme; `#Predicate`/`LIKE` kullanılmaz.
    /// Eşleşme önceliği: (1) name+company → (2) phone → (3) email.
    func findDuplicate(
        firstName: String,
        lastName: String,
        company: String,
        phones: [String],
        emails: [String]
    ) throws -> Contact?
}
