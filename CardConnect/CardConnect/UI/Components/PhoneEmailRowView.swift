// PhoneEmailRowView.swift
// CardConnect

import SwiftUI

struct PhoneEmailRowView: View {
    enum RowType { case phone, email }

    @Binding var value: String
    let type: RowType
    let onDelete: () -> Void

    var body: some View {
        HStack {
            TextField(type == .phone ? "Telefon" : "E-posta", text: $value)
                .keyboardType(type == .phone ? .phonePad : .emailAddress)
                .textContentType(type == .phone ? .telephoneNumber : .emailAddress)
                .textInputAutocapitalization(type == .email ? .never : .sentences)
            Button(role: .destructive, action: onDelete) {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        }
    }
}
