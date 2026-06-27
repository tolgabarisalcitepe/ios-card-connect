// HomeView.swift
// CardConnect

import SwiftUI

struct HomeView: View {

    var body: some View {
        coreView
    }

    // MARK: - Core View

    @ViewBuilder
    private var coreView: some View {
        ZStack(alignment: .bottomTrailing) {
            emptyState
            scanFAB
        }
        .navigationTitle("Kişiler")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarLeading) {
                NavigationLink(value: AppRoute.profile) {
                    Image(systemName: "person.circle")
                }
                NavigationLink(value: AppRoute.settings) {
                    Image(systemName: "gearshape")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                NavigationLink(value: AppRoute.camera) {
                    Image(systemName: "plus")
                }
            }
        }
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

}
