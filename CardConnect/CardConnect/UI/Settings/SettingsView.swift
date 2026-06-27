// SettingsView.swift
// CardConnect

import SwiftUI

struct SettingsView: View {

    @AppStorage("onboarding_done") private var onboardingDone = false
    @Environment(\.dependencies) private var dependencies
    @State private var showResetConfirm = false

    var body: some View {
        List {
            Section {
                Button(role: .destructive) {
                    showResetConfirm = true
                } label: {
                    Label("Önbelleği Temizle ve Sıfırla", systemImage: "arrow.counterclockwise")
                }
            } footer: {
                Text("Tüm kişiler, profil ve uygulama verileri silinir. Karşılama ekranı yeniden gösterilir.")
            }

            Section("Hakkında") {
                NavigationLink(value: AppRoute.privacyPolicy) {
                    Label("Gizlilik Politikası", systemImage: "hand.raised")
                }
            }
        }
        .navigationTitle("Ayarlar")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Uygulamayı Sıfırla",
            isPresented: $showResetConfirm,
            titleVisibility: .visible
        ) {
            Button("Sıfırla", role: .destructive) {
                Task { await resetApp() }
            }
            Button("İptal", role: .cancel) {}
        } message: {
            Text("Tüm kişiler ve profil silinecek. Bu işlem geri alınamaz.")
        }
    }

    private func resetApp() async {
        try? await dependencies.userProfileStore.deleteProfile()
        if let domain = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: domain)
        }
        onboardingDone = false
    }
}
