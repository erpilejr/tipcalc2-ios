import SwiftUI

struct TipCalc {
    static func parse(_ text: String) -> Decimal? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        let digits = trimmed.filter { $0.isASCII && $0.isNumber }
        let dots = trimmed.filter { $0 == "." }.count
        guard !digits.isEmpty, dots <= 1, digits.count + dots == trimmed.count else { return nil }
        return Decimal(string: trimmed, locale: Locale(identifier: "en_US_POSIX"))
    }

    static func cents(_ value: Decimal) -> Decimal {
        var input = value
        var result = Decimal()
        NSDecimalRound(&result, &input, 2, .plain)
        return result
    }

    static func money(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_NZ")
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return "$" + (formatter.string(from: value as NSDecimalNumber) ?? "0.00")
    }

    struct Amounts {
        let tip: String
        let total: String
        let each: String
    }

    static func amounts(bill text: String, percent: Int, people: Int = 1) -> Amounts {
        let bill = parse(text) ?? 0
        let tip = cents(bill * Decimal(percent) / 100)
        let total = cents(bill + tip) // spec line 29: exact decimal, half a cent rounds up
        let each = cents(total / Decimal(people))
        return Amounts(tip: money(tip), total: money(total), each: money(each))
    }
}

struct RootView: View {
    @State private var bill = ""
    @State private var percent = 15
    @State private var people = 1

    var body: some View {
        let result = TipCalc.amounts(bill: bill, percent: percent, people: people)
        VStack(spacing: 12) {
            TextField("Bill", text: $bill)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.decimalPad)
                .accessibilityIdentifier("bill-input")
            HStack {
                Button("10%") { percent = 10 }.accessibilityIdentifier("tip-10")
                Button("15%") { percent = 15 }.accessibilityIdentifier("tip-15")
                Button("20%") { percent = 20 }.accessibilityIdentifier("tip-20")
            }
            .buttonStyle(.bordered)
            Text("Tip: \(percent)%").accessibilityIdentifier("tip-label")
            HStack(spacing: 20) { // spec lines 19-20: people row, then the three amounts below it
                Button("−") { people = max(1, people - 1) }
                    .accessibilityIdentifier("people-minus")
                Text("\(people)").accessibilityIdentifier("people-count")
                Button("+") { people = min(20, people + 1) }
                    .accessibilityIdentifier("people-plus")
            }
            .buttonStyle(.bordered)
            Text(result.tip).accessibilityIdentifier("tip-amount")
            Text(result.total).accessibilityIdentifier("total-amount")
            Text(result.each).accessibilityIdentifier("each-amount")
            Spacer()
        }
        .padding()
    }
}
