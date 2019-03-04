import XCTest
@testable import StubKit

final class StubKitTests: XCTestCase {

    // MARK: Stub
    func testSetConfig() {
        struct Item: Decodable {}
        var stub = Stub(type: Item.self)
        let maxDepth = 10
        stub.maxDepth = maxDepth
        XCTAssertEqual(stub.maxDepth, maxDepth)
        let maxSequenceLength = 100
        stub.maxSequenceLength = maxSequenceLength
        XCTAssertEqual(stub.maxSequenceLength, maxSequenceLength)
    }
}

class InjectorTests: XCTestCase {

    struct Item: Decodable {
        let id: Int
        var name: String

        var description: String {
            return id.description + name
        }
    }

    func testLetInjection() throws {
        let item = Item(id: 1, name: "foo")
        let injector = Stub<Item>.Injector()
        injector.set(\.id, value: 2)
        let injectedItem = try injector.inject(to: item)
        XCTAssertEqual(injectedItem.id, 2)
    }

    func testVarInjection() throws {
        let item = Item(id: 1, name: "foo")
        let injector = Stub<Item>.Injector()
        injector.set(\.name, value: "bar")
        let injectedItem = try injector.inject(to: item)
        XCTAssertEqual(injectedItem.name, "bar")
    }

    func testUnsupportedInjection() throws {
        let item = Item(id: 1, name: "foo")
        let injector = Stub<Item>.Injector()
        injector.set(\.description, value: "description")
        XCTAssertThrowsError(try injector.inject(to: item)) { error in
            guard let injectionError = error as? Stub<Item>.InjectionError else {
                XCTFail(String(describing: error))
                return
            }
            switch injectionError {
            case .unsupportedProperty: break
            }
        }
    }
}

class EnumStubTests: XCTestCase {

    /// If failed, please see TypeMetadata document(https://github.com/apple/swift/blob/master/docs/ABI/TypeMetadata.rst#common-metadata-layout)
    /// and definition(https://github.com/apple/swift/blob/master/include/swift/ABI/MetadataKind.def),
    /// and check that `Enum` metadata has a kind of 2.
    func testIsEnum() {
        enum E {
            case case1
        }
        XCTAssertTrue(EnumStub.isEnum(E.self))
    }

    func testIsEnumWithEmptyEnum() {
        enum E {}
        XCTAssertTrue(EnumStub.isEnum(E.self))
    }

    func testIsEnumWithAssocValue() {
        enum E1 {
            case case1(String)
        }
        XCTAssertTrue(EnumStub.isEnum(E1.self))
        enum E2 {
            case case1(String, String)
        }
        XCTAssertTrue(EnumStub.isEnum(E2.self))
    }

    func testIsEnumWithRawValue() {
        enum E: String {
            case case1 = "case1"
        }
        XCTAssertTrue(EnumStub.isEnum(E.self))
    }

    func testIsNotEnum() {
        struct S {}
        class C {}
        XCTAssertFalse(EnumStub.isEnum(S.self))
        XCTAssertFalse(EnumStub.isEnum(C.self))
        XCTAssertFalse(EnumStub.isEnum(CustomStringConvertible.self))
    }

    /// If failed, please see `Enum` memory layout(https://github.com/apple/swift/blob/master/docs/ABI/TypeLayout.rst#c-like-enums)
    /// and check that no-payload `Enum` is represented as starting 0 and ordered integer.
    func testStubEnum() {
        enum E {
            case case1
        }

        do {
            let e = try EnumStub.stub(E.self)
            XCTAssertEqual(e, .case1)
        } catch {
            XCTFail(String(describing: error))
        }
    }

    func testStubGenericEnum() {
        enum E<T> {
            case case1(T)
        }

        XCTAssertThrowsError(try EnumStub.stub(E<Int>.self)) { error in
            guard let enumStubError = error as? EnumStub.Error else {
                XCTFail(String(describing: error))
                return
            }
            switch enumStubError {
            case .notSupportingPayloadEnum(let type):
                XCTAssert(type == E<Int>.self as Any.Type)
            default: XCTFail("Should throw notSupportingPayloadEnum")
            }
        }
    }

    func testStubRawValueEnum() {
        enum E: String {
            case case1
        }
        do {
            let e = try EnumStub.stub(E.self)
            XCTAssertEqual(e, .case1)
        } catch {
            XCTFail(String(describing: error))
        }
    }

    func testStubPayloadEnum() {
        enum E {
            case case1(String)
        }
        XCTAssertThrowsError(try EnumStub.stub(E.self)) { error in
            guard let enumStubError = error as? EnumStub.Error else {
                XCTFail(String(describing: error))
                return
            }
            switch enumStubError {
            case .notSupportingPayloadEnum(let type):
                XCTAssert(type == E.self as Any.Type)
            default: XCTFail("Should throw notSupportingPayloadEnum")
            }
        }
    }

    func testStubNoCasesEnum() {
        enum E {}
        XCTAssertThrowsError(try EnumStub.stub(E.self)) { error in
            guard let enumStubError = error as? EnumStub.Error else {
                XCTFail(String(describing: error))
                return
            }
            switch enumStubError {
            case .notSupportingNoCasesEnum(let type):
                XCTAssert(type == E.self as Any.Type)
            default: XCTFail("Should throw notSupportingNoCasesEnum")
            }
        }
    }

    func testStubNotEnum() {
        struct S {}
        XCTAssertThrowsError(try EnumStub.stub(S.self)) { error in
            guard let enumStubError = error as? EnumStub.Error else {
                XCTFail(String(describing: error))
                return
            }
            switch enumStubError {
            case .notEnumType(let type):
                XCTAssert(type == S.self as Any.Type)
            default: XCTFail("Should throw notSupportingNoCasesEnum")
            }
        }
    }

    /// If failed, please see NominalTypeDescriptor document(https://github.com/apple/swift/blob/master/docs/ABI/TypeMetadata.rst#nominal-type-descriptor)
    /// and check that number of payload cases are stored at offset 2 and number of no-payload cases are stored at offset 3.
    func testEnumKind() {
        enum E {
            case case1
        }
        XCTAssertEqual(EnumStub.enumKind(E.self), .noPayload)
    }

    func testEnumKindWithEmptyEnum() {
        enum E {}
        XCTAssertEqual(EnumStub.enumKind(E.self), .noCases)
    }

    func testEnumKindWithAssocValue() {
        enum E {
            case case1(String)
        }
        XCTAssertEqual(EnumStub.enumKind(E.self), .payload)
    }

    func testEnumKindWithRawValue() {
        enum E: String {
            case case1
        }
        XCTAssertEqual(EnumStub.enumKind(E.self), .noPayload)
    }

    func testEnumKindWithGeneric() {
        enum E<T> {
            case case1(T)
        }
        XCTAssertEqual(EnumStub.enumKind(E<Int>.self), .payload)
    }
}
