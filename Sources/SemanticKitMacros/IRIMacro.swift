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
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let arguments = node.arguments?.as(LabeledExprListSyntax.self),
              let first = arguments.first,
              let literal = first.expression.as(StringLiteralExprSyntax.self)
        else {
            throw IRIMacroError.message("@IRI requires a string literal.")
        }

        let value = literal.segments.compactMap { segment -> String? in
            if let stringSegment = segment.as(StringSegmentSyntax.self) {
                return stringSegment.content.text
            }
            return nil
        }.joined()

        if declaration.is(ProtocolDeclSyntax.self) {
            return [DeclSyntax("static var iri: String { get }")]
        }

        return [DeclSyntax("public static let iri: String = \"\(raw: value)\"")]
    }
}
