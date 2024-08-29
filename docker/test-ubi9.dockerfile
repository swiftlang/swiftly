ARG base_image=swift:5.10-rhel-ubi9
FROM $base_image
# needed to do again after FROM due to docker limitation
ARG swift_version
ARG ubuntu_version

# dependencies
RUN yum install -y --allowerasing \
    curl \
    gpg

RUN curl -L https://swift.org/keys/all-keys.asc | gpg --import
