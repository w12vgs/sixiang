import SwiftUI

struct ProfileView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(SyncEngine.self) private var sync

    var body: some View {
        List {
            Section("账号") {
                if let user = auth.currentUser {
                    LabeledContent("邮箱", value: user.email)
                    if let name = user.displayName, !name.isEmpty {
                        LabeledContent("昵称", value: name)
                    }
                }
                Button("退出登录", role: .destructive) {
                    auth.logout()
                }
            }

            Section("工具") {
                NavigationLink {
                    ToolsHomeView()
                } label: {
                    Label("文件工具（文件夹对比）", systemImage: "doc.on.doc")
                }
            }

            Section("设置") {
                NavigationLink {
                    ServerSettingsView()
                } label: {
                    Label("服务器地址", systemImage: "server.rack")
                }
                NavigationLink {
                    TagManageView()
                } label: {
                    Label("标签管理", systemImage: "tag")
                }
            }

            Section("同步") {
                HStack {
                    Text("状态")
                    Spacer()
                    Text(sync.state.label)
                        .foregroundStyle(.secondary)
                }
                Button("立即同步") {
                    Task { await sync.sync() }
                }
                if let t = sync.lastSyncedAt {
                    Text("上次同步：\(t.formatted(date: .abbreviated, time: .shortened))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Text("四象 v\(appVersion) · 离线优先，数据实时保存")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
        }
        .navigationTitle("我的")
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
    }
}

struct ServerSettingsView: View {
    @AppStorage("serverBaseURL") private var serverURL = "http://localhost:3000"
    @Environment(AuthManager.self) private var auth

    var body: some View {
        Form {
            Section("API 服务器地址") {
                TextField("http://localhost:3000", text: $serverURL)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            Section {
                Text("修改后新请求即生效。真机调试请填写电脑局域网 IP，例如 http://192.168.1.10:3000")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if auth.isLoggedIn {
                Section {
                    Button("退出登录后重新登录以切换账号服务器", role: .destructive) {
                        auth.logout()
                    }
                }
            }
        }
        .navigationTitle("服务器地址")
    }
}
