import Foundation

/// Protocol retrieving terminal properties
public protocol Terminal: Sendable {
    /// Detects the terminal width in columns
    func width() -> Int
}

public struct SystemTerminal: Terminal {
    /// Detects the terminal width in columns
    public func width() -> Int {
#if os(macOS) || os(Linux)
        var size = winsize()
#if os(OpenBSD)
        // TIOCGWINSZ is a complex macro, so we need the flattened value.
        let tiocgwinsz = UInt(0x4008_7468)
        let result = ioctl(STDOUT_FILENO, tiocgwinsz, &size)
#else
        let result = ioctl(STDOUT_FILENO, UInt(TIOCGWINSZ), &size)
#endif

        if result == 0 && Int(size.ws_col) > 0 {
            return Int(size.ws_col)
        }
#endif
        return 80 // Default width if terminal size detection fails
    }
}
