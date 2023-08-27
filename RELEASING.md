# Releasing swiftly

1. Check out the commit you wish to create a release for. Ensure no other local modifications or changes are present.

1. Ensure the version string in `Swiftly.swift` is accurate. If it is not, push another commit updating it to the proper value.

1. Create a tag on that commit with the format "x.y.z". Do not omit "z", even if its value is 0.

1. Build the executables for the release by running ./scripts/build_release.sh from the root of the swiftly repository (do this once on an x86_64 machine and once on an aarch64 one)

1. Push the tag to `origin`.

1. Go to the GitHub page for the new tag, click edit tag, add an appropriate description, attach the prebuilt executables, and click "Publish Release".
