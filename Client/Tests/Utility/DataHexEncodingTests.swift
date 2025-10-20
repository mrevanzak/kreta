import XCTest
@testable import kreta

final class DataHexEncodingTests: XCTestCase {
    func testHexEncodingProducesExpectedString() {
        let data = Data([0x0f, 0xa0, 0x1b])
        XCTAssertEqual(data.hexEncodedString(), "0fa01b")
    }
}
