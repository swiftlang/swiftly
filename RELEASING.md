# Releasing

Swiftly and the swiftly-install release script have different release schedules and their version numbers do not correspond. Below is instructions for releasing each.

## Releasing swiftly

1. Check out the commit you wish to create a release for. Ensure no other local modifications or changes are present.

2. Ensure the version string in `SwiftlyCore/SwiftlyCore.swift` is accurate. If it is not, push another commit updating it to the proper value.

3. Create a tag on that commit with the format "x.y.z". Do not omit "z", even if its value is 0.

4. Build the executables for the release by running ./scripts/build_release.sh from the root of the swiftly repository (do this once on an x86_64 machine and once on an aarch64 one)

5. Push the tag to `origin`. `git push origin <tag_name>`

6. Go to the GitHub page for the new tag, click edit tag, add an appropriate description, attach the prebuilt executables, and click "Publish Release".

## Releasing swiftly-install

1. Check out the commit you wish to create a release for. Ensure no other local modifications or changes are present.

2. Ensure the version string `SWIFTLY_INSTALL_VERSION` in `install/swiftly-install.sh` is accurate. If it is not, push another commit updating it to the proper value.

3. Create a tag on that commit with the format "swiftly-install-x.y.z". Do not omit "z", even if its value is 0.

4. Push the tag to `origin`. `git push origin <tag_name>`

5. Copy `install/swiftly-install.sh` to website branch of repository
