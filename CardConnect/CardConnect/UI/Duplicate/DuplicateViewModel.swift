import Foundation

@MainActor
final class DuplicateViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?

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
