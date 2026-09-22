import Foundation

/// 服务端时间统一为 ISO 8601（可能带毫秒），本工具负责双向转换。
enum SixiangDate {
    static func parse(_ s: String) -> Date? {
        let f1 = ISO8601DateFormatter()
        f1.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f1.date(from: s) { return d }
        let f2 = ISO8601DateFormatter()
        f2.formatOptions = [.withInternetDateTime]
        return f2.date(from: s)
    }

    static func string(_ d: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.string(from: d)
    }
}

extension JSONDecoder {
    /// 兼容毫秒/无毫秒 ISO 8601 的解码器
    static var sixiang: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let s = try container.decode(String.self)
            guard let date = SixiangDate.parse(s) else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "无法解析日期: \(s)")
            }
            return date
        }
        return decoder
    }
}

extension JSONEncoder {
    static var sixiang: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(SixiangDate.string(date))
        }
        return encoder
    }
}
