// CrashReporter.swift
// CardConnect
// MetricKit tabanlı on-device crash/diagnostic toplama — harici servis yok.

import MetricKit
import OSLog

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.cardconnect",
                            category: "CrashReporter")

final class CrashReporter: NSObject, MXMetricManagerSubscriber {

    static let shared = CrashReporter()

    private override init() {}

    func start() {
        MXMetricManager.shared.add(self)
        logger.info("CrashReporter başlatıldı")
    }

    // MARK: - MXMetricManagerSubscriber

    // Haftalık metrik paketi (bellek, CPU, ağ, disk I/O vb.)
    func didReceive(_ payloads: [MXMetricPayload]) {
        for payload in payloads {
            save(data: payload.jsonRepresentation(), prefix: "metrics")
        }
    }

    // Crash / hang / disk-write / CPU exception sonrası çağrılır (iOS 14+)
    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for payload in payloads {
            save(data: payload.jsonRepresentation(), prefix: "diagnostic")
        }
    }

    // MARK: - Private

    private func save(data: Data, prefix: String) {
        let dir = logsDirectory()
        let timestamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let file = dir.appendingPathComponent("\(prefix)-\(timestamp).json")
        do {
            try data.write(to: file, options: .atomic)
            logger.info("Kaydedildi: \(file.lastPathComponent)")
        } catch {
            logger.error("Kayıt hatası [\(prefix)]: \(error)")
        }
    }

    private func logsDirectory() -> URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        )[0]
        let dir = appSupport.appendingPathComponent("crash_logs", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
