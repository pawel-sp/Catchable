public protocol ErrorProcessor: Sendable {
    func callAsFunction(_ error: Error) -> Error
}

@attached(peer, names: named(CatchableDecorator))
@attached(extension, names: named(catchable(errorProcessor:)))
public macro Catchable() = #externalMacro(module: "CatchableMacros", type: "CatchableMacro")
