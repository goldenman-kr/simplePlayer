import Foundation

enum SubtitleFormat: String {
    case srt = "SRT"
    case smi = "SMI"
}

struct SubtitleCue: Identifiable, Equatable {
    let id: Int
    let startTime: Double
    let endTime: Double
    let text: String
}

struct SubtitleTrack: Equatable {
    let url: URL
    let format: SubtitleFormat
    let cues: [SubtitleCue]

    var displayName: String {
        url.lastPathComponent
    }

    func cue(at time: Double) -> SubtitleCue? {
        guard !cues.isEmpty else { return nil }

        var low = 0
        var high = cues.count - 1

        while low <= high {
            let mid = (low + high) / 2
            let cue = cues[mid]

            if time < cue.startTime {
                high = mid - 1
            } else if time >= cue.endTime {
                low = mid + 1
            } else {
                return cue
            }
        }

        return nil
    }
}

enum SubtitleParserError: LocalizedError {
    case unsupportedFormat
    case unreadableText
    case noCues

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat:
            return "Unsupported subtitle format."
        case .unreadableText:
            return "Could not read the subtitle text."
        case .noCues:
            return "No subtitle cues were found."
        }
    }
}

enum SubtitleParser {
    static func parse(url: URL) throws -> SubtitleTrack {
        let format: SubtitleFormat
        switch url.pathExtension.lowercased() {
        case "srt":
            format = .srt
        case "smi":
            format = .smi
        default:
            throw SubtitleParserError.unsupportedFormat
        }

        let data = try Data(contentsOf: url)
        guard let text = decode(data: data) else {
            throw SubtitleParserError.unreadableText
        }

        let cues: [SubtitleCue]
        switch format {
        case .srt:
            cues = parseSRT(text)
        case .smi:
            cues = parseSMI(text)
        }

        guard !cues.isEmpty else {
            throw SubtitleParserError.noCues
        }

        return SubtitleTrack(url: url, format: format, cues: cues)
    }

    private static func decode(data: Data) -> String? {
        let koreanEncoding = String.Encoding(
            rawValue: CFStringConvertEncodingToNSStringEncoding(
                CFStringEncoding(CFStringEncodings.EUC_KR.rawValue)
            )
        )
        let encodings: [String.Encoding] = [
            .utf8,
            .utf16,
            .utf16LittleEndian,
            .utf16BigEndian,
            koreanEncoding,
            .isoLatin1
        ]

        for encoding in encodings {
            if let text = String(data: data, encoding: encoding) {
                return text
            }
        }

        return nil
    }

    private static func parseSRT(_ text: String) -> [SubtitleCue] {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let blocks = normalized.components(separatedBy: "\n\n")
        var cues: [SubtitleCue] = []

        for block in blocks {
            let lines = block
                .split(separator: "\n", omittingEmptySubsequences: false)
                .map(String.init)
            guard let timeLineIndex = lines.firstIndex(where: { $0.contains("-->") }) else {
                continue
            }

            let parts = lines[timeLineIndex].components(separatedBy: "-->")
            guard parts.count >= 2,
                  let start = parseTimestamp(parts[0]),
                  let end = parseTimestamp(parts[1]) else {
                continue
            }

            let body = lines
                .dropFirst(timeLineIndex + 1)
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !body.isEmpty, end > start else {
                continue
            }

            cues.append(SubtitleCue(id: cues.count, startTime: start, endTime: end, text: body))
        }

        return cues
    }

    private static func parseTimestamp(_ value: String) -> Double? {
        let cleaned = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        let pieces = cleaned.components(separatedBy: ":")
        guard pieces.count == 3,
              let hours = Double(pieces[0]),
              let minutes = Double(pieces[1]),
              let seconds = Double(pieces[2].components(separatedBy: " ").first ?? "") else {
            return nil
        }

        return hours * 3600 + minutes * 60 + seconds
    }

    private static func parseSMI(_ text: String) -> [SubtitleCue] {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let pattern = "(?is)<sync\\s+[^>]*start\\s*=\\s*[\"']?(\\d+)[\"']?[^>]*>(.*?)(?=<sync\\s|</body|</sami|$)"

        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return []
        }

        let nsText = normalized as NSString
        let matches = regex.matches(in: normalized, range: NSRange(location: 0, length: nsText.length))
        var startsAndTexts: [(start: Double, text: String)] = []

        for match in matches {
            guard match.numberOfRanges >= 3,
                  let startRange = Range(match.range(at: 1), in: normalized),
                  let bodyRange = Range(match.range(at: 2), in: normalized),
                  let milliseconds = Double(normalized[startRange]) else {
                continue
            }

            let body = normalizeSMIBody(String(normalized[bodyRange]))
            startsAndTexts.append((start: milliseconds / 1000.0, text: body))
        }

        var cues: [SubtitleCue] = []
        for index in startsAndTexts.indices {
            let current = startsAndTexts[index]
            let nextStart = index + 1 < startsAndTexts.count ? startsAndTexts[index + 1].start : current.start + 4.0
            guard !current.text.isEmpty, nextStart > current.start else {
                continue
            }

            cues.append(SubtitleCue(id: cues.count, startTime: current.start, endTime: nextStart, text: current.text))
        }

        return cues
    }

    private static func normalizeSMIBody(_ body: String) -> String {
        var text = body
        text = text.replacingOccurrences(of: "(?i)<br\\s*/?>", with: "\n", options: .regularExpression)
        text = text.replacingOccurrences(of: "(?is)<style.*?</style>", with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: "(?is)<script.*?</script>", with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: "(?s)<[^>]+>", with: "", options: .regularExpression)
        text = decodeHTMLEntities(text)
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0.lowercased() != "&nbsp;" }
        return lines.joined(separator: "\n")
    }

    private static func decodeHTMLEntities(_ value: String) -> String {
        var text = value
        let replacements = [
            "&nbsp;": " ",
            "&amp;": "&",
            "&lt;": "<",
            "&gt;": ">",
            "&quot;": "\"",
            "&#39;": "'"
        ]

        for (entity, replacement) in replacements {
            text = text.replacingOccurrences(of: entity, with: replacement, options: .caseInsensitive)
        }

        return text
    }
}
