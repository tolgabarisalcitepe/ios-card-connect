// TemplateEditView.swift
// CardConnect

import SwiftUI
import SwiftData

struct TemplateEditView: View {

    let templateID: UUID

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = TemplateEditViewModel()
    @Query private var allTemplates: [EmailTemplate]

    @State private var showDiscardAlert = false

    private var template: EmailTemplate? {
        allTemplates.first { $0.id == templateID }
    }

    var body: some View {
        Form {
            Section("Şablon Adı") {
                TextField("Ad", text: $viewModel.name)
            }
            Section("Konu") {
                TextField("Konu", text: $viewModel.subject)
            }
            Section("Gövde") {
                TextEditor(text: $viewModel.body)
                    .frame(minHeight: 180)
            }
        }
        .navigationTitle(template?.name ?? "Şablon Düzenle")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Geri") {
                    if viewModel.isDirty {
                        showDiscardAlert = true
                    } else {
                        dismiss()
                    }
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Kaydet") {
                    if let t = template, viewModel.save(template: t, modelContext: modelContext) {
                        dismiss()
                    }
                }
                .disabled(!viewModel.canSave)
            }
        }
        .task(id: template?.id) {
            if let t = template { viewModel.load(template: t) }
        }
        .alert("Değişiklikler Kaydedilmedi", isPresented: $showDiscardAlert) {
            Button("Değişiklikleri At", role: .destructive) { dismiss() }
            Button("Düzenlemeye Devam Et", role: .cancel) {}
        } message: {
            Text("Yaptığınız değişiklikler kaybolacak.")
        }
        .alert("Hata", isPresented: .init(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("Tamam", role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}
