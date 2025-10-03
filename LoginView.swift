import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var email: String = ""
    @State private var password: String = ""
    @State private var disableFields = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Sign In") {
                    TextField("Email", text: $email)
                        .textContentType(.username)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .disabled(disableFields)
                    SecureField("Password", text: $password)
                        .textContentType(.password)
                        .disabled(disableFields)
                }

                if let error = appState.authError {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Sign In")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(appState.isAuthenticating)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await authenticate() }
                    } label: {
                        if appState.isAuthenticating {
                            ProgressView()
                        } else {
                            Text("Sign In")
                        }
                    }
                    .disabled(appState.isAuthenticating || email.isEmpty || password.isEmpty)
                }
            }
        }
    }

    private func authenticate() async {
        disableFields = true
        await appState.login(email: email, password: password)
        disableFields = false
        if appState.authSession != nil {
            dismiss()
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AppState())
}
