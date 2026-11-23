import XCTest
@testable import MediLens

final class ImprintNormalizerTests: XCTestCase {
    func testStripsNoiseTokensAndUppercases() {
        XCTAssertEqual(ImprintNormalizer.normalize("J분할선W"), "JW")
        XCTAssertEqual(ImprintNormalizer.normalize("Hanmi Lipidown   60"), "HANMILIPIDOWN60")
        XCTAssertEqual(ImprintNormalizer.normalize("VD분할선5 마크"), "VD5")
    }
}
