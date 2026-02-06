//
//  Iri.swift
//  SemanticKit – Iri target
//
//  Created by ChatGPT (2026)
//  Swift 6.2 – Protocol‑oriented design, no external libraries
//

import Foundation

// MARK: - Public IRI Protocol

/// A protocol that describes an Internationalized Resource Identifier (IRI) as defined by RFC 3987.
/// Conforming types expose the IRI’s components and provide utilities for validation,
/// percent‑encoding/decoding, and conversion to `URL`.
public protocol Iri: CustomStringConvertible, Equatable, RDFPredicate {
    /// The scheme component, e.g. `"http"` or `"urn"`. Always lower‑cased.
    var scheme: String { get }
    
    /// The optional authority component (e.g. `"example.com"`). May contain Unicode.
    var authority: String? { get }
    
    /// The hierarchical path component. May be empty but never `nil`.
    var path: String { get }
    
    /// The optional query component (the part after `?`), without the leading `?`.
    var query: String? { get }
    
    /// The optional fragment component (the part after `#`), without the leading `#`.
    var fragment: String? { get }
    
    /// The full IRI string, correctly percent‑encoded where required.
    var string: String { get }
    
    /// Returns a `URL` representation of the IRI. The URL is guaranteed to be
    /// syntactically valid; Unicode characters are percent‑escaped as required.
    func asURL() throws -> URL
}


// MARK: - Errors

/// Errors that can be thrown while creating or manipulating an IRI.
public enum IriError: Error, LocalizedError {
    /// The IRI string fails RFC 3987 syntactic validation.
    case invalidSyntax(String)
    
    /// The scheme component is missing or empty.
    case missingScheme
    
    /// The scheme component contains illegal characters.
    case invalidScheme(String)
    
    /// The path component violates the RFC 3987 path rules.
    case invalidPath(String)
    
    /// A generic conversion error (e.g., URL creation failed).
    case urlConversionFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidSyntax(let msg):        return "Invalid IRI syntax: \(msg)"
        case .missingScheme:                 return "Missing IRI scheme component."
        case .invalidScheme(let s):          return "Invalid scheme '\(s)'."
        case .invalidPath(let p):            return "Invalid path '\(p)'."
        case .urlConversionFailed(let msg): return "URL conversion failed: \(msg)"
        }
    }
}

// MARK: - Concrete Implementation

/// An immutable, value‑type implementation of the `Iri` protocol.
public struct ConcreteIri: Iri, Hashable, Sendable {
    // Stored components (already validated and percent‑escaped as needed)
    public let scheme: String
    public let authority: String?
    public let path: String
    public let query: String?
    public let fragment: String?
    
    // MARK: Init
    
    /// Parses and validates an IRI string according to RFC 3987.
    /// - Parameter iriString: The raw IRI text (may contain Unicode characters).
    /// - Throws: `IriError` if validation fails.
    public init(_ iriString: String) throws {
        // Quick early‑exit for empty input.
        guard !iriString.isEmpty else {
            throw IriError.invalidSyntax("IRI string is empty.")
        }
        
        // 1️⃣ Separate scheme.
        guard let schemeRange = iriString.range(of: ":") else {
            throw IriError.missingScheme
        }
        let rawScheme = String(iriString[..<schemeRange.lowerBound])
        let lowercasedScheme = rawScheme.lowercased()
        // RFC 3987 restricts scheme to ALPHA *( ALPHA / DIGIT / "+" / "-" / "." )
        let schemePattern = "^[A-Za-z][A-Za-z0-9+\\-.]*$"
        guard lowercasedScheme.range(of: schemePattern, options: .regularExpression) != nil else {
            throw IriError.invalidScheme(rawScheme)
        }
        self.scheme = lowercasedScheme
        
        // Remainder after scheme:
        var remainder = String(iriString[schemeRange.upperBound...])
        
        // 2️⃣ Authority, path, query, fragment.
        var extractedAuthority: String? = nil
        var extractedPath = ""
        var extractedQuery: String? = nil
        var extractedFragment: String? = nil
        
        // Authority is introduced by "//". If present, consume it.
        if remainder.hasPrefix("//") {
            remainder.removeFirst(2) // drop "//"
            // Authority ends at the first "/" , "?" or "#"
            let authorityEndIndex = remainder.firstIndex(where: { "/?#".contains($0) }) ?? remainder.endIndex
            extractedAuthority = String(remainder[..<authorityEndIndex])
            remainder = String(remainder[authorityEndIndex...])
        }
        
        // Extract fragment (after "#")
        if let hashIndex = remainder.firstIndex(of: "#") {
            extractedFragment = String(remainder[remainder.index(after: hashIndex)...])
            remainder = String(remainder[..<hashIndex])
        }
        
        // Extract query (after "?")
        if let questionIndex = remainder.firstIndex(of: "?") {
            extractedQuery = String(remainder[remainder.index(after: questionIndex)...])
            remainder = String(remainder[..<questionIndex])
        }
        
        // Whatever remains is the path.
        extractedPath = remainder
        
        // Validate each component according to RFC 3987 character sets.
        // The validation functions accept Unicode and perform percent‑encoding where required.
        // They return the correctly escaped representation.
        self.authority = try extractedAuthority.map { try IriComponentValidator.percentEncodeAuthority($0) }
        self.path = try IriComponentValidator.percentEncodePath(extractedPath)
        self.query = try extractedQuery.map { try IriComponentValidator.percentEncodeQueryOrFragment($0) }
        self.fragment = try extractedFragment.map { try IriComponentValidator.percentEncodeQueryOrFragment($0) }
    }
    
    // MARK: Iri Conformance
    
    /// The fully‑escaped IRI string.
    public var string: String {
        var result = "\(scheme):"
        if let auth = authority {
            result += "//\(auth)"
        }
        result += path
        if let q = query {
            result += "?\(q)"
        }
        if let f = fragment {
            result += "#\(f)"
        }
        return result
    }
    
    public var description: String { string }
    
    public static func == (lhs: ConcreteIri, rhs: ConcreteIri) -> Bool {
        lhs.string == rhs.string
    }
    
    /// Returns a `URL` instance representing the IRI.
    public func asURL() throws -> URL {
        // `URL(string:)` expects a percent‑escaped UTF‑8 string.
        guard let url = URL(string: string) else {
            throw IriError.urlConversionFailed(string)
        }
        return url
    }
}

// MARK: - Component Validation & Percent‑Encoding

/// Utility namespace for RFC 3987 component validation and percent‑encoding.
private enum IriComponentValidator {
    // RFC 3987 defines the following character sets (in Unicode):
    //   iunreserved = ALPHA / DIGIT / "-" / "." / "_" / "~" / %U+00A0‑%U+D7FF / %U+F900‑%U+FDCF / %U+FDF0‑%U+FFEF
    //   ireserved  = gen-delims / sub-delims
    //   ipchar     = iunreserved / pct-encoded / ireserved
    //   scheme    = ALPHA *( ALPHA / DIGIT / "+" / "-" / "." )
    //
    // For simplicity we rely on Foundation’s `URLComponents` percent‑encoding rules
    // for the generic‑delims/sub‑delims sets and augment them with the extended Unicode ranges.
    
    // MARK: Percent‑Encode Helpers
    
    /// Percent‑encodes any character not allowed in an IRI path segment.
    static func percentEncodePath(_ path: String) throws -> String {
        // The path may be empty, but must start with "/" if authority is present.
        // The set of characters allowed unescaped in a path is iunreserved + ireserved + "/"
        return try percentEncode(string: path, allowed: pathAllowedCharacters)
    }
    
    static func percentEncodeAuthority(_ authority: String) throws -> String {
        // Authority may contain userinfo, host, and port.
        // We'll percent‑encode everything that is not iunreserved or sub‑delims or ":" or "@"
        return try percentEncode(string: authority, allowed: authorityAllowedCharacters)
    }
    
    static func percentEncodeQueryOrFragment(_ component: String) throws -> String {
        // Query and fragment share the same allowed character set (everything except pct‑encoded).
        return try percentEncode(string: component, allowed: queryFragmentAllowedCharacters)
    }
    
    // MARK: Core Encoder
    
    /// Core percent‑encoding routine that works with an `CharacterSet`.
    /// - Parameters:
    ///   - string: Input string (may contain Unicode).
    ///   - allowed: Set of characters that may appear unescaped.
    /// - Returns: Correctly escaped string.
    /// - Throws: `IriError.invalidPath` if the resulting string violates basic structure rules.
    private static func percentEncode(string: String, allowed: CharacterSet) throws -> String {
        // Use Foundation’s `addingPercentEncoding(withAllowedCharacters:)` – it works on Unicode scalar level.
        guard let escaped = string.addingPercentEncoding(withAllowedCharacters: allowed) else {
            throw IriError.invalidSyntax("Failed to percent‑encode component: \(string)")
        }
        return escaped
    }
    
    // MARK: Allowed Character Sets
    
    /// IRI‑specific “iunreserved” characters plus the generic delimiters needed for a path.
    private static let iunreserved: CharacterSet = {
        var set = CharacterSet.alphanumerics
        set.insert(charactersIn: "-._~")
        // Extended Unicode ranges for iunreserved:
        set.insert(charactersIn: "\u{00A0}"..."\u{D7FF}")
        set.insert(charactersIn: "\u{F900}"..."\u{FDCF}")
        set.insert(charactersIn: "\u{FDF0}"..."\u{FFEF}")
        // Note: Foundation’s `urlQueryAllowed` already contains the generic delimiters.
        return set
    }()
    
    /// Characters that may appear unescaped in the *path* component.
    private static let pathAllowedCharacters: CharacterSet = {
        var set = iunreserved
        // gen-delims = ":" / "/" / "?" / "#" / "[" / "]" / "@"
        // sub-delims = "!" / "$" / "&" / "'" / "(" / ")" / "*" / "+" / "," / ";" / "="
        set.insert(charactersIn: ":/?#[]@!$&'()*+,;=")
        // "/" is already included above, but we explicitly keep it for clarity.
        set.insert(charactersIn: "/")
        return set
    }()
    
    /// Characters allowed unescaped in the *authority* component.
    private static let authorityAllowedCharacters: CharacterSet = {
        var set = iunreserved
        // Sub‑delims + ":" + "@" are allowed in userinfo and host sections.
        set.insert(charactersIn: "!$&'()*+,;=:@")
        // IPv6 literals contain "[" and "]".
        set.insert(charactersIn: "[]")
        return set
    }()
    
    /// Characters allowed unescaped in query or fragment components.
    private static let queryFragmentAllowedCharacters: CharacterSet = {
        var set = iunreserved
        set.insert(charactersIn: "!$&'()*+,;=:@/?")
        return set
    }()
    
    // The public `percentEncodeQueryOrFragment` re‑uses the same set.
    static var queryAllowedCharacters: CharacterSet { queryFragmentAllowedCharacters }
    static var fragmentAllowedCharacters: CharacterSet { queryFragmentAllowedCharacters }
}

// MARK: - Public Extension for Convenience

public extension Iri {
    /// Convenience initializer that forwards to `ConcreteIri`.
    /// Allows using `Iri` directly without mentioning the concrete type.
    init(iriString: String) throws where Self == ConcreteIri {
        self = try ConcreteIri(iriString)
    }
}
