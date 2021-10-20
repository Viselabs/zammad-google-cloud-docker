# syntax=docker/dockerfile:1.3-labs
FROM centos:centos8

ARG BUILD_DATE

ENV SSL_CERT_RSA_KEY_BITS=4096

LABEL org.label-schema.build-date="$BUILD_DATE" \
      org.label-schema.name="Base image of Zammad on CentOS" \
      org.opencontainers.image.authors="drindt@ayxon-dynamics.com" \
      org.label-schema.docker.cmd="docker run --rm -ti ayxon-dynamics/centos-zammad bash"

# Configure: timezone
RUN ln -sf /usr/share/zoneinfo/Europe/Berlin /etc/localtime

RUN rpm --import https://artifacts.elastic.co/GPG-KEY-elasticsearch
RUN <<EOF cat > /etc/yum.repos.d/elasticsearch.repo
[elasticsearch]
name=Packages for Enterprise CentOS Linux 8 - Elasticsearch
baseurl=https://artifacts.elastic.co/packages/7.x/yum
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://artifacts.elastic.co/GPG-KEY-elasticsearch
EOF

RUN rpm --import https://dl.packager.io/srv/zammad/zammad/key
RUN <<EOF cat > /etc/yum.repos.d/zammad.repo
[zammad]
name=Packages for Enterprise CentOS Linux 8 - Zammad
baseurl=https://dl.packager.io/srv/rpm/zammad/zammad/stable/el/8/\$basearch
enabled=1
gpgcheck=0
repo_gpgcheck=1
gpgkey=https://dl.packager.io/srv/zammad/zammad/key
EOF

# Install required packages for this build and update security related packages
RUN dnf install -y epel-release && \
    dnf update -y && \
    dnf install -y glibc-langpack-en wget supervisor certbot elasticsearch postgresql-server nginx zammad

RUN sed "s/\/var\/run\/elasticsearch/\/run\/elasticsearch/g" -i /usr/lib/tmpfiles.d/elasticsearch.conf
RUN echo "http.max_content_length: 400mb" >> /etc/elasticsearch/elasticsearch.yml

RUN sed "s/\/var\/run\/postgresql/\/run\/postgresql/g" -i /usr/lib/tmpfiles.d/postgresql.conf

# Install/Configure/Run: nginx with self signed ssl certificate until certbot is started
RUN rm -rf /usr/share/nginx/html
RUN mkdir -p /etc/nginx/ssl
RUN wget https://letsencrypt.org/certs/lets-encrypt-x3-cross-signed.pem -P /etc/nginx/ssl
RUN openssl dhparam -out /etc/nginx/ssl/dhparam.pem "$SSL_CERT_RSA_KEY_BITS"
COPY zammad_ssl.conf /etc/nginx/conf.d/zammad.conf

RUN sed "s/nodaemon=false/nodaemon=true/g" -i /etc/supervisord.conf && \
    sed "s/;user=chrism/user=root/g" -i /etc/supervisord.conf

RUN dnf clean all

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]