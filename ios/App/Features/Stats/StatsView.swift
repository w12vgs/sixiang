import SwiftUI

/// M6 将实现：完成率折线、四象限分布、热力图、连续打卡
struct StatsView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "数据看板",
                systemImage: "chart.bar.xaxis",
                description: Text("M6 开发中：任务统计与趋势图表")
            )
            .navigationTitle("看板")
            .profileToolbar()
        }
    }
}
