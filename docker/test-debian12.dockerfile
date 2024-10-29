ARG swift_version=5.10
ARG base_image=swift:debian12
FROM $base_image
# needed to do again after FROM due to docker limitation
ARG swift_version

# set as UTF-8
RUN apt-get update && apt-get install -y locales locales-all
ENV LC_ALL en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US.UTF-8

# dependencies
RUN apt-get update --fix-missing && apt-get install -y curl build-essential gpg
COPY ./scripts/install-libarchive.sh /
RUN /install-libarchive.sh

RUN curl -L https://swift.org/keys/all-keys.asc | gpg --import
