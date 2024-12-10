#!/bin/bash

# This script does a bit of extra preparation of the docker containers used to run the GitHub workflows
# that are specific to this project's needs when building/testing. Note that this script runs on
# every supported Linux distribution so it must adapt to the distribution that it is running.

apt-get --help && apt-get update && apt-get -y install curl make
yum --help && (curl --help && yum -y install curl) && yum install make

(cat /etc/os-release | grep bookworm) && apt-get -y install gnupg2

exit 0
