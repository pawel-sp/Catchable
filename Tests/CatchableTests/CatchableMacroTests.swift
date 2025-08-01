import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest
import CatchableMacros

let testMacros: [String: Macro.Type] = [
    "Catchable": CatchableMacro.self,
]

final class CatchableMacroPropertiesTests: XCTestCase {
    // MARK: Basic

    func testVarGetter() {
        assertMacroExpansion(
            """
            @Catchable
            protocol FooProtocol {
                var foo: Int { get }
            }
            """,
            expandedSource:
            """
            protocol FooProtocol {
                var foo: Int { get }
            }
            
            private final class CatchableDecorator: FooProtocol {
                var foo: Int {
                    get {
                        wrapped.foo
                    }
                }
                private let wrapped: FooProtocol
                private let errorProcessor: ErrorProcessor
                init(_ wrapped: FooProtocol, errorProcessor: ErrorProcessor) {
                    self.wrapped = wrapped
                    self.errorProcessor = errorProcessor
                }
            }
            
            extension FooProtocol {
                func catchable(errorProcessor: ErrorProcessor) -> FooProtocol {
                    CatchableDecorator(self, errorProcessor: errorProcessor)
                }
            }
            """,
            macros: testMacros
        )
    }

    // MARK: Access modifiers

    func testPublicVarGetter() {
        assertMacroExpansion(
            """
            @Catchable
            public protocol FooProtocol {
                var foo: Int { get }
            }
            """,
            expandedSource:
            """
            public protocol FooProtocol {
                var foo: Int { get }
            }
            
            private final class CatchableDecorator: FooProtocol {
                var foo: Int {
                    get {
                        wrapped.foo
                    }
                }
                private let wrapped: FooProtocol
                private let errorProcessor: ErrorProcessor
                init(_ wrapped: FooProtocol, errorProcessor: ErrorProcessor) {
                    self.wrapped = wrapped
                    self.errorProcessor = errorProcessor
                }
            }
            
            extension FooProtocol {
                public func catchable(errorProcessor: ErrorProcessor) -> FooProtocol {
                    CatchableDecorator(self, errorProcessor: errorProcessor)
                }
            }
            """,
            macros: testMacros
        )
    }

    // MARK: Async

    func testAsyncVarGetter() {
        assertMacroExpansion(
            """
            @Catchable
            protocol FooProtocol {
                var foo: Int { get async }
            }
            """,
            expandedSource:
            """
            protocol FooProtocol {
                var foo: Int { get async }
            }

            private final class CatchableDecorator: FooProtocol {
                var foo: Int {
                    get async {
                        await wrapped.foo
                    }
                }
                private let wrapped: FooProtocol
                private let errorProcessor: ErrorProcessor
                init(_ wrapped: FooProtocol, errorProcessor: ErrorProcessor) {
                    self.wrapped = wrapped
                    self.errorProcessor = errorProcessor
                }
            }
            
            extension FooProtocol {
                func catchable(errorProcessor: ErrorProcessor) -> FooProtocol {
                    CatchableDecorator(self, errorProcessor: errorProcessor)
                }
            }
            """,
            macros: testMacros
        )
    }

    // MARK: Actors

    func testVarMainActorGetter() {
        assertMacroExpansion(
            """
            @Catchable
            protocol FooProtocol {
                @MainActor var foo: Int { get }
            }
            """,
            expandedSource:
            """
            protocol FooProtocol {
                @MainActor var foo: Int { get }
            }
            
            private final class CatchableDecorator: FooProtocol {
                @MainActor var foo: Int {
                    get {
                        wrapped.foo
                    }
                }
                private let wrapped: FooProtocol
                private let errorProcessor: ErrorProcessor
                init(_ wrapped: FooProtocol, errorProcessor: ErrorProcessor) {
                    self.wrapped = wrapped
                    self.errorProcessor = errorProcessor
                }
            }
            
            extension FooProtocol {
                func catchable(errorProcessor: ErrorProcessor) -> FooProtocol {
                    CatchableDecorator(self, errorProcessor: errorProcessor)
                }
            }
            """,
            macros: testMacros
        )
    }
}

final class CatchableMacroFunctionsTests: XCTestCase {
    // MARK: Basic

    func testFuncNoParamsReturnsVoid() {
        assertMacroExpansion(
            """
            @Catchable
            protocol FooProtocol {
                func foo()
            }
            """,
            expandedSource:
            """
            protocol FooProtocol {
                func foo()
            }

            private final class CatchableDecorator: FooProtocol {
                private let wrapped: FooProtocol
                private let errorProcessor: ErrorProcessor
                init(_ wrapped: FooProtocol, errorProcessor: ErrorProcessor) {
                    self.wrapped = wrapped
                    self.errorProcessor = errorProcessor
                }
                func foo() {
                    wrapped.foo()
                }
            }
            
            extension FooProtocol {
                func catchable(errorProcessor: ErrorProcessor) -> FooProtocol {
                    CatchableDecorator(self, errorProcessor: errorProcessor)
                }
            }
            """,
            macros: testMacros
        )
    }

    func testFuncNoParamsReturnsVoidExplicitly() {
        assertMacroExpansion(
            """
            @Catchable
            protocol FooProtocol {
                func foo() -> Void
            }
            """,
            expandedSource:
            """
            protocol FooProtocol {
                func foo() -> Void
            }
            
            private final class CatchableDecorator: FooProtocol {
                private let wrapped: FooProtocol
                private let errorProcessor: ErrorProcessor
                init(_ wrapped: FooProtocol, errorProcessor: ErrorProcessor) {
                    self.wrapped = wrapped
                    self.errorProcessor = errorProcessor
                }
                func foo() -> Void {
                    wrapped.foo()
                }
            }
            
            extension FooProtocol {
                func catchable(errorProcessor: ErrorProcessor) -> FooProtocol {
                    CatchableDecorator(self, errorProcessor: errorProcessor)
                }
            }
            """,
            macros: testMacros
        )
    }

    func testFuncNoParamsReturnsInt() {
        assertMacroExpansion(
            """
            @Catchable
            protocol FooProtocol {
                func foo() -> Int
            }
            """,
            expandedSource:
            """
            protocol FooProtocol {
                func foo() -> Int
            }
            
            private final class CatchableDecorator: FooProtocol {
                private let wrapped: FooProtocol
                private let errorProcessor: ErrorProcessor
                init(_ wrapped: FooProtocol, errorProcessor: ErrorProcessor) {
                    self.wrapped = wrapped
                    self.errorProcessor = errorProcessor
                }
                func foo() -> Int {
                    wrapped.foo()
                }
            }
            
            extension FooProtocol {
                func catchable(errorProcessor: ErrorProcessor) -> FooProtocol {
                    CatchableDecorator(self, errorProcessor: errorProcessor)
                }
            }
            """,
            macros: testMacros
        )
    }

    func testFuncTwoParamsReturnsInt() {
        assertMacroExpansion(
            """
            @Catchable
            protocol FooProtocol {
                func foo(arg1: String, arg2: Double) -> Int
            }
            """,
            expandedSource:
            """
            protocol FooProtocol {
                func foo(arg1: String, arg2: Double) -> Int
            }
            
            private final class CatchableDecorator: FooProtocol {
                private let wrapped: FooProtocol
                private let errorProcessor: ErrorProcessor
                init(_ wrapped: FooProtocol, errorProcessor: ErrorProcessor) {
                    self.wrapped = wrapped
                    self.errorProcessor = errorProcessor
                }
                func foo(arg1: String, arg2: Double) -> Int {
                    wrapped.foo(arg1: arg1, arg2: arg2)
                }
            }
            
            extension FooProtocol {
                func catchable(errorProcessor: ErrorProcessor) -> FooProtocol {
                    CatchableDecorator(self, errorProcessor: errorProcessor)
                }
            }
            """,
            macros: testMacros
        )
    }

    func testFuncTwoParamsIncludingWildcardReturnsInt() {
        assertMacroExpansion(
            """
            @Catchable
            protocol FooProtocol {
                func foo(_ arg1: String, arg2: Double) -> Int
            }
            """,
            expandedSource:
            """
            protocol FooProtocol {
                func foo(_ arg1: String, arg2: Double) -> Int
            }
            
            private final class CatchableDecorator: FooProtocol {
                private let wrapped: FooProtocol
                private let errorProcessor: ErrorProcessor
                init(_ wrapped: FooProtocol, errorProcessor: ErrorProcessor) {
                    self.wrapped = wrapped
                    self.errorProcessor = errorProcessor
                }
                func foo(_ arg1: String, arg2: Double) -> Int {
                    wrapped.foo(arg1, arg2: arg2)
                }
            }
            
            extension FooProtocol {
                func catchable(errorProcessor: ErrorProcessor) -> FooProtocol {
                    CatchableDecorator(self, errorProcessor: errorProcessor)
                }
            }
            """,
            macros: testMacros
        )
    }

    // MARK: Access modifiers

    func testPublicFuncNoParamsReturnsVoid() {
        assertMacroExpansion(
            """
            @Catchable
            public protocol FooProtocol {
                func foo()
            }
            """,
            expandedSource:
            """
            public protocol FooProtocol {
                func foo()
            }
            
            private final class CatchableDecorator: FooProtocol {
                private let wrapped: FooProtocol
                private let errorProcessor: ErrorProcessor
                init(_ wrapped: FooProtocol, errorProcessor: ErrorProcessor) {
                    self.wrapped = wrapped
                    self.errorProcessor = errorProcessor
                }
                func foo() {
                    wrapped.foo()
                }
            }
            
            extension FooProtocol {
                public func catchable(errorProcessor: ErrorProcessor) -> FooProtocol {
                    CatchableDecorator(self, errorProcessor: errorProcessor)
                }
            }
            """,
            macros: testMacros
        )
    }

    // MARK: Async

    func testFuncNoParamsAsyncReturnsVoid() {
        assertMacroExpansion(
            """
            @Catchable
            protocol FooProtocol {
                func foo() async
            }
            """,
            expandedSource:
            """
            protocol FooProtocol {
                func foo() async
            }
            
            private final class CatchableDecorator: FooProtocol {
                private let wrapped: FooProtocol
                private let errorProcessor: ErrorProcessor
                init(_ wrapped: FooProtocol, errorProcessor: ErrorProcessor) {
                    self.wrapped = wrapped
                    self.errorProcessor = errorProcessor
                }
                func foo() async {
                    await wrapped.foo()
                }
            }
            
            extension FooProtocol {
                func catchable(errorProcessor: ErrorProcessor) -> FooProtocol {
                    CatchableDecorator(self, errorProcessor: errorProcessor)
                }
            }
            """,
            macros: testMacros
        )
    }

    // MARK: Throws

    func testFuncNoParamsThrowsReturnsVoid() {
        assertMacroExpansion(
            """
            @Catchable
            protocol FooProtocol {
                func foo() throws
            }
            """,
            expandedSource:
            """
            protocol FooProtocol {
                func foo() throws
            }
            
            private final class CatchableDecorator: FooProtocol {
                private let wrapped: FooProtocol
                private let errorProcessor: ErrorProcessor
                init(_ wrapped: FooProtocol, errorProcessor: ErrorProcessor) {
                    self.wrapped = wrapped
                    self.errorProcessor = errorProcessor
                }
                func foo() throws {
                    do {
                        try wrapped.foo()
                    } catch {
                        throw errorProcessor(error)
                    }
                }
            }
            
            extension FooProtocol {
                func catchable(errorProcessor: ErrorProcessor) -> FooProtocol {
                    CatchableDecorator(self, errorProcessor: errorProcessor)
                }
            }
            """,
            macros: testMacros
        )
    }

    func testFuncNoParamsThrowsReturnsVoidExplitictly() {
        assertMacroExpansion(
            """
            @Catchable
            protocol FooProtocol {
                func foo() throws -> Void
            }
            """,
            expandedSource:
            """
            protocol FooProtocol {
                func foo() throws -> Void
            }
            
            private final class CatchableDecorator: FooProtocol {
                private let wrapped: FooProtocol
                private let errorProcessor: ErrorProcessor
                init(_ wrapped: FooProtocol, errorProcessor: ErrorProcessor) {
                    self.wrapped = wrapped
                    self.errorProcessor = errorProcessor
                }
                func foo() throws -> Void {
                    do {
                        try wrapped.foo()
                    } catch {
                        throw errorProcessor(error)
                    }
                }
            }
            
            extension FooProtocol {
                func catchable(errorProcessor: ErrorProcessor) -> FooProtocol {
                    CatchableDecorator(self, errorProcessor: errorProcessor)
                }
            }
            """,
            macros: testMacros
        )
    }

    func testFuncNoParamsThrowsReturnsInt() {
        assertMacroExpansion(
            """
            @Catchable
            protocol FooProtocol {
                func foo() throws -> Int
            }
            """,
            expandedSource:
            """
            protocol FooProtocol {
                func foo() throws -> Int
            }
            
            private final class CatchableDecorator: FooProtocol {
                private let wrapped: FooProtocol
                private let errorProcessor: ErrorProcessor
                init(_ wrapped: FooProtocol, errorProcessor: ErrorProcessor) {
                    self.wrapped = wrapped
                    self.errorProcessor = errorProcessor
                }
                func foo() throws -> Int {
                    do {
                        return try wrapped.foo()
                    } catch {
                        throw errorProcessor(error)
                    }
                }
            }
            
            extension FooProtocol {
                func catchable(errorProcessor: ErrorProcessor) -> FooProtocol {
                    CatchableDecorator(self, errorProcessor: errorProcessor)
                }
            }
            """,
            macros: testMacros
        )
    }

    func testFuncTwoParamsThrowsReturnsInt() {
        assertMacroExpansion(
            """
            @Catchable
            protocol FooProtocol {
                func foo(arg1: String, arg2: Double) throws -> Int
            }
            """,
            expandedSource:
            """
            protocol FooProtocol {
                func foo(arg1: String, arg2: Double) throws -> Int
            }
            
            private final class CatchableDecorator: FooProtocol {
                private let wrapped: FooProtocol
                private let errorProcessor: ErrorProcessor
                init(_ wrapped: FooProtocol, errorProcessor: ErrorProcessor) {
                    self.wrapped = wrapped
                    self.errorProcessor = errorProcessor
                }
                func foo(arg1: String, arg2: Double) throws -> Int {
                    do {
                        return try wrapped.foo(arg1: arg1, arg2: arg2)
                    } catch {
                        throw errorProcessor(error)
                    }
                }
            }
            
            extension FooProtocol {
                func catchable(errorProcessor: ErrorProcessor) -> FooProtocol {
                    CatchableDecorator(self, errorProcessor: errorProcessor)
                }
            }
            """,
            macros: testMacros
        )
    }

    func testFuncTwoParamsIncludingWildcardThrowsReturnsInt() {
        assertMacroExpansion(
            """
            @Catchable
            protocol FooProtocol {
                func foo(_ arg1: String, arg2: Double) throws -> Int
            }
            """,
            expandedSource:
            """
            protocol FooProtocol {
                func foo(_ arg1: String, arg2: Double) throws -> Int
            }
            
            private final class CatchableDecorator: FooProtocol {
                private let wrapped: FooProtocol
                private let errorProcessor: ErrorProcessor
                init(_ wrapped: FooProtocol, errorProcessor: ErrorProcessor) {
                    self.wrapped = wrapped
                    self.errorProcessor = errorProcessor
                }
                func foo(_ arg1: String, arg2: Double) throws -> Int {
                    do {
                        return try wrapped.foo(arg1, arg2: arg2)
                    } catch {
                        throw errorProcessor(error)
                    }
                }
            }
            
            extension FooProtocol {
                func catchable(errorProcessor: ErrorProcessor) -> FooProtocol {
                    CatchableDecorator(self, errorProcessor: errorProcessor)
                }
            }
            """,
            macros: testMacros
        )
    }

    // MARK: Throws + Async

    func testFuncTwoParamsAsyncThrowsReturnsInt() {
        assertMacroExpansion(
            """
            @Catchable
            protocol FooProtocol {
                func foo(arg1: String, arg2: Double) async throws -> Int
            }
            """,
            expandedSource:
            """
            protocol FooProtocol {
                func foo(arg1: String, arg2: Double) async throws -> Int
            }
            
            private final class CatchableDecorator: FooProtocol {
                private let wrapped: FooProtocol
                private let errorProcessor: ErrorProcessor
                init(_ wrapped: FooProtocol, errorProcessor: ErrorProcessor) {
                    self.wrapped = wrapped
                    self.errorProcessor = errorProcessor
                }
                func foo(arg1: String, arg2: Double) async throws -> Int {
                    do {
                        return try await wrapped.foo(arg1: arg1, arg2: arg2)
                    } catch {
                        throw errorProcessor(error)
                    }
                }
            }
            
            extension FooProtocol {
                func catchable(errorProcessor: ErrorProcessor) -> FooProtocol {
                    CatchableDecorator(self, errorProcessor: errorProcessor)
                }
            }
            """,
            macros: testMacros
        )
    }

    // MARK: Actors

    func testFuncMainActorNoParamsReturnsVoid() {
        assertMacroExpansion(
            """
            @Catchable
            protocol FooProtocol {
                @MainActor func foo()
            }
            """,
            expandedSource:
            """
            protocol FooProtocol {
                @MainActor func foo()
            }
            
            private final class CatchableDecorator: FooProtocol {
                private let wrapped: FooProtocol
                private let errorProcessor: ErrorProcessor
                init(_ wrapped: FooProtocol, errorProcessor: ErrorProcessor) {
                    self.wrapped = wrapped
                    self.errorProcessor = errorProcessor
                }
                @MainActor func foo() {
                    wrapped.foo()
                }
            }
            
            extension FooProtocol {
                func catchable(errorProcessor: ErrorProcessor) -> FooProtocol {
                    CatchableDecorator(self, errorProcessor: errorProcessor)
                }
            }
            """,
            macros: testMacros
        )
    }
}
