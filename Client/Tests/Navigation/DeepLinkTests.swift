import XCTest
@testable import kreta

final class DeepLinkTests: XCTestCase {
    func testHomeDeepLinkResolvesToHomeTab() {
        let url = URL(string: "kreta://home")!
        let destination = DeepLink.destination(from: url)
        XCTAssertEqual(destination, .tab(.home))
    }
}
