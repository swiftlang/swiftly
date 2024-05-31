# Releasing

This document describes the process of preparing a release of swiftly.

## Testing

Before releasing you should run the automated test suites. As a prerequisite you should have docker and docker-compose installed on your system to run the tests.

First, there's the unit test suite that you run like this for each of the supported Linux distributions:
```
docker-compose -f docker/docker-compose.yaml -f docker/docker-compose.2004.yaml run test  # Replace 2004 with the various distribution-specific docker files to get more coverage
```

Note that this test suite will hit GitHub API's quite frequently. You will probably need to generate a personal access token from your public GitHub account
and provide it to the yaml to get a better rate limit for the tests. The PAT doesn't require any special permissions in the GitHub settings. Once you have
one you can provide it using an environment variable in the docker file like this:

```
+++ b/docker/docker-compose.2204.yaml
@@ -14,6 +14,8 @@ services:
       - SWIFTLY_PLATFORM_NAME=ubuntu2204
       - SWIFTLY_PLATFORM_NAME_FULL=ubuntu22.04
       - SWIFTLY_PLATFORM_NAME_PRETTY="Ubuntu 22.04"
+      - SWIFTLY_GITHUB_TOKEN=github_pat_ABCDEFG...
```

If you run these tests on an ARM64/Apple Silicon system you can make sure that the tests and swiftly itself are aligned on that architecture:

```
+++ b/docker/docker-compose.2204.yaml
@@ -14,6 +14,8 @@ services:
       - SWIFTLY_PLATFORM_NAME=ubuntu2204
       - SWIFTLY_PLATFORM_NAME_FULL=ubuntu22.04
       - SWIFTLY_PLATFORM_NAME_PRETTY="Ubuntu 22.04"
+      - SWIFTLY_PLATFORM_ARCH=aarch64
```

Next up is the installation tests. These are designed to run in a containerized environment since they make changes to your user account and
profile.

```
docker run -v $(pwd):/swiftly ubuntu:22.04 bash -c "cd /swiftly/install; ./run-tests.sh" # Replace ubuntu:22.04 with other supported distributions for more coverage
```

You can re-run a single test script in isolation.

```
docker run -v $(pwd):/swiftly ubuntu:22.04 bash -c "cd /swiftly/install; ./tests/default-install.sh"
```

Run all of the tests in isolation to make sure that there isn't any leaking system state between tests.

```
./install/run-tests-fresh.sh ubuntu:22.04
```

## Releasing swiftly

1. Check out the commit you wish to create a release for. Ensure no other local modifications or changes are present.

2. Ensure the version string in `SwiftlyCore/SwiftlyCore.swift` is accurate. If it is not, push another commit updating it to the proper value.

3. Create a tag on that commit with the format "x.y.z". Do not omit "z", even if its value is 0.

4. Build the executables for the release by running ./scripts/build_release.sh from the root of the swiftly repository (do this once on an x86_64 machine and once on an aarch64 one)

5. Push the tag to `origin`. `git push origin <tag_name>`

6. Go to the GitHub page for the new tag, click edit tag, add an appropriate description, attach the prebuilt executables, and click "Publish Release".

