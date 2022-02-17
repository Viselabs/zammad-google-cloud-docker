# syntax=docker/dockerfile:1.3-labs
FROM centos:centos8

ARG BUILD_DATE

LABEL org.label-schema.build-date="$BUILD_DATE" \
      org.label-schema.name="Base image of CentOS 8 Stream" \
      org.opencontainers.image.authors="drindt@ayxon-dynamics.com" \
      org.label-schema.docker.cmd="docker run --rm -ti ayxon-dynamics/centos8-stream bash"

# Switch to CentOS Stream which currently does not offer a Docker image
RUN curl -O http://mirror.centos.org/centos/8-stream/BaseOS/x86_64/os/Packages/centos-gpg-keys-8-3.el8.noarch.rpm && \
    rpm -i centos-gpg-keys-8-3.el8.noarch.rpm && \
    dnf -y --disablerepo=* --enablerepo=extras swap centos-linux-repos centos-stream-repos && \
    dnf -y distro-sync && \
    rm centos-gpg-keys-8-3.el8.noarch.rpm && \
    dnf -y clean all

CMD ["/usr/bin/bash", "-l", "&&", "cd"]