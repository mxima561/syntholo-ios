import FirebaseFirestore
import Foundation
import XCTest
@testable import Syntholo

/// Firestore hands every number back as `NSNumber`, and `NSNumber(1) as? Bool`
/// succeeds in Swift. Decoding that checked `Bool` before `NSNumber` therefore
/// turned `schemaVersion: 1` into `.bool(true)`, and every profile load failed
/// its `.integer` guard with `malformedProfileDocuments`.
///
/// The in-memory contract tests could not catch this: they never went through
/// the Objective-C bridge that creates the ambiguity.
final class FirestoreProfileValueDecodingTests: XCTestCase {
    func testSchemaVersionOneDecodesAsIntegerNotBoolean() throws {
        let value = try FirestoreProfileDocumentStore.decode(NSNumber(value: 1))

        XCTAssertEqual(value, .integer(1))
    }

    func testZeroDecodesAsIntegerNotBoolean() throws {
        let value = try FirestoreProfileDocumentStore.decode(NSNumber(value: 0))

        XCTAssertEqual(value, .integer(0))
    }

    func testGenuineBooleansStillDecodeAsBooleans() throws {
        // isDiscoverable is written as a real boolean and must stay one.
        XCTAssertEqual(
            try FirestoreProfileDocumentStore.decode(NSNumber(value: true)),
            .bool(true)
        )
        XCTAssertEqual(
            try FirestoreProfileDocumentStore.decode(NSNumber(value: false)),
            .bool(false)
        )
    }

    func testLargerIntegersRoundTrip() throws {
        XCTAssertEqual(
            try FirestoreProfileDocumentStore.decode(NSNumber(value: 42)),
            .integer(42)
        )
    }

    func testStringsListsTimestampsAndNullsAreUnaffected() throws {
        let date = Date(timeIntervalSince1970: 1_800_000_000)

        XCTAssertEqual(
            try FirestoreProfileDocumentStore.decode("syntholo" as NSString),
            .string("syntholo")
        )
        XCTAssertEqual(
            try FirestoreProfileDocumentStore.decode(["a", "b"] as NSArray),
            .stringList(["a", "b"])
        )
        XCTAssertEqual(
            try FirestoreProfileDocumentStore.decode(Timestamp(date: date)),
            .timestamp(date)
        )
        XCTAssertEqual(
            try FirestoreProfileDocumentStore.decode(NSNull()),
            .null
        )
    }

    func testUnsupportedValuesStillThrow() {
        XCTAssertThrowsError(
            try FirestoreProfileDocumentStore.decode(Data([0x01]) as NSData)
        )
    }
}
