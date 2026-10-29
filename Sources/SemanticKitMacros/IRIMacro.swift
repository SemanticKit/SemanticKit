import IRIKit
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

enum IRIMacroError: Error, CustomStringConvertible {
    case message(String)

    var description: String {
        switch self {
        case .message(let message):
            return message
        }
    }
}

public struct IRIMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let arguments = node.arguments?.as(LabeledExprListSyntax.self),
              let first = arguments.first,
              let literal = first.expression.as(StringLiteralExprSyntax.self),
              let value = literal.representedLiteralValue
        else {
            throw IRIMacroError.message("@IRI requires a string literal without interpolation.")
        }

        if declaration.is(ProtocolDeclSyntax.self) {
            return [DeclSyntax("static var iri: IRIKit.IRI { get }")]
        }

        do {
            _ = try IRIKit.IRI(validating: value)
        } catch {
            throw IRIMacroError.message("@IRI requires an absolute IRI; \"\(value)\" is not one.")
        }

        return [DeclSyntax("public static let iri: IRIKit.IRI = \(literal)")]
    }
}
