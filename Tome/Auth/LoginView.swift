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
            backgroundLayer
            ScrollView {
                content
                    .padding(.horizontal, 24)
                    .padding(.vertical, 32)
                    .frame(maxWidth: 520)
                    .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    private var backgroundLayer: some View {
        LinearGradient(
            colors: [
                Color(.systemIndigo).opacity(0.55),
                Color(.systemPurple).opacity(0.45),
                Color(.systemTeal).opacity(0.35),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        .overlay(
            RadialGradient(
                colors: [Color.white.opacity(0.18), .clear],
                center: .top,
                startRadius: 20,
                endRadius: 420
            )
            .ignoresSafeArea()
        )
    }

    private var content: some View {
        VStack(spacing: 28) {
            header
            formCard
            errorRow
            submitButton
            footer
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            Image(systemName: "books.vertical.fill")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
            Text("Tome")
                .font(.system(.largeTitle, design: .serif, weight: .semibold))
                .foregroundStyle(.white)
            Text("Sign in to your AudiobookShelf server")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
        }
        .padding(.top, 16)
    }

    private var formCard: some View {
        GlassEffectContainer(spacing: 12) {
            VStack(spacing: 12) {
                fieldRow(
                    icon: "server.rack",
                    placeholder: "https://abs.example.com",
                    text: $serverURL,
                    contentType: .URL,
                    keyboard: .URL,
                    submitLabel: .next,
                    field: .server
                )
                fieldRow(
                    icon: "person",
                    placeholder: "Username",
                    text: $username,
                    contentType: .username,
                    keyboard: .default,
                    submitLabel: .next,
                    field: .username
                )
                secureRow(
                    icon: "lock",
                    placeholder: "Password",
                    text: $password,
                    field: .password
                )
            }
        }
    }

    @ViewBuilder
    private func fieldRow(
        icon: String,
        placeholder: String,
        text: Binding<String>,
        contentType: UITextContentType,
        keyboard: UIKeyboardType,
        submitLabel: SubmitLabel,
        field: Field
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 22)
            TextField(placeholder, text: text)
                .textContentType(contentType)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(keyboard)
                .submitLabel(submitLabel)
                .focused($focusedField, equals: field)
                .onSubmit { advanceFocus(from: field) }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .glassEffect()
    }

    @ViewBuilder
    private func secureRow(icon: String, placeholder: String, text: Binding<String>, field: Field) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 22)
            SecureField(placeholder, text: text)
                .textContentType(.password)
                .submitLabel(.go)
                .focused($focusedField, equals: field)
                .onSubmit { Task { await submit() } }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .glassEffect()
    }

    @ViewBuilder
    private var errorRow: some View {
        if let inlineError {
            Text(inlineError)
                .font(.callout.weight(.medium))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .glassEffect(.regular.tint(.red.opacity(0.6)))
                .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    private var submitButton: some View {
        Button {
            Task { await submit() }
        } label: {
            HStack(spacing: 8) {
                if isSubmitting {
                    ProgressView().tint(.white)
                }
                Text(isSubmitting ? "Signing in…" : "Sign In")
                    .font(.body.weight(.semibold))
            }
            .frame(maxWidth: .infinity, minHeight: 32)
        }
        .buttonStyle(.glassProminent)
        .controlSize(.large)
        .disabled(!canSubmit || isSubmitting)
        .animation(.snappy, value: isSubmitting)
        .animation(.snappy, value: canSubmit)
    }

    private var footer: some View {
        Text("Your credentials are stored on this device only.")
            .font(.caption)
            .foregroundStyle(.white.opacity(0.7))
            .multilineTextAlignment(.center)
            .padding(.top, 8)
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
