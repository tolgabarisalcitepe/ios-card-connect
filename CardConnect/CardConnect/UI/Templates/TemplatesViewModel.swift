// TemplatesViewModel.swift
// CardConnect

import Foundation
import SwiftData

@MainActor final class TemplatesViewModel: ObservableObject {

    @Published var errorMessage: String?

    func resetTemplate(_ template: EmailTemplate, modelContext: ModelContext) {
        guard let original = EmailTemplateSeeder.original(for: template.id) else { return }
        template.name = original.name
        template.iconName = original.iconName
        template.subject = original.subject
        template.body = original.body
        do {
            try modelContext.save()
        } catch {
            errorMessage = "Şablon sıfırlanamadı."
        }
    }

    func deleteTemplate(_ template: EmailTemplate, modelContext: ModelContext) {
        modelContext.delete(template)
        do {
            try modelContext.save()
        } catch {
            errorMessage = "Şablon silinemedi."
        }
    }
}
