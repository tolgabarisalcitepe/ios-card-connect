// TemplatesView.swift
// CardConnect

import SwiftUI
import SwiftData

struct TemplatesView: View {

    @Query(sort: \EmailTemplate.sortOrder) private var templates: [EmailTemplate]

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
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Şablonlar")
        .navigationBarTitleDisplayMode(.large)
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
