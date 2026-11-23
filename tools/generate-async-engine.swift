// generate-async-engine.swift
//
// Generates the async mirror of SzEngine:
//
//   Sources/SenzingSDK/SzEngine.swift            (the protocol requirements)
//   Sources/SenzingSDK/SzEngine+Defaults.swift   (the same, with default arguments)
//   Sources/SenzingSDK/SzEngine+Typed.swift      (the Codable variants)
//     -> Sources/SenzingSDK/Generated/SzAsyncEngine+Engine.swift
//
// Every SzEngine method gets an `async` counterpart on SzAsyncEngine with the
// same name, labels and defaults, forwarding through `perform`. Generic
// parameters gain `& Sendable`. CI regenerates the file and fails if it
// drifts, so a new SzEngine method cannot lack its async counterpart.
//
// Usage (from the repository root):
//
//   swift tools/generate-async-engine.swift [<sources directory>]

import Foundation

struct Declaration {
    let name: String
    let generics: String
    let parameters: [String]
    let returnType: String?
    let discardable: Bool

    /// The argument labels, `_` for unlabeled parameters.
    var labels: [String] {
        parameters.map { parameter in
            let head = parameter.split(separator: ":", maxSplits: 1)[0]
            return String(head.split(separator: " ")[0])
        }
    }

    var key: String {
        "\(name)(\(labels.map { "\($0):" }.joined()))"
    }

    /// The call forwarding each parameter to the engine.
    var call: String {
        let arguments = parameters.map { parameter -> String in
            let words = parameter.split(separator: ":", maxSplits: 1)[0].split(separator: " ")
            let name = words.count > 1 ? words[1] : words[0]
            return words[0] == "_" ? "\(name)" : "\(words[0]): \(name)"
        }
        return "engine.\(name)(\(arguments.joined(separator: ", ")))"
    }
}

/// Splits `text` at top-level commas (outside (), [] and <>).
func splitTopLevel(_ text: String) -> [String] {
    var parts: [String] = []
    var depth = 0
    var current = ""
    for character in text {
        switch character {
        case "(", "[", "<": depth += 1
        case ")", "]", ">": depth -= 1
        default: break
        }
        if character == "," && depth == 0 {
            parts.append(current)
            current = ""
        } else {
            current.append(character)
        }
    }
    parts.append(current)
    return parts.map { $0.split(whereSeparator: \.isWhitespace).joined(separator: " ") }.filter { !$0.isEmpty }
}

/// The `func` declarations in a source file: protocol requirements, or the
/// `public func`s of an extension.
func declarations(in url: URL, publicOnly: Bool) throws -> [Declaration] {
    let text = try String(contentsOf: url, encoding: .utf8)
    let pattern =
        publicOnly
        ? #"(?m)^(\s*@discardableResult\s*\n)?\s*public func "# : #"(?m)^(\s*@discardableResult\s*\n)?\s*func "#
    let regex = try NSRegularExpression(pattern: pattern)
    let source = text as NSString
    var result: [Declaration] = []
    for match in regex.matches(in: text, range: NSRange(location: 0, length: source.length)) {
        let discardable = match.range(at: 1).location != NSNotFound
        var index = text.index(text.startIndex, offsetBy: match.range.upperBound)
        let nameStart = index
        while text[index] != "(" && text[index] != "<" {
            index = text.index(after: index)
        }
        let name = String(text[nameStart..<index])
        var generics = ""
        if text[index] == "<" {
            guard let close = text[index...].firstIndex(of: ">") else {
                throw CocoaError(.formatting, userInfo: [NSDebugDescriptionErrorKey: "Unclosed generics in \(name)"])
            }
            generics = String(text[index...close])
            index = text.index(after: close)
        }
        // The parameter list, to its matching parenthesis.
        var depth = 0
        let open = index
        repeat {
            if text[index] == "(" { depth += 1 }
            if text[index] == ")" { depth -= 1 }
            index = text.index(after: index)
        } while depth > 0
        let parameters = splitTopLevel(String(text[text.index(after: open)..<text.index(before: index)]))
        // `throws(SzError)` and an optional `-> Type`, up to a body or line end.
        let rest = String(text[index...])
        let signature = try NSRegularExpression(pattern: #"^\s*throws\(SzError\)\s*(->\s*([^\{\n]+?))?\s*(\{|\n)"#)
        guard let tail = signature.firstMatch(in: rest, range: NSRange(location: 0, length: (rest as NSString).length))
        else {
            throw CocoaError(.formatting, userInfo: [NSDebugDescriptionErrorKey: "Cannot parse \(name) in \(url.path)"])
        }
        let returnRange = tail.range(at: 2)
        let returnType = returnRange.location == NSNotFound ? nil : (rest as NSString).substring(with: returnRange)
        result.append(
            Declaration(
                name: name,
                generics: generics,
                parameters: parameters,
                returnType: returnType,
                discardable: discardable
            )
        )
    }
    return result
}

/// `<T: Decodable>` -> `<T: Decodable & Sendable>`.
func sendableGenerics(_ generics: String) -> String {
    guard !generics.isEmpty else {
        return ""
    }
    let inner = generics.dropFirst().dropLast()
    let constrained = splitTopLevel(String(inner)).map { "\($0) & Sendable" }
    return "<" + constrained.joined(separator: ", ") + ">"
}

func render(_ declaration: Declaration) -> String {
    var out = "    /// Async ``SzEngine/\(declaration.key)``.\n"
    if declaration.discardable {
        out += "    @discardableResult\n"
    }
    let returns = declaration.returnType.map { " -> \($0)" } ?? ""
    let head = "    public func \(declaration.name)\(sendableGenerics(declaration.generics))("
    let oneLine = head + declaration.parameters.joined(separator: ", ") + ") async throws\(returns) {"
    if oneLine.count <= 120 {
        out += oneLine + "\n"
    } else {
        out += head + "\n"
        out += declaration.parameters.map { "        \($0)" }.joined(separator: ",\n") + "\n"
        out += "    ) async throws\(returns) {\n"
    }
    let call = "            try \(declaration.call)"
    if call.count <= 120 {
        out += "        try await perform { engine in\n\(call)\n        }\n"
    } else {
        let arguments = String(declaration.call.dropFirst("engine.\(declaration.name)(".count).dropLast())
        out += "        try await perform { engine in\n            try engine.\(declaration.name)(\n"
        out += splitTopLevel(arguments).map { "                \($0)" }.joined(separator: ",\n") + "\n"
        out += "            )\n        }\n"
    }
    out += "    }\n"
    return out
}

let sources = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Sources/SenzingSDK")
do {
    let requirements = try declarations(in: sources.appendingPathComponent("SzEngine.swift"), publicOnly: false)
    let defaults = try declarations(in: sources.appendingPathComponent("SzEngine+Defaults.swift"), publicOnly: true)
    let typed = try declarations(in: sources.appendingPathComponent("SzEngine+Typed.swift"), publicOnly: true)
    let withDefaults = Dictionary(defaults.map { ($0.key, $0) }, uniquingKeysWith: { first, _ in first })
    var emitted = Set<String>()
    var ordered: [Declaration] = []
    func emit(_ declaration: Declaration) {
        if emitted.insert(declaration.key).inserted {
            ordered.append(declaration)
        }
    }
    for requirement in requirements {
        emit(withDefaults[requirement.key] ?? requirement)
        typed.filter { $0.name == requirement.name }.forEach(emit)
    }
    defaults.forEach(emit)
    typed.forEach(emit)

    var out = """
        // @generated by tools/generate-async-engine.swift. DO NOT EDIT.
        //
        // Regenerate after changing SzEngine with:
        //   swift tools/generate-async-engine.swift

        extension SzAsyncEngine {

        """
    out += ordered.map(render).joined(separator: "\n")
    out += "}\n"
    let output = sources.appendingPathComponent("Generated/SzAsyncEngine+Engine.swift")
    try out.write(to: output, atomically: true, encoding: .utf8)
    print("Generated \(output.path): \(ordered.count) async methods")
} catch {
    FileHandle.standardError.write(Data("error: \(error)\n".utf8))
    exit(1)
}
