import Foundation
import SemanticKit

/// An RDF document in `Fixtures`, read as text and decoded at the boundary.
enum Fixture {
    static func text(_ name: String) throws -> String {
        let url = URL(filePath: #filePath).deletingLastPathComponent().appending(path: "Fixtures/\(name)")
        return try String(contentsOf: url, encoding: .utf8)
    }

    static func turtle(_ name: String) throws -> Graph {
        try TurtleDecoder().decode(try text(name))
    }

    static func nTriples(_ name: String) throws -> Graph {
        try NTriplesDecoder().decode(try text(name))
    }
}
