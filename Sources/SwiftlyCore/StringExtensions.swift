/// A description
extension String {
    /// Wraps text to fit within specified column width
    ///
    /// This method reformats the string to ensure each line fits within the specified column width,
    /// attempting to break at spaces when possible to avoid splitting words.
    ///
    /// - Parameters:
    ///   - columns: Maximum width (in characters) for each line
    ///   - wrappingIndent: Number of spaces to add at the beginning of each wrapped line (not the first line)
    ///
    /// - Returns: A new string with appropriate line breaks to maintain the specified column width
    func wrapText(to columns: Int, wrappingIndent: Int = 0) -> String {
        let effectiveColumns = columns - wrappingIndent
        guard effectiveColumns > 0 else { return self }

        var result: [Substring] = []
        var currentIndex = self.startIndex

        while currentIndex < self.endIndex {
            let nextChunk = self[currentIndex...].prefix(effectiveColumns)

            // Handle line breaks in the current chunk
            if let lastLineBreak = nextChunk.lastIndex(of: "\n") {
                result.append(
                    contentsOf: self[currentIndex..<lastLineBreak].split(
                        separator: "\n", omittingEmptySubsequences: false
                    ))
                currentIndex = self.index(after: lastLineBreak)
                continue
            }

            // We've reached the end of the string
            if nextChunk.endIndex == self.endIndex {
                result.append(self[currentIndex...])
                break
            }

            // Try to break at the last space within the column limit
            if let lastSpace = nextChunk.lastIndex(of: " ") {
                result.append(self[currentIndex..<lastSpace])
                currentIndex = self.index(after: lastSpace)
                continue
            }

            // If no space in the chunk, find the next space after column limit
            if let nextSpace = self[currentIndex...].firstIndex(of: " ") {
                result.append(self[currentIndex..<nextSpace])
                currentIndex = self.index(after: nextSpace)
                continue
            }

            // No spaces left in the string - add the rest and finish
            result.append(self[currentIndex...])
            break
        }

        // Apply indentation to wrapped lines and join them
        return
            result
                .map { $0.isEmpty ? $0 : String(repeating: " ", count: wrappingIndent) + $0 }
                .joined(separator: "\n")
    }
}
