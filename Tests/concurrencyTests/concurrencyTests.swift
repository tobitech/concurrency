import XCTest
@testable import concurrency

final class concurrencyTests: XCTestCase {
    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(concurrency().text, "Hello, World!")
    }
}
