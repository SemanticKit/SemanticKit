import Foundation
import SwiftUI
import UniformTypeIdentifiers
import SemanticKit

@main
struct SemanticKitGraphViewerApp: App {
    @StateObject private var graphStore = GraphStore()
    @State private var isImporting = false
    @State private var isExporting = false
    @State private var errorMessage: String?

    var body: some Scene {
        WindowGroup {
            GraphSidebarView(graph: graphStore.graph)
                .toolbar {
                    ToolbarItemGroup {
                        Button {
                            isImporting = true
                        } label: {
                            Label("Import", systemImage: "square.and.arrow.down")
                        }

                        Button {
                            isExporting = true
                        } label: {
                            Label("Export", systemImage: "square.and.arrow.up")
                        }
                    }
                }
                .fileImporter(
                    isPresented: $isImporting,
                    allowedContentTypes: [.turtle],
                    allowsMultipleSelection: false
                ) { result in
                    switch result {
                    case .success(let urls):
                        if let url = urls.first {
                            importGraph(from: url)
                        }
                    case .failure(let error):
                        errorMessage = error.localizedDescription
                    }
                }
                .fileExporter(
                    isPresented: $isExporting,
                    document: TurtleDocument(graph: graphStore.graph),
                    contentType: .turtle,
                    defaultFilename: "graph"
                ) { result in
                    if case .failure(let error) = result {
                        errorMessage = error.localizedDescription
                    }
                }
                .alert("File Error", isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { _ in errorMessage = nil }
                )) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(errorMessage ?? "Unknown error.")
                }
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button("Import Turtle…") {
                    isImporting = true
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])

                Button("Export Turtle…") {
                    isExporting = true
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
            }
        }
    }

    private func importGraph(from url: URL) {
        do {
            let data = try Data(contentsOf: url)
            guard let text = String(data: data, encoding: .utf8) else {
                errorMessage = "Unable to read file as UTF-8 text."
                return
            }
            graphStore.graph = try Graph(turtle: text)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private enum SampleGraphBuilder {
    static func make() -> Graph {
        var graph = Graph()

        do {
            guard
                let alice = try? IRI(iriString: "https://example.com/alice"),
                let knows = try? IRI(iriString: "https://example.com/knows"),
                let name = try? IRI(iriString: "https://schema.org/name"),
                let age = try? IRI(iriString: "https://schema.org/age"),
                let rdfType = try? IRI(iriString: "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"),
                let schemaPerson = try? IRI(iriString: "https://schema.org/Person"),
                let xsdInteger = try? IRI(iriString: "http://www.w3.org/2001/XMLSchema#integer")
            else {
                return graph
            }

            let bob = try BlankNode("b1")
            let aliceName = try Literal("Alice", languageTag: "en")
            let aliceAge = try Literal("29", datatype: xsdInteger)
            let aliceSubject = try AnyRDFSubject(alice)

            let triples = [
                Triple(subject: aliceSubject, predicate: rdfType, object: AnyRDFObject(schemaPerson)),
                Triple(subject: aliceSubject, predicate: knows, object: AnyRDFObject(bob)),
                Triple(subject: aliceSubject, predicate: name, object: AnyRDFObject(aliceName)),
                Triple(subject: aliceSubject, predicate: age, object: AnyRDFObject(aliceAge))
            ]

            for triple in triples {
                try? graph.insert(triple)
            }
        } catch {
            return graph
        }

        return graph
    }
}

private final class GraphStore: ObservableObject {
    @Published var graph: Graph = SampleGraphBuilder.make()
}

private struct TurtleDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.turtle] }

    let turtle: String

    init(graph: Graph) {
        self.turtle = graph.turtleString()
    }

    init(configuration: ReadConfiguration) throws {
        let data = configuration.file.regularFileContents ?? Data()
        self.turtle = String(data: data, encoding: .utf8) ?? ""
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = Data(turtle.utf8)
        return FileWrapper(regularFileWithContents: data)
    }
}

private extension UTType {
    static let turtle = UTType(filenameExtension: "ttl") ?? .plainText
}
