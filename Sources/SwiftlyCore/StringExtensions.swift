import Foundation

extension String {
    func wrapText(to columns: Int) -> String {
        guard columns > 0 else { return self }

        var result: [Substring] = []
        var current = startIndex

        while current < endIndex {
            if self[current] == "\n" {
                result.append("\n")
                current = index(after: current)
                continue
            }

            let remainingText: String.SubSequence = self[current...]
            let nextNewlineRange = remainingText.range(of: "\n")
            let lineEnd = nextNewlineRange?.lowerBound ?? endIndex

            var lineStart = current

            while lineStart < lineEnd {
                let remainingLength = distance(from: lineStart, to: lineEnd)

                if remainingLength <= columns {
                    result.append(self[lineStart..<lineEnd])
                    lineStart = lineEnd
                    continue
                }

                let chunkEnd = index(lineStart, offsetBy: columns + 1, limitedBy: lineEnd) ?? lineEnd
                let chunkLength = distance(from: lineStart, to: chunkEnd)

                if chunkLength <= columns {
                    result.append(self[lineStart..<chunkEnd])
                    lineStart = chunkEnd
                    continue
                }

                let nextCharIndex = index(lineStart, offsetBy: columns)

                if self[nextCharIndex].isWhitespace && self[nextCharIndex] != "\n" {
                    result.append(self[lineStart..<nextCharIndex])
                    result.append("\n")
                    lineStart = self.skipWhitespace(from: index(after: nextCharIndex))
                } else {
                    var lastWhitespace: String.Index?
                    var searchIndex = nextCharIndex

                    while searchIndex > lineStart {
                        let prevIndex = index(before: searchIndex)
                        if self[prevIndex].isWhitespace && self[prevIndex] != "\n" {
                            lastWhitespace = prevIndex
                            break
                        }
                        searchIndex = prevIndex
                    }

                    if let lastWS = lastWhitespace {
                        result.append(self[lineStart..<lastWS])
                        result.append("\n")
                        lineStart = self.skipWhitespace(from: index(after: lastWS))
                    } else {
                        let wordEndRange = self[lineStart...].rangeOfCharacter(from: .whitespacesAndNewlines)
                        let wordEnd = wordEndRange?.lowerBound ?? lineEnd

                        result.append(self[lineStart..<wordEnd])
                        if wordEnd < lineEnd && self[wordEnd] != "\n" {
                            result.append("\n")
                            lineStart = self.skipWhitespace(from: index(after: wordEnd))
                        } else {
                            lineStart = wordEnd
                        }
                    }
                }
            }

            current = lineEnd
        }

        return result.joined()
    }

    private func skipWhitespace(from index: String.Index) -> String.Index {
        guard index < endIndex else { return index }

        let remainingRange = index..<endIndex
        let nonWhitespaceRange = rangeOfCharacter(
            from: CharacterSet.whitespacesAndNewlines.inverted.union(CharacterSet.newlines),
            range: remainingRange
        )

        if let nonWhitespaceStart = nonWhitespaceRange?.lowerBound {
            if self[nonWhitespaceStart] == "\n" {
                return nonWhitespaceStart // Stop at newline
            }
            return nonWhitespaceStart
        } else {
            return endIndex
        }
    }
}
