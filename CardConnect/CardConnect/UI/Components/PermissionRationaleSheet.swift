import SwiftUI

enum PermissionType {
    case camera, contacts, calendar

    var icon: String {
        switch self {
        case .camera:   "camera.fill"
        case .contacts: "person.crop.circle.badge.plus"
        case .calendar: "calendar.badge.plus"
        }
    }

    var title: String {
        switch self {
        case .camera:   "Kamera Erişimi"
        case .contacts: "Rehber Erişimi"
        case .calendar: "Takvim Erişimi"
        }
    }

    var description: String {
        switch self {
        case .camera:
            "Kartvizitleri taramak için kamera erişimi gerekiyor."
        case .contacts:
            "Taradığınız kartvizitleri rehberinize kaydetmek için erişim gerekiyor."
        case .calendar:
            "Kartvizit sahipleriyle toplantı planlamak için takvim erişimi gerekiyor."
        }
    }
}

struct PermissionRationaleSheet: View {
    @Binding var isPresented: Bool
    let permissionType: PermissionType

    @State private var isPermanentlyDenied = false
    private let coordinator = PermissionCoordinator()

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: permissionType.icon)
                .font(.system(size: 56))
                .foregroundStyle(.accent)

            VStack(spacing: 8) {
                Text(permissionType.title)
                    .font(.title2.bold())
                Text(permissionType.description)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                if isPermanentlyDenied {
                    Button {
                        coordinator.openSettings()
                    } label: {
                        Text("Ayarlara Git")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button {
                        Task {
                            let status = await requestPermission()
                            if status == .denied {
                                isPermanentlyDenied = true
                            } else {
                                isPresented = false
                            }
                        }
                    } label: {
                        Text("İzin Ver")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }

                Button {
                    isPresented = false
                } label: {
                    Text("Şimdi Değil")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(32)
        .task {
            let status = await currentStatus()
            isPermanentlyDenied = (status == .denied)
        }
    }

    private func currentStatus() async -> PermissionCoordinator.Status {
        switch permissionType {
        case .camera:   await coordinator.cameraStatus()
        case .contacts: await coordinator.contactsStatus()
        case .calendar: await coordinator.calendarStatus()
        }
    }

    private func requestPermission() async -> PermissionCoordinator.Status {
        switch permissionType {
        case .camera:   await coordinator.requestCamera()
        case .contacts: await coordinator.requestContacts()
        case .calendar: await coordinator.requestCalendar()
        }
    }
}
