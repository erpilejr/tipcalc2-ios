import XCTest

/// Harness-owned. It has no tests: it gives the AppTests bundle a source file once the builder's own tests
/// (AppTests/Own) are cleared before verify, so the bundle still has an executable to load.
final class Anchor: XCTestCase {}
