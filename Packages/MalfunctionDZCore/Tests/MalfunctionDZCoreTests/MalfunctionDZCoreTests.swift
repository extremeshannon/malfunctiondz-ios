import XCTest
@testable import MalfunctionDZCore

final class MalfunctionDZCoreTests: XCTestCase {
    func testAPIErrorDescriptions() {
        XCTAssertEqual(APIError.invalidURL.errorDescription, "Invalid URL.")
    }
}
