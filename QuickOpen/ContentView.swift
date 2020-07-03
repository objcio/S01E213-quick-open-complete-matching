import SwiftUI
import Cocoa
import OSLog

let log = OSLog(subsystem: "objc.io", category: "FuzzyMatch")

struct Score {
    private(set) var value: Int = 0
    private var log: [(Int, String)] = []
    var explanation: String {
        log.map { "\($0.0):\t\($0.1)"}.joined(separator: "\n")
    }
    
    mutating func add(_ amount: Int, reason: String) {
        value += amount
        log.append((amount, reason))
    }
    
    mutating func add(_ other: Score) {
        value += other.value
        log.append(contentsOf: other.log)
    }
}

extension Score: Comparable {
    static func < (lhs: Score, rhs: Score) -> Bool {
        lhs.value < rhs.value
    }
    
    static func == (lhs: Score, rhs: Score) -> Bool {
        lhs.value == rhs.value
    }
}

extension Substring {
    func fuzzyMatch2(_ needle: Substring, gap: Int?) -> Score? {
        guard !needle.isEmpty else { return Score() }
        guard !self.isEmpty else { return nil }
        let skipScore = { self.dropFirst().fuzzyMatch2(needle, gap: gap.map { $0  + 1}) }
        if self.first == needle.first {
            guard let s = dropFirst().fuzzyMatch2(needle.dropFirst(), gap: 0) else { return nil }

            var acceptScore = Score()
            if let g = gap, g > 0 {
                acceptScore.add(-g, reason: "Gap \(g)")
            }
            acceptScore.add(1, reason: "Match \(first!)")
            acceptScore.add(s)
            
            guard let skip = skipScore() else { return acceptScore }
            return Swift.max(skip, acceptScore)
        } else {
            return skipScore()
        }
    }
}

extension String {
    func fuzzyMatch(_ needle: String) -> (score: Score, indices: [String.Index])? {
        var ixs: [Index] = []
        var score = Score()
        if needle.isEmpty { return (score, []) }
        var remainder = needle[...].utf8
        var gap = 0
        for idx in utf8.indices {
            let char = utf8[idx]
            if char == remainder[remainder.startIndex] {
                if gap > 0, !ixs.isEmpty {
                    score.add(-gap, reason: "Gap \(gap)")
                }
                score.add(1, reason: "Match \(String(decoding: [char], as: UTF8.self))")
                gap = 0
                ixs.append(idx)
                remainder.removeFirst()
                if remainder.isEmpty { return (score, ixs) }
            } else {
                gap += 1
            }
        }
        return nil
    }
}

let demoFiles: [String] = [
    "module/string.swift",
    "source/string.swift",
    "str/testing.swift"
]

struct ContentView: View {
    @State var needle: String = ""
    
    var filtered: [(string: String, score: Score, indices: [String.Index])] {
        os_signpost(.begin, log: log, name: "Search", "%@", needle)
        defer { os_signpost(.end, log: log, name: "Search", "%@", needle) }
        let needleS = needle[...]
        return files.compactMap {
            guard let match = $0[...].fuzzyMatch2(needleS, gap: nil) else { return nil }
            return ($0, match, [])
        }.sorted { $0.score.value > $1.score.value }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Image(nsImage: search)
                    .padding(.leading, 10)
                TextField("", text: $needle).textFieldStyle(PlainTextFieldStyle())
                    .padding(10)
                    .font(.subheadline)
                Button(action: {
                    self.needle = ""
                }, label: {
                    Image(nsImage: close)
                        .padding()
                }).disabled(needle.isEmpty)
                .buttonStyle(BorderlessButtonStyle())
            }
            List(filtered.prefix(30), id: \.string) { result in
                HStack {
                    Text("\(result.score.value)")
                    highlight(string: result.string, indices: result.indices)
                    Text(result.score.explanation)
                }
            }
        }
    }
}

func highlight(string: String, indices: [String.Index]) -> Text {
    var result = Text("")
    for i in string.indices {
        let char = Text(String(string[i]))
        if indices.contains(i) {
            result = result + char.bold()
        } else {
            result = result + char.foregroundColor(.secondary)
        }
    }
    return result
}


// Hack to disable the focus ring
extension NSTextField {
    open override var focusRingType: NSFocusRingType {
        get { .none }
        set { }
    }
}

let close: NSImage = NSImage(named: "NSStopProgressFreestandingTemplate")!
let search: NSImage = NSImage(named: "NSTouchBarSearchTemplate")!
