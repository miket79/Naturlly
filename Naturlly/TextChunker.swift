import Foundation

enum TextChunker {
    static let maxBytes: Int = 4500

    static func effectiveMaxBytes(base: Int = maxBytes, marginPercent: Int = 0, overheadBytes: Int = 0) -> Int {
        let percentReduction = max(0, min(marginPercent, 90)) // cap to avoid zero
        let reduced = base - (base * percentReduction / 100)
        let final = max(512, reduced - max(0, overheadBytes))
        return final
    }

    static func clean(_ text: String) -> String {
        var result = text
        guard !result.isEmpty else { return "" }
        // Normalize newlines
        result = result.replacingOccurrences(of: "\r\n", with: "\n")
                       .replacingOccurrences(of: "\r", with: "\n")
        // Remove soft hyphen
        result = result.replacingOccurrences(of: "\u{00AD}", with: "")
        // Replace newlines with spaces
        result = result.replacingOccurrences(of: "\n", with: " ")
        // Collapse multiple spaces
        while result.contains("  ") {
            result = result.replacingOccurrences(of: "  ", with: " ")
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func split(_ text: String, maxBytes: Int = maxBytes, marginPercent: Int = 0, overheadBytes: Int = 0) -> [String] {
        guard !text.isEmpty else { return [] }
        let limit = effectiveMaxBytes(base: maxBytes, marginPercent: marginPercent, overheadBytes: overheadBytes)
        let cleaned = clean(text)
        guard !cleaned.isEmpty else { return [] }

        let pattern = "[^.!?]+[.!?]?"
        let nsText = cleaned as NSString
        let regex = try? NSRegularExpression(pattern: pattern)
        let matches = regex?.matches(in: cleaned, range: NSRange(location: 0, length: nsText.length)) ?? []
        let sentences = matches
            .map { nsText.substring(with: $0.range).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var chunks: [String] = []
        var current = ""

        func fits(_ s: String) -> Bool { s.utf8.count <= limit }

        func appendHardSplit(_ s: String) {
            var buffer = ""
            for ch in s {
                let test = buffer + String(ch)
                if fits(test) {
                    buffer = test
                } else {
                    if !buffer.isEmpty { chunks.append(buffer) }
                    buffer = String(ch)
                }
            }
            if !buffer.isEmpty { chunks.append(buffer) }
        }

        for sentence in sentences {
            let candidate = current.isEmpty ? sentence : (current + " " + sentence)
            if fits(candidate) {
                current = candidate
            } else {
                if !current.isEmpty { chunks.append(current) }
                if fits(sentence) {
                    current = sentence
                } else {
                    // Split sentence by words, then by chars if needed
                    var partial = ""
                    for word in sentence.split(separator: " ", omittingEmptySubsequences: false) {
                        let w = String(word)
                        let test = partial.isEmpty ? w : partial + " " + w
                        if fits(test) {
                            partial = test
                        } else {
                            if !partial.isEmpty { chunks.append(partial) }
                            if fits(w) {
                                partial = w
                            } else {
                                appendHardSplit(w)
                                partial = ""
                            }
                        }
                    }
                    current = partial
                }
            }
        }
        if !current.isEmpty { chunks.append(current) }

        // Post-validate: ensure no chunk exceeds limit
        var validated: [String] = []
        for s in chunks {
            if s.utf8.count <= limit {
                validated.append(s)
            } else {
                var buf = ""
                for ch in s {
                    let test = buf + String(ch)
                    if test.utf8.count <= limit {
                        buf = test
                    } else {
                        if !buf.isEmpty { validated.append(buf) }
                        buf = String(ch)
                    }
                }
                if !buf.isEmpty { validated.append(buf) }
            }
        }
        return validated.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }
}
