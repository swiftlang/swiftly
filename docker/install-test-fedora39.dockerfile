ARG base_image=fedora:39
FROM $base_image

RUN yum install -y curl util-linux gpg
RUN echo 'export PATH="$HOME/.local/bin:$PATH"' >> $HOME/.profile
