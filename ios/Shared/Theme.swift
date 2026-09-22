import SwiftUI

enum Theme {
    /// 品牌主色（#5E6AD2）
    static let accent = Color(red: 94 / 255, green: 106 / 255, blue: 210 / 255)

    /// 四象限标准配色：重要紧急=红，重要不紧急=蓝，紧急不重要=橙，不紧急不重要=灰
    static let quadrantColors: [Color] = [
        Color(red: 235 / 255, green: 87 / 255, blue: 87 / 255),
        Color(red: 47 / 255, green: 128 / 255, blue: 237 / 255),
        Color(red: 242 / 255, green: 153 / 255, blue: 74 / 255),
        Color(.systemGray2),
    ]

    static func quadrantColor(_ quadrant: Int) -> Color {
        quadrantColors[max(0, min(3, quadrant - 1))]
    }

    static func quadrantTitle(_ quadrant: Int) -> String {
        switch quadrant {
        case 1: return "重要且紧急"
        case 2: return "重要不紧急"
        case 3: return "紧急不重要"
        case 4: return "不紧急不重要"
        default: return "未分类"
        }
    }

    /// 图例用的短标题
    static func quadrantShortTitle(_ quadrant: Int) -> String {
        switch quadrant {
        case 1: return "重要紧急"
        case 2: return "重要不紧急"
        case 3: return "紧急不重要"
        case 4: return "不紧急不重要"
        default: return "未分类"
        }
    }

    static func priorityTitle(_ priority: Int) -> String {
        switch priority {
        case 1: return "高"
        case 2: return "中"
        case 3: return "低"
        default: return "中"
        }
    }

    /// 解析 #RRGGBB 颜色
    static func color(fromHex hex: String) -> Color {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let value = UInt64(s, radix: 16) else { return .gray }
        return Color(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}
