import SwiftUI

struct AuthView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(SyncEngine.self) private var sync

    enum Mode: String, CaseIterable {
        case login = "登录"
        case register = "注册"
    }

    @State private var mode: Mode = .login
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var errorMessage: String?
    @State private var busy = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    header
                    form
                }
                .padding(24)
            }
            .navigationTitle("四象")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        ServerSettingsView()
                    } label: {
                        Image(systemName: "server.rack")
                    }
                    .accessibilityLabel("服务器设置")
                }
            }
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.grid.2x2.fill")
                .font(.system(size: 52))
                .foregroundStyle(Theme.accent)
            Text("四象")
                .font(.largeTitle.bold())
            Text("重要×紧急，理清每一天")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 20)
    }

    private var form: some View {
        VStack(spacing: 14) {
            Picker("模式", selection: $mode) {
                ForEach(Mode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            if mode == .register {
                TextField("昵称（可选）", text: $displayName)
                    .textFieldStyle(.roundedBorder)
            }

            TextField("邮箱", text: $email)
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)

            SecureField("密码（至少 8 位）", text: $password)
                .textContentType(mode == .login ? .password : .newPassword)
                .textFieldStyle(.roundedBorder)

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button {
                Task { await submit() }
            } label: {
                Group {
                    if busy {
                        ProgressView()
                    } else {
                        Text(mode == .login ? "登录" : "注册并登录")
                            .bold()
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!isValid || busy)

            NavigationLink {
                ServerSettingsView()
            } label: {
                Text("服务器地址：\(APIClient.shared.baseURL.absoluteString)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var isValid: Bool {
        email.contains("@") && password.count >= 8
    }

    private func submit() async {
        busy = true
        defer { busy = false }
        errorMessage = nil
        do {
            switch mode {
            case .login:
                try await auth.login(email: email, password: password)
            case .register:
                try await auth.register(email: email, password: password, displayName: displayName.isEmpty ? nil : displayName)
            }
            await sync.sync()
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }
}
