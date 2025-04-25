public enum Messages {
    public static let refreshShell = """
    NOTE: Swiftly has updated some elements in your path and your shell may not yet be
    aware of the changes. You can update your shell's environment by running

    hash -r

    or restarting your shell.

    """

    public static let unlinkSuccess = """
    Swiftly is now unlinked and will not manage the active toolchain until the following command is run:

        $ swiftly link

    """

    public static func postInstall(_ command: String) -> String {
        """
        There are some dependencies that should be installed before using this toolchain.
        You can run the following script as the system administrator (e.g. root) to prepare
        your system:

            \(command)

        """
    }
}
