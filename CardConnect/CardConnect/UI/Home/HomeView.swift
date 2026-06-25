// HomeView.swift
// CardConnect
// Epic 2'ye kadar boş state — ContactStore Epic 2'de eklenir.

import SwiftUI

struct HomeView: View {
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            emptyState
            scanFAB
        }
        .navigationTitle("Kişiler")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    // Camera navigation — Epic 1
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "creditcard")
                .font(.system(size: 64))
                .foregroundStyle(.secondary.opacity(0.3))
            Text("Henüz kartvizit yok")
                .font(.title2.bold())
                .foregroundStyle(.primary)
            Text("Kameranızı bir kartvizite tutarak başlayın.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var scanFAB: some View {
        Button {
            // Camera scan — Epic 1
        } label: {
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
