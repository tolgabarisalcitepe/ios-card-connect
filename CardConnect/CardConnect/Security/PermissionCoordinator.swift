// PermissionCoordinator.swift
// CardConnect
// Cat-7 önlemi: izin döngüsünü kırar, kalıcı red → Settings yönlendirir.

import AVFoundation
import Contacts
import EventKit
import UIKit

actor PermissionCoordinator {

    enum Status: Sendable {
        case undetermined, authorized, denied
    }

    // MARK: - Query (synchronous snapshots)

    func cameraStatus() -> Status {
        mapAV(AVCaptureDevice.authorizationStatus(for: .video))
    }

    func contactsStatus() -> Status {
        mapCN(CNContactStore.authorizationStatus(for: .contacts))
    }

    func calendarStatus() -> Status {
        mapEK(EKEventStore.authorizationStatus(for: .event))
    }

    // MARK: - Request

    func requestCamera() async -> Status {
        let granted = await withCheckedContinuation { (c: CheckedContinuation<Bool, Never>) in
            AVCaptureDevice.requestAccess(for: .video) { c.resume(returning: $0) }
        }
        return granted ? .authorized : .denied
    }

    func requestContacts() async -> Status {
        let granted = await withCheckedContinuation { (c: CheckedContinuation<Bool, Never>) in
            CNContactStore().requestAccess(for: .contacts) { ok, _ in c.resume(returning: ok) }
        }
        return granted ? .authorized : .denied
    }

    func requestCalendar() async -> Status {
        guard let granted = try? await EKEventStore().requestFullAccessToEvents() else {
            return .denied
        }
        return granted ? .authorized : .denied
    }

    // MARK: - Settings redirect (permanent denial recovery)

    nonisolated func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        DispatchQueue.main.async { UIApplication.shared.open(url) }
    }

    // MARK: - Private

    private func mapAV(_ s: AVAuthorizationStatus) -> Status {
        switch s {
        case .authorized: .authorized
        case .denied, .restricted: .denied
        default: .undetermined
        }
    }

    private func mapCN(_ s: CNAuthorizationStatus) -> Status {
        switch s {
        case .authorized: .authorized
        case .denied, .restricted: .denied
        default: .undetermined
        }
    }

    private func mapEK(_ s: EKAuthorizationStatus) -> Status {
        switch s {
        case .fullAccess: .authorized
        case .denied, .restricted: .denied
        default: .undetermined
        }
    }
}
