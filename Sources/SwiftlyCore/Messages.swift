public enum Messages {
    public static let unlinkSuccess = """
    Swiftly is now unlinked and will not manage the active toolchain until the following
    command is run:

        $ swiftly link


    """

    public static let currentlyUnlinked = """
    Swiftly is currently unlinked and will not manage the active toolchain. You can run
    the following command to link swiftly to the active toolchain:

        $ swiftly link


    """

    public static func postInstall(_ command: String) -> String {
        """
        There are some dependencies that should be installed before using this toolchain.
        You can run the following script as the system administrator (e.g. root) to prepare
        your system:

            $ \(command)

        """
    }

    public static func refreshShell(_ command: String) -> String {
        """
        NOTE: Swiftly has updated some elements in your PATH and your shell may not yet be
        aware of the changes. You can update your shell's environment by running

            $ \(command)

        or restarting your shell.

        """
    }
}
