import SwiftUI

/// 每个 Tab 导航栏的「我的」入口（文件工具 / 账号 / 设置）
struct ProfileToolbarModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    ProfileView()
                } label: {
                    Image(systemName: "person.crop.circle")
                }
                .accessibilityLabel("我的")
            }
        }
    }
}

extension View {
    func profileToolbar() -> some View {
        modifier(ProfileToolbarModifier())
    }
}
