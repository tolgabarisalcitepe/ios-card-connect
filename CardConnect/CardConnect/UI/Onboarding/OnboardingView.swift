// OnboardingView.swift
// CardConnect
// Akış: Welcome → Features → Privacy (KVKK) → Profile Setup → Home

import SwiftUI

struct OnboardingView: View {
    let onComplete: () -> Void

    @State private var step = 0
    @AppStorage("privacy_accepted") private var privacyAccepted = false
    @Environment(\.dependencies) private var dependencies

    var body: some View {
        VStack(spacing: 0) {
            stepContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            navigationBar
        }
        .animation(.easeInOut, value: step)
    }

    // MARK: - Step Content

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case 0: WelcomePage()
        case 1: FeaturesPage()
        case 2: PrivacyPage(accepted: $privacyAccepted)
        default: ProfileSetupPage(store: dependencies.userProfileStore, onComplete: onComplete)
        }
    }

    // MARK: - Navigation Bar

    private var navigationBar: some View {
        HStack {
            backButton
            Spacer()
            progressDots
            Spacer()
            nextButton
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
    }

    @ViewBuilder
    private var backButton: some View {
        if step > 0 && step < 3 {
            Button("Geri") { step -= 1 }
                .foregroundStyle(.secondary)
        } else {
            Color.clear.frame(width: 44, height: 44)
        }
    }

    private var progressDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<4) { i in
                Circle()
                    .fill(i == step ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: 8, height: 8)
                    .animation(.spring, value: step)
            }
        }
    }

    @ViewBuilder
    private var nextButton: some View {
        if step < 2 {
            Button("İleri") { step += 1 }
                .fontWeight(.semibold)
        } else if step == 2 {
            Button("İleri") { step += 1 }
                .fontWeight(.semibold)
                .disabled(!privacyAccepted)
                .opacity(privacyAccepted ? 1 : 0.4)
        } else {
            Color.clear.frame(width: 44, height: 44)
        }
    }
}

// MARK: - Step 0: Welcome

private struct WelcomePage: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "creditcard.viewfinder")
                .font(.system(size: 72))
                .foregroundStyle(.tint)
            VStack(spacing: 8) {
                Text("Card Connect")
                    .font(.largeTitle.bold())
                Text("Kartvizitleri saniyeler içinde\ndijitale taşıyın.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 32)
    }
}

// MARK: - Step 1: Features

private struct FeaturesPage: View {
    private let items: [(String, String, String)] = [
        ("camera.viewfinder", "Tara", "Kartviziti kameraya tutun, bilgiler otomatik dolsun."),
        ("person.crop.rectangle.stack", "Yönet", "Tüm kişileriniz tek yerde, arama hızlı."),
        ("envelope.open", "Takip Et", "Şablonlarla tek dokunuşta takip maili gönderin.")
    ]

    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            Text("Nasıl Çalışır?")
                .font(.title.bold())
            VStack(spacing: 28) {
                ForEach(items, id: \.1) { icon, title, body in
                    HStack(spacing: 16) {
                        Image(systemName: icon)
                            .font(.title2)
                            .foregroundStyle(.tint)
                            .frame(width: 40)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(title).fontWeight(.semibold)
                            Text(body)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
            }
            Spacer()
        }
        .padding(.horizontal, 32)
    }
}

// MARK: - Step 2: Privacy / KVKK

private struct PrivacyPage: View {
    @Binding var accepted: Bool

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "lock.shield")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
            VStack(spacing: 12) {
                Text("Gizlilik ve KVKK")
                    .font(.title.bold())
                Text("Verileriniz yalnızca cihazınızda saklanır ve üçüncü taraflarla paylaşılmaz. 6698 sayılı KVKK kapsamında veri sorumlusu olarak bilginize sunarız.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            Toggle(isOn: $accepted) {
                Text("Gizlilik politikasını okudum ve kabul ediyorum.")
                    .font(.subheadline)
            }
            .toggleStyle(.switch)
            .tint(.accentColor)
            Spacer()
        }
        .padding(.horizontal, 32)
    }
}

// MARK: - Step 3: Profile Setup

private struct ProfileSetupPage: View {
    let store: UserProfileStore
    let onComplete: () -> Void

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var company = ""
    @State private var title = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var isSaving = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("Profilinizi Kurun")
                        .font(.title.bold())
                    Text("Takip maillerinde kullanılacak bilgilerinizi girin. Daha sonra değiştirebilirsiniz.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 32)

                VStack(spacing: 12) {
                    TextField("Ad", text: $firstName)
                        .textContentType(.givenName)
                    TextField("Soyad", text: $lastName)
                        .textContentType(.familyName)
                    TextField("Şirket", text: $company)
                        .textContentType(.organizationName)
                    TextField("Ünvan", text: $title)
                        .textContentType(.jobTitle)
                    TextField("E-posta", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                    TextField("Telefon", text: $phone)
                        .textContentType(.telephoneNumber)
                        .keyboardType(.phonePad)
                }
                .textFieldStyle(.roundedBorder)

                VStack(spacing: 12) {
                    Button {
                        save()
                    } label: {
                        Text(isSaving ? "Kaydediliyor…" : "Tamamla")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isSaving)

                    Button("Şimdi Değil") {
                        onComplete()
                    }
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 24)
        }
    }

    private func save() {
        var profile = UserProfile()
        profile.firstName = firstName
        profile.lastName = lastName
        profile.company = company
        profile.title = title
        profile.email = email
        profile.phone = phone
        isSaving = true
        Task {
            try? await store.save(profile)
            isSaving = false
            onComplete()
        }
    }
}
