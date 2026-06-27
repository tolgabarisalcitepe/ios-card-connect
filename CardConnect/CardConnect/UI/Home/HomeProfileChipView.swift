// HomeProfileChipView.swift
// CardConnect

import SwiftUI

struct HomeProfileChipView: View {

    let profile: UserProfile
    let avatarImage: Image?

    private var subtitle: String {
        if !profile.company.isEmpty { return profile.company }
        if !profile.title.isEmpty   { return profile.title   }
        return ""
    }

    var body: some View {
        HStack(spacing: 8) {
            avatarView
            VStack(alignment: .leading, spacing: 1) {
                Text(profile.fullName)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: 140, alignment: .leading)
        }
    }

    @ViewBuilder
    private var avatarView: some View {
        if let avatarImage {
            avatarImage
                .resizable()
                .scaledToFill()
                .frame(width: 30, height: 30)
                .clipShape(Circle())
        } else {
            InitialsAvatarView(fullName: profile.fullName, size: 30)
        }
    }
}
