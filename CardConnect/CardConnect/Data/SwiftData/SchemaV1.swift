// SchemaV1.swift
// CardConnect

import SwiftData

enum SchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            Contact.self,
            EmailTemplate.self
        ]
    }
}
