// MainTabView.swift
// CardConnect

import SwiftUI

enum AppTab: Int {
    case home, contacts, templates, mail
}

struct MainTabView: View {

    @Binding var path: NavigationPath
    @State private var selectedTab: AppTab = .home

    var body: some View {
        ZStack(alignment: .bottom) {
            tabContent
                .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 56) }

            AppBottomTabBar(
                selectedTab: $selectedTab,
                onCameraTap: { path.append(AppRoute.camera) }
            )
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .home:
            HomeView(onShowAllContacts: { selectedTab = .contacts })
        case .contacts:
            ContactsView()
        case .templates:
            TemplatesView()
        case .mail:
            ContactsView()
        }
    }
}

// MARK: - Bottom Tab Bar

private struct AppBottomTabBar: View {

    @Binding var selectedTab: AppTab
    let onCameraTap: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            tabItem(tab: .home,      icon: "house.fill",       label: "Ana Sayfa")
            tabItem(tab: .contacts,  icon: "person.2.fill",    label: "Kişiler")

            Button(action: onCameraTap) {
                VStack(spacing: 4) {
                    Image(systemName: "viewfinder")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 52, height: 52)
                        .background(Color.accentColor, in: Circle())
                        .shadow(color: Color.accentColor.opacity(0.35), radius: 8, y: 4)
                    Text("")
                        .font(.caption2)
                }
                .frame(maxWidth: .infinity)
                .offset(y: -10)
            }
            .buttonStyle(.plain)

            tabItem(tab: .templates, icon: "doc.text.fill",    label: "Şablonlar")
            tabItem(tab: .mail,      icon: "paperplane.fill",  label: "Mail Gönder")
        }
        .padding(.horizontal, 4)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(.regularMaterial)
        .overlay(alignment: .top) { Divider() }
    }

    private func tabItem(tab: AppTab, icon: String, label: String) -> some View {
        Button { selectedTab = tab } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                Text(label)
                    .font(.caption2)
            }
            .foregroundStyle(selectedTab == tab ? Color.accentColor : Color.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}
