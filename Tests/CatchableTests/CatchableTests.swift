import Catchable
import XCTest

@MainActor
final class CatchableTests: XCTestCase {
    func testErrorProcessing() async {
        let errorProcessor = CustomErrorProcessor()
        let defaultUserService = DefaultUserService()
        let date = Date.now
        let uuid = UUID()

        defaultUserService.enabledStub = true
        defaultUserService.currentStub = [.johnDoe]
        defaultUserService.currentForLimitStub = { Array(repeating: .johnDoe, count: $0) }
        defaultUserService.isRegisteredStub = { $0 == .johnDoe }

        let sut = defaultUserService.catchable(errorProcessor: errorProcessor)

        XCTAssertTrue(sut.enabled)

        sut.start()
        XCTAssertTrue(defaultUserService.startCalled)

        sut.stop()
        XCTAssertTrue(defaultUserService.stopCalled)

        let current = sut.current()
        XCTAssertEqual(current, [.johnDoe])

        let currentForLimit = sut.current(limit: 2)
        XCTAssertEqual(defaultUserService.currentLimitCalled, 2)
        XCTAssertEqual(currentForLimit, [.johnDoe, .johnDoe])

        sut.register(.johnDoe)
        XCTAssertEqual(defaultUserService.registerUserCalled, .johnDoe)

        let isRegistered = sut.isRegistered(.johnDoe)
        XCTAssertEqual(defaultUserService.isRegisteredUserCalled, .johnDoe)
        XCTAssertTrue(isRegistered)

        do {
            try await sut.deactiveAllUsers(where: { $0 == .johnDoe })
            XCTFail("deactiveAllUsers should throw an error")
        } catch {
            XCTAssertTrue(defaultUserService.deactiveAllUsersCalled)
            XCTAssertEqual(error as? CustomError, CustomError(wrapped: DefaultUserService.Error.unknown))
        }

        do {
            try sut.deactiveUser(.johnDoe, at: date)
            XCTFail("deactiveUser should throw an error")
        } catch {
            XCTAssertEqual(defaultUserService.deactiveUserCalled?.0, .johnDoe)
            XCTAssertEqual(defaultUserService.deactiveUserCalled?.1, date)
            XCTAssertEqual(error as? CustomError, CustomError(wrapped: DefaultUserService.Error.unknown))
        }

        do {
            _ = try await sut.getPendingDeactivations(where: { _ in throw DefaultUserService.Error.unknown })
            XCTFail("getPendingDeactivations should throw an error")
        } catch {
            XCTAssertTrue(defaultUserService.getPendingDeactivationsCalled)
            XCTAssertEqual(error as? CustomError, CustomError(wrapped: DefaultUserService.Error.unknown))
        }

        do {
            _ = try sut.scheduleMaintenance(at: date, message: "foo")
            XCTFail("scheduleMaintenance should throw an error")
        } catch {
            XCTAssertEqual(defaultUserService.scheduleMaintenanceCalled?.0, date)
            XCTAssertEqual(defaultUserService.scheduleMaintenanceCalled?.1, "foo")
            XCTAssertEqual(error as? CustomError, CustomError(wrapped: DefaultUserService.Error.unknown))
        }

        sut.cancelMaintenance(uuid: uuid)
        XCTAssertEqual(defaultUserService.cancelMaintenanceCalled, uuid)
    }
}

private extension CatchableTests {
    struct CustomError: Error, Equatable {
        let wrapped: Error

        static func == (lhs: CustomError, rhs: CustomError) -> Bool {
            lhs.wrapped.localizedDescription == rhs.wrapped.localizedDescription
        }
    }

    struct CustomErrorProcessor: ErrorProcessor {
        func callAsFunction(_ error: Error) -> Error {
            CustomError(wrapped: error)
        }
    }
}

// MARK: SUT

public struct User: Sendable, Equatable {
    let firstName: String
    let lastName: String

    static var johnDoe: User {
        .init(firstName: "John", lastName: "Doe")
    }
}

public struct Deactivation: Sendable, Equatable {
    let user: User
    let date: Date
}

@Catchable
public protocol UserService: Sendable {
    var enabled: Bool { get }

    @MainActor func start()
    @MainActor func stop()

    func current() -> [User]
    func current(limit: Int) -> [User]

    func register(_ user: User)
    func isRegistered(_ user: User) -> Bool

    func deactiveAllUsers(where condition: @Sendable (User) -> Bool) async throws
    func deactiveUser(_ user: User, at date: Date) throws
    func getPendingDeactivations(where condition: @Sendable (User) throws -> Bool) async rethrows -> [Deactivation]

    func scheduleMaintenance(at date: Date, message: String) throws -> UUID
    func cancelMaintenance(uuid: UUID)
}

final class DefaultUserService: UserService, @unchecked Sendable {
    enum Error: Swift.Error {
        case unknown
    }

    var enabledStub: Bool = false
    var enabled: Bool { enabledStub }

    var startCalled: Bool = false
    @MainActor func start() {
        startCalled = true
    }
    var stopCalled: Bool = false
    @MainActor func stop() {
        stopCalled = true
    }

    var currentStub: [User] = []
    func current() -> [User] { currentStub }
    var currentLimitCalled: Int = 0
    var currentForLimitStub: (Int) -> [User] = { _ in [] }
    func current(limit: Int) -> [User] {
        currentLimitCalled = limit
        return currentForLimitStub(limit)
    }

    var registerUserCalled: User? = nil
    func register(_ user: User) {
        registerUserCalled = user
    }
    var isRegisteredUserCalled: User? = nil
    var isRegisteredStub: (User) -> Bool = { _ in false }
    func isRegistered(_ user: User) -> Bool {
        isRegisteredUserCalled = user
        return isRegisteredStub(user)
    }

    var deactiveAllUsersCalled: Bool = false
    func deactiveAllUsers(where condition: @Sendable (User) -> Bool) async throws {
        deactiveAllUsersCalled = true
        throw Error.unknown
    }
    var deactiveUserCalled: (User, Date)? = nil
    func deactiveUser(_ user: User, at date: Date) throws {
        deactiveUserCalled = (user, date)
        throw Error.unknown
    }
    var getPendingDeactivationsCalled: Bool = false
    func getPendingDeactivations(where condition: @Sendable (User) throws -> Bool) async rethrows -> [Deactivation] {
        getPendingDeactivationsCalled = true
        do {
            let user = User.johnDoe
            _ = try condition(user)
            return [.init(user: user, date: .now)]
        } catch {
            throw Error.unknown
        }
    }

    var scheduleMaintenanceCalled: (Date, String)? = nil
    func scheduleMaintenance(at date: Date, message: String) throws -> UUID {
        scheduleMaintenanceCalled = (date, message)
        throw Error.unknown
    }
    var cancelMaintenanceCalled: UUID? = nil
    func cancelMaintenance(uuid: UUID) {
        cancelMaintenanceCalled = uuid
    }
}
