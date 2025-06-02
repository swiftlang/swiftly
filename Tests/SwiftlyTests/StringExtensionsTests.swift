@testable import SwiftlyCore
import Testing

@Suite struct StringExtensionsTests {
    @Test("Basic text wrapping at column width")
    func testBasicWrapping() {
        let input = "This is a simple test string that should be wrapped at the specified width."
        let expected = """
        This is a
        simple test
        string that
        should be
        wrapped at
        the
        specified
        width.
        """

        #expect(input.wrapText(to: 10) == expected)
    }

    @Test("Preserve existing line breaks")
    func testPreserveLineBreaks() {
        let input = "First line\nSecond line\nThird line"
        let expected = "First line\nSecond line\nThird line"

        #expect(input.wrapText(to: 20) == expected)
    }

    @Test("Combine wrapping with existing line breaks")
    func testCombineWrappingAndLineBreaks() {
        let input = "Short line\nThis is a very long line that needs to be wrapped\nAnother short line"
        let expected = """
        Short line
        This is a very
        long line that
        needs to be
        wrapped
        Another short line
        """

        #expect(input.wrapText(to: 15) == expected)
    }

    @Test("Words longer than column width")
    func testLongWords() {
        let input = "This has a supercalifragilisticexpialidocious word"
        let expected = """
        This has a
        supercalifragilisticexpialidocious
        word
        """

        #expect(input.wrapText(to: 10) == expected)
    }

    @Test("Text with no spaces")
    func testNoSpaces() {
        let input = "ThisIsALongStringWithNoSpaces"
        let expected = "ThisIsALongStringWithNoSpaces"

        #expect(input.wrapText(to: 10) == expected)
    }

    @Test("Empty string")
    func testEmptyString() {
        let input = ""
        let expected = ""

        #expect(input.wrapText(to: 10) == expected)
    }

    @Test("Single character")
    func testSingleCharacter() {
        let input = "X"
        let expected = "X"

        #expect(input.wrapText(to: 10) == expected)
    }

    @Test("Single line not exceeding width")
    func testSingleLineNoWrapping() {
        let input = "Short text"
        let expected = "Short text"

        #expect(input.wrapText(to: 10) == expected)
    }

    @Test("Wrapping with indentation")
    func testWrappingWithIndent() {
        let input = "This is text that should be wrapped with indentation on new lines."
        let expected = """
        This is
          text that
          should be
          wrapped
          with
          indentation
          on new
          lines.
        """

        #expect(input.wrapText(to: 20, wrappingIndent: 2) == expected)
    }

    @Test("Zero or negative column width")
    func testZeroOrNegativeWidth() {
        let input = "This should not be wrapped"

        #expect(input.wrapText(to: 0) == input)
        #expect(input.wrapText(to: -5) == input)
    }

    @Test("Very narrow column width")
    func testVeryNarrowWidth() {
        let input = "A B C"
        let expected = "A\nB\nC"

        #expect(input.wrapText(to: 1) == expected)
    }

    @Test("Special characters")
    func testSpecialCharacters() {
        let input = "Special !@#$%^&*() chars"
        let expected = """
        Special
        !@#$%^&*()
        chars
        """

        #expect(input.wrapText(to: 10) == expected)
    }

    @Test("Unicode characters")
    func testUnicodeCharacters() {
        let input = "Unicode: 你好世界 😀🚀🌍"
        let expected = """
        Unicode: 你好世界
        😀🚀🌍
        """

        #expect(input.wrapText(to: 15) == expected)
    }

    @Test("Irregular spacing")
    func testIrregularSpacing() {
        let input = "Words  with    irregular     spacing"
        let expected = """
        Words  with
        irregular
        spacing
        """

        #expect(input.wrapText(to: 10) == expected)
    }

    @Test("Tab characters")
    func testTabCharacters() {
        let input = "Text\twith\ttabs"
        let expected = """
        Text\twith
        \ttabs
        """

        #expect(input.wrapText(to: 10) == expected)
    }

    @Test("Trailing spaces")
    func testTrailingSpaces() {
        let input = "Text with  trailing spaces  "
        let expected = """
        Text with
        trailing
        spaces
        """

        #expect(input.wrapText(to: 10) == expected)
    }

    @Test("Leading spaces")
    func testLeadingSpaces() {
        let input = "  Leading spaces with text"
        let expected = """
          Leading
        spaces with
        text
        """

        #expect(input.wrapText(to: 10) == expected)
    }

    @Test("Multiple consecutive newlines")
    func testMultipleNewlines() {
        let input = "First\n\nSecond\n\n\nThird"
        let expected = "First\n\nSecond\n\n\nThird"

        #expect(input.wrapText(to: 10) == expected)
    }

    @Test("Edge case - exactly at column width")
    func testExactColumnWidth() {
        let input = "1234567890 abcdefghij"
        let expected = "1234567890\nabcdefghij"

        #expect(input.wrapText(to: 10) == expected)
    }
}
