// TemplatesView.swift
// CardConnect

import Combine
import SwiftUI
import SwiftData

struct TemplatesView: View {

    @Query(sort: \EmailTemplate.sortOrder) private var templates: [EmailTemplate]
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = TemplatesViewModel()

    @State private var templateToReset: EmailTemplate?
    @State private var templateToDelete: EmailTemplate?

    var body: some View {
        Group {
            if templates.isEmpty {
                ContentUnavailableView(
                    "Şablon Yok",
                    systemImage: "doc.text",
                    description: Text("Henüz e-posta şablonu eklenmemiş.")
                )
            } else {
                List(templates) { template in
                    NavigationLink(value: AppRoute.templateEdit(templateID: template.id)) {
                        TemplateRowView(template: template)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if template.isDefault {
                            Button {
                                templateToReset = template
                            } label: {
                                Label("Sıfırla", systemImage: "arrow.counterclockwise")
                            }
                            .tint(.orange)
                        } else {
                            Button(role: .destructive) {
                                templateToDelete = template
                            } label: {
                                Label("Sil", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Şablonlar")
        .navigationBarTitleDisplayMode(.large)
        .alert("Şablonu Sıfırla", isPresented: .init(
            get: { templateToReset != nil },
            set: { if !$0 { templateToReset = nil } }
        )) {
            Button("Sıfırla", role: .destructive) {
                if let t = templateToReset {
                    viewModel.resetTemplate(t, modelContext: modelContext)
                }
                templateToReset = nil
            }
            Button("İptal", role: .cancel) { templateToReset = nil }
        } message: {
            Text("Şablon orijinal içeriğine döndürülecek. Bu işlem geri alınamaz.")
        }
        .alert("Şablonu Sil", isPresented: .init(
            get: { templateToDelete != nil },
            set: { if !$0 { templateToDelete = nil } }
        )) {
            Button("Sil", role: .destructive) {
                if let t = templateToDelete {
                    viewModel.deleteTemplate(t, modelContext: modelContext)
                }
                templateToDelete = nil
            }
            Button("İptal", role: .cancel) { templateToDelete = nil }
        } message: {
            Text("Bu şablon kalıcı olarak silinecek.")
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

// MARK: - TemplateRowView

private struct TemplateRowView: View {
    let template: EmailTemplate

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: template.iconName)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 32, alignment: .center)

            VStack(alignment: .leading, spacing: 4) {
                Text(template.name)
                    .font(.body.weight(.medium))

                TemplateVariableChipView(text: template.body)
            }
        }
        .padding(.vertical, 4)
    }
}
