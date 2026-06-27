// TemplateEditViewModel.swift
// CardConnect

import Combine
import Foundation
import SwiftData

@MainActor final class TemplateEditViewModel: ObservableObject {

    @Published var name: String = ""
    @Published var subject: String = ""
    @Published var body: String = ""
    @Published var errorMessage: String?

    private var originalName = ""
    private var originalSubject = ""
    private var originalBody = ""
    private var isLoaded = false

    var isDirty: Bool {
        name != originalName || subject != originalSubject || body != originalBody
    }

    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && isDirty
    }

    func load(template: EmailTemplate) {
        guard !isLoaded else { return }
        isLoaded = true
        name = template.name
        subject = template.subject
        body = template.body
        originalName = template.name
        originalSubject = template.subject
        originalBody = template.body
    }

    /// Kaydeder ve başarıyı Bool olarak döner.
    func save(template: EmailTemplate, modelContext: ModelContext) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            errorMessage = "Şablon adı boş olamaz."
            return false
        }
        template.name = trimmed
        template.subject = subject
        template.body = body
        do {
            try modelContext.save()
            originalName = trimmed
            originalSubject = subject
            originalBody = body
            return true
        } catch {
            errorMessage = "Şablon kaydedilemedi."
            return false
        }
    }
}
