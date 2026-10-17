import Foundation

enum MaintenanceInput {
    static func integer(_ text: String, emptyValue: Int? = nil) -> Int? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.isEmpty { return emptyValue }
        guard value.allSatisfy({ $0.isASCII && $0.isNumber }),
              let number = Int(value), number >= 0, number <= 100_000_000 else { return nil }
        return number
    }

    static func decimal(_ text: String, emptyValue: Double? = nil) -> Double? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
        if value.isEmpty { return emptyValue }
        guard value.allSatisfy({ ($0.isASCII && $0.isNumber) || $0 == "." }),
              let number = Double(value), number.isFinite, number >= 0, number <= 100_000_000 else { return nil }
        return number
    }
}
