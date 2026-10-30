import SemanticKitMacroImplementations
import SwiftSyntax
import SwiftSyntaxMacros

/// The type the compiler resolves `@IRI` to in this plugin.
///
/// The expansion itself is ``SemanticKitMacroImplementations/IRIMacro``, a plain
/// library the test target can depend on without depending on this macro target.
public struct IRIMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        try SemanticKitMacroImplementations.IRIMacro.expansion(
            of: node,
            providingMembersOf: declaration,
            conformingTo: protocols,
            in: context
        )
    }
}
