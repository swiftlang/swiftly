# Releasing

Swift has a tool for producing final product packages, suitable for distribution. Follow these steps to complete a release and test the packaging.

1. Check out the commit you wish to create a release for. Ensure no other local modifications or changes are present.

2. Check the validity of the documentation preview  with `swift package --disable-sandbox preview-documentation --target SwiftlyDocs`

3. Verify that the swiftly command-line reference is up-to-date, if not then run `swift package plugin generate-docs-reference` to update it.

4. Ensure the version string in `SwiftlyCore/SwiftlyCore.swift` is accurate. If it is not, push another commit updating it to the proper value.

5. Create a tag on that commit with the format "x.y.z". Do not omit "z", even if its value is 0.

6. Build the executables for the release by running `swift run build-swiftly-release <version>` from the root of the swiftly repository
  * Build on a Apple silicon macOS machine to produce a universal package for x86_64 and arm64
  * Build on an Amazon Linux 2 image for x86_64
  * Build on an Amazon Linux 2 image for arm64

7. Push the tag to `origin`. `git push origin <tag_name>`
