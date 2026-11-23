// coverage-summary.swift
//
// Prints line coverage per source file from the llvm-cov JSON that
// `swift test --enable-code-coverage` writes, and fails below a minimum.
//
// Usage: swift tools/coverage-summary.swift <codecov.json> [<path fragment>] [<minimum percent>]
//
//   swift tools/coverage-summary.swift "$(swift test --show-codecov-path)" Sources/SenzingSDK/ 100

import Foundation

struct Report: Decodable {
    struct Export: Decodable {
        struct File: Decodable {
            struct Summary: Decodable {
                struct Lines: Decodable {
                    let count: Int
                    let covered: Int
                }
                let lines: Lines
            }
            let filename: String
            let summary: Summary
        }
        let files: [File]
    }
    let data: [Export]
}

let arguments = CommandLine.arguments
guard arguments.count > 1 else {
    FileHandle.standardError.write(Data("usage: coverage-summary.swift <codecov.json> [fragment] [minimum]\n".utf8))
    exit(2)
}
let fragment = arguments.count > 2 ? arguments[2] : "Sources/"
let minimum = arguments.count > 3 ? Double(arguments[3]) ?? 0 : 0

do {
    let report = try JSONDecoder().decode(Report.self, from: Data(contentsOf: URL(fileURLWithPath: arguments[1])))
    let files = report.data.flatMap(\.files).filter { $0.filename.contains(fragment) }
        .sorted { $0.filename < $1.filename }
    var total = 0
    var covered = 0
    for file in files {
        let lines = file.summary.lines
        total += lines.count
        covered += lines.covered
        let percent = lines.count == 0 ? 100 : 100 * Double(lines.covered) / Double(lines.count)
        let name = file.filename.components(separatedBy: fragment).last ?? file.filename
        print(String(format: "%7.2f%%  %5d/%-5d  ", percent, lines.covered, lines.count) + name)
    }
    let percent = total == 0 ? 0 : 100 * Double(covered) / Double(total)
    print(String(format: "%7.2f%%  %5d/%-5d  ", percent, covered, total) + "TOTAL (\(fragment))")
    if files.isEmpty || percent < minimum {
        FileHandle.standardError.write(Data("error: line coverage \(percent)% is below \(minimum)%\n".utf8))
        exit(1)
    }
} catch {
    FileHandle.standardError.write(Data("error: \(error)\n".utf8))
    exit(1)
}
