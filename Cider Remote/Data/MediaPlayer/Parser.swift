// Made by Lumaa, ChatGPT & Grok

import Foundation

/// Parses the XML of the `rise.cider.sh` responses
class Parser: NSObject, XMLParserDelegate {
    var lyrics: [LyricLine]
    var provider: Parser.LyricProvider

    private var currentText: String
    private var currentBegin: String?
    private var currentAgent: String?

    init(provider: Parser.LyricProvider, lyrics: [LyricLine] = []) {
        self.provider = provider
        self.lyrics = lyrics
        self.currentText = ""
        self.currentBegin = nil
        self.currentAgent = nil
    }

    func parser(_ parser: XMLParser,
                didStartElement elementName: String,
                namespaceURI: String?,
                qualifiedName qName: String?,
                attributes attributeDict: [String : String] = [:])
    {
        if elementName == "p" {
            // Save the 'begin' time and 'ttm:agent' (if present) when <p> starts, reset text.
            currentBegin = attributeDict["begin"]
            currentAgent = attributeDict["ttm:agent"]
            currentText = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        // Accumulate text (including inside nested tags) for the current <p>.
        currentText += string
    }

    func parser(_ parser: XMLParser,
                didEndElement elementName: String,
                namespaceURI: String?,
                qualifiedName qName: String?)
    {
        if elementName == "p" {
            // We reached </p>, so finalize this lyric line.
            let trimmedText = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
            // Ignore empty lines
            if !trimmedText.isEmpty, let beginString = currentBegin {
                let isMain = trimmedText.hasPrefix("(") && trimmedText.hasSuffix(")")
                var timestamp: Double = 0.0

                let parts = beginString.split(separator: ":")
                if parts.count == 3 {
                    // "HH:MM:SS.mmmm"
                    let hours = Double(parts[0]) ?? 0
                    let minutes = Double(parts[1]) ?? 0
                    let seconds = Double(parts[2].split(separator: ".")[0]) ?? 0
                    let milliseconds = Double(parts[2].split(separator: ".")[1]) ?? 0
                    timestamp = hours * 3600 + minutes * 60 + seconds + milliseconds / 1000
                } else if parts.count == 2 {
                    // "MM:SS.mmmm"
                    let minutes = Double(parts[0]) ?? 0
                    let seconds = Double(parts[1].split(separator: ".")[0]) ?? 0
                    let milliseconds = Double(parts[1].split(separator: ".")[1]) ?? 0
                    timestamp = minutes * 60 + seconds + milliseconds / 1000
                } else if parts.count <= 1 {
                    // "SS.mmmm"
                    let seconds = Double(beginString.split(separator: ".")[0]) ?? 0
                    let milliseconds = Double(beginString.split(separator: ".")[1]) ?? 0
                    timestamp = seconds + milliseconds / 1000
                }

                // Set altVoice based on ttm:agent value: "v1" -> false, "v2" -> true, default to false if not specified
                let altVoice = currentAgent == "v2" ? true : false

                let lyricLine = LyricLine(text: trimmedText,
                                          timestamp: timestamp,
                                          isMainLyric: isMain,
                                          altVoice: altVoice)
                lyrics.append(lyricLine)
            }
            // Reset for next <p>
            currentBegin = nil
            currentAgent = nil
            currentText = ""
        }
    }

    enum LyricProvider {
        case mxm
        case am
        case cache
    }
}
