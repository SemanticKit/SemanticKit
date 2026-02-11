import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct SemanticKitMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        IRIMacro.self
    ]
}
