// JailbreakDetector.swift
// CardConnect

import Foundation
import UIKit

enum JailbreakDetector {

#if targetEnvironment(simulator)
    static var isJailbroken: Bool { false }
#else
    static var isJailbroken: Bool {
        checkSuspiciousFiles() || checkSandboxWrite() || checkSuspiciousSchemes()
    }

    // MARK: - Checks

    private static let suspiciousFiles: [String] = [
        "/Applications/Cydia.app",
        "/Library/MobileSubstrate/MobileSubstrate.dylib",
        "/bin/bash",
        "/usr/sbin/sshd",
        "/etc/apt",
        "/private/var/lib/apt/",
        "/private/var/lib/cydia",
        "/private/var/stash",
        "/private/var/mobile/Library/SBSettings/Themes",
        "/usr/libexec/sftp-server",
        "/usr/bin/sshd",
    ]

    private static func checkSuspiciousFiles() -> Bool {
        suspiciousFiles.contains { FileManager.default.fileExists(atPath: $0) }
    }

    private static func checkSandboxWrite() -> Bool {
        let path = "/private/jailbreak_\(UUID().uuidString)"
        do {
            try "x".write(toFile: path, atomically: true, encoding: .utf8)
            try? FileManager.default.removeItem(atPath: path)
            return true
        } catch {
            return false
        }
    }

    private static func checkSuspiciousSchemes() -> Bool {
        let schemes = ["cydia://", "sileo://", "zbra://"]
        return schemes.compactMap { URL(string: $0) }
            .contains { UIApplication.shared.canOpenURL($0) }
    }
#endif
}
