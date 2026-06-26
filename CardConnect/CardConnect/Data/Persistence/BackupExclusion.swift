// BackupExclusion.swift
// CardConnect
// Hassas dizinleri iCloud / iTunes yedeklemesinden dışlar.
// @AppStorage onboarding flag'leri kasıtlı olarak yedek kapsamında bırakılır.

import Foundation
import OSLog

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.cardconnect",
                            category: "BackupExclusion")

enum BackupExclusion {

    /// Uygulama açılışında çağrılır; hata backup'ı durdurmaz.
    static func applyAll() {
        excludeDocumentsSubdirectory("photos")
        excludeDocumentsSubdirectory("ics")
        excludeDocumentsSubdirectory("vcf")
        excludeApplicationSupportDirectory()
    }

    // MARK: - Private

    private static func excludeDocumentsSubdirectory(_ name: String) {
        guard let docs = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let dir = docs.appendingPathComponent(name, isDirectory: true)
        createIfNeeded(dir)
        setExcluded(dir)
    }

    private static func excludeApplicationSupportDirectory() {
        guard let appSupport = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        ) else { return }
        let dir = appSupport.appendingPathComponent("CardConnect", isDirectory: true)
        setExcluded(dir)
    }

    private static func createIfNeeded(_ url: URL) {
        guard !FileManager.default.fileExists(atPath: url.path) else { return }
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    private static func setExcluded(_ url: URL) {
        var mutable = url
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        do {
            try mutable.setResourceValues(values)
        } catch {
            logger.error("isExcludedFromBackup set edilemedi [\(url.lastPathComponent)]: \(error)")
        }
    }
}
