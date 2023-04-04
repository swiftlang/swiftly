ARG base_image=amazonlinux:2
FROM $base_image

RUN yum install --allowerasing -y curl gcc-c++
RUN echo 'export PATH="$HOME/.local/bin:$PATH"' >> $HOME/.profile
