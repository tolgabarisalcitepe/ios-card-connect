// HomeView.swift
// CardConnect

import SwiftUI
import SwiftData

struct HomeView: View {

    #if DEBUG
    @State private var showClearConfirm = false
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dependencies) private var dependencies
    #endif

    var body: some View {
        coreView
    }

    // MARK: - Core View

    @ViewBuilder
    private var coreView: some View {
        let base = ZStack(alignment: .bottomTrailing) {
            emptyState
            scanFAB
        }
        .navigationTitle("Kişiler")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                NavigationLink(value: AppRoute.profile) {
                    Image(systemName: "person.circle")
                }
            }
            #if DEBUG
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    showClearConfirm = true
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                }
                .accessibilityIdentifier("debug_clear_cache_button")
            }
            #endif
            ToolbarItem(placement: .primaryAction) {
                NavigationLink(value: AppRoute.camera) {
                    Image(systemName: "plus")
                }
            }
        }
        #if DEBUG
        base.confirmationDialog(
            "Tüm veriyi sıfırla",
            isPresented: $showClearConfirm,
            titleVisibility: .visible
        ) {
            Button("Sıfırla", role: .destructive) {
                Task { await clearAllData() }
            }
            Button("İptal", role: .cancel) {}
        } message: {
            Text("Tüm kişiler ve profil silinecek. Uygulama başa dönecek.")
        }
        #else
        base
        #endif
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "creditcard")
                .font(.system(size: 64))
                .foregroundStyle(.secondary.opacity(0.3))
            Text("Henüz kartvizit yok")
                .font(.title2.bold())
            Text("Kameranızı bir kartvizite tutarak başlayın.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - FAB

    private var scanFAB: some View {
        NavigationLink(value: AppRoute.camera) {
            Image(systemName: "camera.viewfinder")
                .font(.title2.weight(.semibold))
                .padding(18)
                .background(Color.accentColor, in: Circle())
                .foregroundStyle(.white)
                .shadow(radius: 4, y: 2)
        }
        .padding(24)
    }

    // MARK: - Debug

    #if DEBUG
    private func clearAllData() async {
        let contacts = (try? modelContext.fetch(FetchDescriptor<Contact>())) ?? []
        let photoPaths = contacts.flatMap(\.photoPaths)
        contacts.forEach { modelContext.delete($0) }
        try? modelContext.save()
        PhotoStorage.deletePhotos(paths: photoPaths)
        try? await dependencies.userProfileStore.deleteProfile()
        if let domain = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: domain)
        }
    }
    #endif
}
