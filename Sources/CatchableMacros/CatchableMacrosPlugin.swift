import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct CatchablePlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        CatchableMacro.self,
    ]
}
