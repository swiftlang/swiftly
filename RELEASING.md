# Releasing swiftly

1. Check out the commit you wish to create a release for. Ensure no other local modifications or changes are present.

1. Ensure the version string in `Swiftly.swift` is accurate. If it is not, push another commit updating it to the proper value.

1. Create a tag on that commit with the format "x.y.z". Do not omit "z", even if its value is 0.

1. Build the executables for the release (do this once on an x86_64 machine and once on an aarch64 one):

    - In the root of the `swiftly` repository, run the following command: `docker build -t <image name> -f scripts/build.dockerfile .`
    - Then, run `container_id=$(docker create <image name>)`
    - Retrieve the built swiftly executable with `docker cp "$container_id:/swiftly" <executable name>`
      - For ARM, the executable name should be `swiftly-aarch64-unknown-linux-gnu`
      - For x86_64, the executable name should be `swiftly-x86_64-unknown-linux-gnu`
    - Clean up the leftover container with `docker rm -v $container_id`
    - Clean up the leftover image with `docker rm -f <image name>`

1. Push the tag to `origin`.

1. Go to the GitHub page for the new tag, click edit tag, add an appropriate description, attach the prebuilt executables, and click "Publish Release".
