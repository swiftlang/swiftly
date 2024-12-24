#!/bin/bash

apt-get --help && apt-get update && TZ=Etc/UTC apt-get -y install curl make gpg tzdata
yum --help && (curl --help && yum -y install curl) && yum install make gpg

(cat /etc/os-release | grep bookworm) && apt-get -y install libstdc++-12-dev gnupg2
(cat /etc/os-release | grep 'Fedora Linux 39') && yum -y install libstdc++-devel libstdc++-static

exit 0
