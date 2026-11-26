import XCTest

/// The steps a scenario test is made of, with the harness's waits: each one waits up to five seconds.
/// Elements are found by accessibility identifier. A failed step is reported at the caller's file and line.
/// Harness-owned.
final class Scenario {
    private static let timeout: TimeInterval = 5
    private static let maxSwipes = 10
    private static let maxClearRounds = 12
    /// Where a field is tapped to put the caret at the end of its text, not in the middle of long text.
    private static let trailingEdge = CGVector(dx: 0.97, dy: 0.5)
    private let locale: String
    private let language: String
    private let app = XCUIApplication()

    /// `region` is a language-region code such as `en-US` or `de_DE`.
    init(region: String) {
        locale = region.replacingOccurrences(of: "-", with: "_")
        language = String(locale.prefix { $0 != "_" })
    }

    func launch(fresh: Bool) {
        app.launchArguments = (fresh ? ["-harness-fresh"] : []) + ["-AppleLocale", locale, "-AppleLanguages", "(\(language))"]
        app.launch()
    }

    func tap(_ identifier: String, file: StaticString = #filePath, line: UInt = #line) {
        ready(identifier, file: file, line: line)?.tap()
    }

    func type(_ identifier: String, _ text: String, file: StaticString = #filePath, line: UInt = #line) {
        guard let element = ready(identifier, file: file, line: line) else { return }
        element.coordinate(withNormalizedOffset: Self.trailingEdge).tap()
        element.typeText(text)
    }

    func clear(_ identifier: String, file: StaticString = #filePath, line: UInt = #line) {
        guard let element = ready(identifier, file: file, line: line) else { return }
        // A tap at the trailing edge can land mid-text when the field is not focused and its text is wider than the
        // field: each round deletes what is before the caret, so repeat until nothing is left.
        for _ in 0..<Self.maxClearRounds {
            let current = shown(element)
            if current.isEmpty { return }
            element.coordinate(withNormalizedOffset: Self.trailingEdge).tap()
            element.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
        }
        if !shown(element).isEmpty { XCTFail("could not clear \(identifier): it still shows text", file: file, line: line) }
    }

    func expectShows(_ identifier: String, _ text: String, file: StaticString = #filePath, line: UInt = #line) {
        let element = find(identifier)
        guard element.waitForExistence(timeout: Self.timeout) else {
            return XCTFail("expected \(identifier) to exist", file: file, line: line)
        }
        let want = Self.normalised(text)
        let deadline = Date().addingTimeInterval(Self.timeout)
        var seen = shown(element)
        while seen != want && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.2)
            seen = shown(element)
        }
        XCTAssertEqual(seen, want, "\(identifier) shows a different text", file: file, line: line)
    }

    func expectExists(_ identifier: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(find(identifier).waitForExistence(timeout: Self.timeout), "expected \(identifier) to exist", file: file, line: line)
    }

    func expectGone(_ identifier: String, file: StaticString = #filePath, line: UInt = #line) {
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: find(identifier))
        let result = XCTWaiter().wait(for: [gone], timeout: Self.timeout)
        XCTAssertEqual(result, .completed, "expected \(identifier) to be gone", file: file, line: line)
    }

    /// Ends the app process and starts it again with the same saved data.
    func restart() {
        app.terminate()
        app.launchArguments = app.launchArguments.filter { $0 != "-harness-fresh" }
        app.launch()
    }

    private func find(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    /// The element once it exists and is on screen: scrolls up to ten swipes when it is not.
    private func ready(_ identifier: String, file: StaticString, line: UInt) -> XCUIElement? {
        let element = find(identifier)
        guard element.waitForExistence(timeout: Self.timeout) else {
            XCTFail("expected \(identifier) to exist", file: file, line: line)
            return nil
        }
        let scroller = [app.scrollViews, app.collectionViews, app.tables].map { $0.firstMatch }.first { $0.exists }
        var swipes = 0
        while !element.isHittable && swipes < Self.maxSwipes, let scroller {
            scroller.swipeUp()
            swipes += 1
        }
        return element
    }

    /// What the element shows: a text field's value (nothing while it shows its placeholder), else its label.
    private func shown(_ element: XCUIElement) -> String {
        let fields: [XCUIElement.ElementType] = [.textField, .secureTextField, .textView, .searchField]
        guard fields.contains(element.elementType) else { return Self.normalised(element.label) }
        let value = element.value as? String ?? ""
        if value == element.placeholderValue { return "" }
        return Self.normalised(value)
    }

    /// No-break and narrow no-break spaces (a locale's currency format uses them) read as an ordinary space.
    private static func normalised(_ text: String) -> String {
        text.replacingOccurrences(of: "\u{00A0}", with: " ").replacingOccurrences(of: "\u{202F}", with: " ")
    }
}
