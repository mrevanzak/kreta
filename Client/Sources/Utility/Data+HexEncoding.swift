import Foundation

extension Data {
    func hexEncodedString() -> String {
        map { String(format: "%02x", $0) }.joined()
    }
}
