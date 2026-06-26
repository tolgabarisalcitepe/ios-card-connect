// PhotoStorage.swift
// CardConnect
// Disk dosyası temizleme yardımcısı: fotoğraflar + ICS temp dosyası.

import Foundation
import OSLog

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.cardconnect",
                            category: "PhotoStorage")

enum PhotoStorage {

    /// Contact'a ait tüm disk dosyalarını siler: OCR fotoğrafları + ICS davet dosyası.
    static func deleteFiles(for contact: Contact) {
        deletePhotos(paths: contact.photoPaths)
        deleteICS(contactID: contact.id)
    }

    /// Verilen path listesindeki dosyaları siler (ConfirmViewModel iptal akışı için).
    static func deletePhotos(paths: [String]) {
        for path in paths where !path.isEmpty {
            do {
                try FileManager.default.removeItem(atPath: path)
            } catch {
                logger.debug("Fotoğraf silinemedi [\(path)]: \(error)")
            }
        }
    }

    /// MailComposeViewModel'ın yazdığı temp ICS dosyasını siler.
    static func deleteICS(contactID: UUID) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("invite-\(contactID).ics")
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            logger.debug("ICS silinemedi [\(contactID)]: \(error)")
        }
    }
}
