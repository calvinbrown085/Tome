import SwiftUI
import UIKit
import os

struct LoginView: View {
    @Environment(AppDependencies.self) private var deps

    @State private var serverURL: String = ""
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var isSubmitting: Bool = false
    @State private var inlineError: String? = nil
    @FocusState private var focusedField: Field?

    private enum Field: Hashable { case server, username, password }

    var body: some View {
        ZStack {
            TomeMoodyBackground()
            ScrollView {
                content
                    .padding(.horizontal, 28)
                    .padding(.top, 32)
                    .padding(.bottom, 24)
                    .frame(maxWidth: 520)
                    .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .foregroundStyle(TomePalette.ink0)
        .tint(TomePalette.ember)
    }

    private var content: some View {
        VStack(spacing: 18) {
            header
                .padding(.bottom, 8)
            field(.server, label: "Server", placeholder: "https://your-server.com",
                  text: $serverURL, keyboard: .URL, contentType: .URL, submit: .next)
            field(.username, label: "Username", placeholder: "you",
                  text: $username, keyboard: .default, contentType: .username, submit: .next)
            secureField(.password, label: "Password", text: $password)
            errorRow
            submitButton
                .padding(.top, 4)
            footer
        }
    }

    private var header: some View {
        VStack(spacing: 14) {
            ListeningTLogo(size: 72)
                .shadow(color: TomePalette.ember.opacity(0.4), radius: 28, y: 16)
                .shadow(color: .black.opacity(0.55), radius: 14, y: 8)
                .padding(.top, 8)

            Text("Tome")
                .font(.tomeSerif(44, weight: .medium))
                .italic()
                .tracking(-0.5)
                .foregroundStyle(TomePalette.ink0)

            Text("For your Audiobookshelf library.")
                .font(.subheadline)
                .tracking(0.3)
                .foregroundStyle(TomePalette.ink2)
        }
    }

    @ViewBuilder
    private func field(
        _ field: Field,
        label: String,
        placeholder: String,
        text: Binding<String>,
        keyboard: UIKeyboardType,
        contentType: UITextContentType,
        submit: SubmitLabel
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            TomeFieldLabel(text: label)
                .padding(.leading, 4)
            TextField("", text: text, prompt: placeholderText(placeholder))
                .textContentType(contentType)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(keyboard)
                .submitLabel(submit)
                .focused($focusedField, equals: field)
                .onSubmit { advanceFocus(from: field) }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .font(.system(size: 15))
                .foregroundStyle(TomePalette.ink0)
                .background(fieldBackground(focused: focusedField == field))
        }
    }

    @ViewBuilder
    private func secureField(_ field: Field, label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            TomeFieldLabel(text: label)
                .padding(.leading, 4)
            SecureField("", text: text, prompt: placeholderText("••••••••"))
                .textContentType(.password)
                .submitLabel(.go)
                .focused($focusedField, equals: field)
                .onSubmit { Task { await submit() } }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .font(.system(size: 15))
                .foregroundStyle(TomePalette.ink0)
                .background(fieldBackground(focused: focusedField == field))
        }
    }

    private func fieldBackground(focused: Bool) -> some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(TomePalette.ink0.opacity(0.05))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(focused ? TomePalette.ember : TomePalette.hairline2, lineWidth: 1)
            )
            .animation(.snappy(duration: 0.15), value: focused)
    }

    private func placeholderText(_ s: String) -> Text {
        Text(s).foregroundStyle(TomePalette.ink3)
    }

    @ViewBuilder
    private var errorRow: some View {
        if let inlineError {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(TomePalette.ember)
                Text(inlineError)
                    .font(.callout)
                    .foregroundStyle(TomePalette.ink1)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(TomePalette.ember.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(TomePalette.ember.opacity(0.3), lineWidth: 0.5)
            )
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    private var submitButton: some View {
        Button {
            Task { await submit() }
        } label: {
            HStack(spacing: 10) {
                if isSubmitting {
                    ProgressView()
                        .tint(TomePalette.bg0)
                        .controlSize(.small)
                }
                Text(isSubmitting ? "Connecting…" : "Open the shelf")
            }
        }
        .buttonStyle(TomeEmberButtonStyle())
        .disabled(!canSubmit || isSubmitting)
        .opacity(!canSubmit && !isSubmitting ? 0.55 : 1)
        .animation(.snappy, value: isSubmitting)
        .animation(.snappy, value: canSubmit)
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Text("Need a server?")
                .foregroundStyle(TomePalette.ink3)
            Text("Set up Audiobookshelf →")
                .foregroundStyle(TomePalette.gold)
        }
        .font(.system(size: 12))
        .padding(.top, 18)
    }

    private var canSubmit: Bool {
        !serverURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !username.isEmpty
            && !password.isEmpty
    }

    private func advanceFocus(from field: Field) {
        switch field {
        case .server: focusedField = .username
        case .username: focusedField = .password
        case .password: Task { await submit() }
        }
    }

    private func submit() async {
        focusedField = nil
        withAnimation(.smooth(duration: 0.2)) { inlineError = nil }
        guard let url = parsedServerURL() else {
            withAnimation(.smooth) {
                inlineError = "Enter a valid URL like https://abs.example.com"
            }
            return
        }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            try await deps.auth.login(serverURL: url, username: username, password: password)
        } catch {
            withAnimation(.smooth) {
                inlineError = userMessage(for: error)
            }
            Log.auth.error("Login failed: \(String(describing: error), privacy: .public)")
        }
    }

    private func parsedServerURL() -> URL? {
        let trimmed = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let withScheme = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        guard let url = URL(string: withScheme),
              let scheme = url.scheme?.lowercased(),
              scheme == "https" || scheme == "http",
              let host = url.host(),
              !host.isEmpty
        else { return nil }
        return url
    }

    private func userMessage(for error: any Error) -> String {
        if let api = error as? APIError {
            switch api {
            case .http(let status, _) where status == 401:
                return "Wrong username or password."
            case .http(let status, _):
                return "Server returned HTTP \(status)."
            case .transport:
                return "Couldn't reach the server. Check the URL and your network."
            case .decoding:
                return "Server response wasn't recognized. Is this an AudiobookShelf server?"
            case .invalidURL:
                return "That URL doesn't look right."
            case .noResponse:
                return "No response from the server."
            case .unauthorized:
                return "Wrong username or password."
            }
        }
        return "Login failed. \(error.localizedDescription)"
    }
}

#Preview("Login") {
    LoginView()
        .environment(AppDependencies())
}
