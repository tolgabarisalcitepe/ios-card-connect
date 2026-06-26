import Foundation
import SwiftUI

@MainActor
final class DuplicateViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?

    // MARK: - checkDuplicate

    /// Kaydedilmeden önce duplikat kontrolü yapar.
    /// Eşleşme bulunursa `.duplicate(contactID:)` route'a push eder.
    /// ContactStore Epic 2'de inject edilecek — şimdilik stub.
    /// Bug #138: NavigationPath üzerinden geri dönüş sağlanır.
    func checkDuplicate(
        incoming: Contact,
        candidates: [Contact],   // TODO: Epic 2 — contactStore.allContacts
        navigationPath: Binding<[AppRoute]>
    ) {
        guard !candidates.isEmpty else { return }
        if let match = DuplicateDetector.findDuplicate(incoming: incoming, in: candidates) {
            navigationPath.wrappedValue.append(.duplicate(contactID: match.id))
        }
        // No match → caller continues with save
    }

    /// Bug #138: Duplikat ekranından geri döner.
    func goBack(navigationPath: Binding<[AppRoute]>) {
        guard !navigationPath.wrappedValue.isEmpty else { return }
        navigationPath.wrappedValue.removeLast()
    }

    // MARK: - merge

    /// Mevcut kaydı gelen verilerle birleştirir.
    /// DB güncelleme Epic 2'de tamamlanacak.
    @discardableResult
    func mergeAndContinue(
        existing: Contact,
        incoming: Contact,
        scanFlow: ScanFlowActor
    ) async -> Bool {
        isLoading = true
        defer { isLoading = false }
        _ = DuplicateDetector.merge(existing: existing, incoming: incoming)
        // TODO: Epic 2 — await contactStore.update(existing)
        // TODO: Epic 2 — await contactStore.delete(incoming)
        await scanFlow.reset()
        return true
    }

    /// Duplikatı görmezden gelir, yeni kayıt olarak devam eder.
    /// DB insert Epic 2'de tamamlanacak.
    @discardableResult
    func continueAsNew(scanFlow: ScanFlowActor) async -> Bool {
        isLoading = true
        defer { isLoading = false }
        // TODO: Epic 2 — await contactStore.insert(incoming)
        await scanFlow.reset()
        return true
    }
}
