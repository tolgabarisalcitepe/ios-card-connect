// EmailTemplateSeeder.swift
// CardConnect

import Foundation
import SwiftData

enum EmailTemplateSeeder {

    // MARK: - TemplateDefault (shared reset kaynak)

    struct TemplateDefault {
        let id: UUID
        let name: String
        let iconName: String
        let subject: String
        let body: String
        let sortOrder: Int
    }

    // swiftlint:disable force_unwrapping
    static let defaults: [TemplateDefault] = [
        TemplateDefault(
            id: UUID(uuidString: "11111111-0000-0000-0000-000000000001")!,
            name: "Tanışma",
            iconName: "hand.wave",
            subject: "[Etkinlik] - Merhaba!",
            body: """
            Merhaba [Ad],

            [Etkinlik]'te tanışmak çok güzeldi. Umarım yakında tekrar görüşürüz.

            Saygılarımla,
            [Benim Adım]
            [Ünvanım] · [Şirketim]
            """,
            sortOrder: 0
        ),
        TemplateDefault(
            id: UUID(uuidString: "11111111-0000-0000-0000-000000000002")!,
            name: "İş Birliği",
            iconName: "person.2",
            subject: "İş Birliği Teklifi",
            body: """
            Merhaba [Ad],

            [Etkinlik]'te iş birliği fikirlerimizi paylaşmak güzeldi. Ortak projeler üzerine daha detaylı konuşmak ister misiniz?

            Saygılarımla,
            [Benim Adım]
            [Ünvanım] · [Şirketim]
            """,
            sortOrder: 1
        ),
        TemplateDefault(
            id: UUID(uuidString: "11111111-0000-0000-0000-000000000003")!,
            name: "Bilgi Talebi",
            iconName: "questionmark.circle",
            subject: "Bilgi Talebi",
            body: """
            Merhaba [Ad],

            [Etkinlik]'te bahsettiğiniz konular hakkında daha fazla bilgi almak istiyorum. Uygun olduğunuzda konuşabilir miyiz?

            Saygılarımla,
            [Benim Adım]
            [Ünvanım] · [Şirketim]
            """,
            sortOrder: 2
        ),
        TemplateDefault(
            id: UUID(uuidString: "11111111-0000-0000-0000-000000000004")!,
            name: "Takip",
            iconName: "arrow.clockwise",
            subject: "[Etkinlik] - Takip",
            body: """
            Merhaba [Ad],

            [Etkinlik]'ten bu yana iletişimi sürdürmek istedim. Nasıl devam edelim?

            Saygılarımla,
            [Benim Adım]
            [Ünvanım] · [Şirketim]
            """,
            sortOrder: 3
        ),
        TemplateDefault(
            id: UUID(uuidString: "11111111-0000-0000-0000-000000000005")!,
            name: "Toplantı",
            iconName: "calendar",
            subject: "Toplantı Teklifi",
            body: """
            Merhaba [Ad],

            Kısa bir görüşme ayarlamak mümkün olur mu? Size uygun bir zaman önerir misiniz?

            Saygılarımla,
            [Benim Adım]
            [Ünvanım] · [Şirketim]
            """,
            sortOrder: 4
        ),
    ]
    // swiftlint:enable force_unwrapping

    // MARK: - API

    /// COUNT > 0 ise no-op; ilk çalışmada 5 varsayılan şablon ekler.
    static func seedIfEmpty(in context: ModelContext) {
        let count = (try? context.fetchCount(FetchDescriptor<EmailTemplate>())) ?? 0
        guard count == 0 else { return }
        for d in defaults {
            context.insert(EmailTemplate(
                id: d.id,
                name: d.name,
                iconName: d.iconName,
                subject: d.subject,
                body: d.body,
                isDefault: true,
                sortOrder: d.sortOrder
            ))
        }
        try? context.save()
    }

    /// isDefault şablon için orijinal içeriği döner.
    static func original(for id: UUID) -> TemplateDefault? {
        defaults.first { $0.id == id }
    }
}
