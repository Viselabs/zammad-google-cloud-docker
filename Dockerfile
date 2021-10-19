# syntax = docker/dockerfile:1.3-labs
FROM centos:centos8

ARG BUILD_DATE

ENV DOMAIN="crm.ayxon-dynamics.com"
ENV SSL_CERT_RSA_KEY_BITS=3072
ENV SSL_CERT_DAYS_VALID=90
ENV SSL_CERT_CN=$DOMAIN
ENV SSL_CERT_O="Ayxon-Dynamics GmbH"
ENV SSL_CERT_OU="IT-Department"
ENV SSL_CERT_C="DE"
ENV CERTBOT_EMAIL="hostmaster@ayxon-dynamics.com"

LABEL org.label-schema.build-date="$BUILD_DATE" \
      org.label-schema.name="Zammad" \
      org.opencontainers.image.authors="drindt@ayxon-dynamics.com" \
      org.label-schema.docker.cmd="docker run -ti --memory=4g --memory-swap=0 -p 9001:9001 -p 80:80 -p 443:443 -v pgsql:/var/lib/pgsql ayxon-dynamics/zammad"

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
    dnf update --security -y && \
    dnf install -y glibc-langpack-en wget supervisor certbot elasticsearch postgresql-server nginx zammad

EXPOSE 80/tcp 443/tcp

RUN sed "s/\/var\/run\/elasticsearch/\/run\/elasticsearch/g" -i /usr/lib/tmpfiles.d/elasticsearch.conf

RUN sed "s/\/var\/run\/postgresql/\/run\/postgresql/g" -i /usr/lib/tmpfiles.d/postgresql.conf

RUN mkdir -p /etc/nginx/ssl
RUN wget https://letsencrypt.org/certs/lets-encrypt-x3-cross-signed.pem -P /etc/nginx/ssl

RUN sed "s/nodaemon=false/nodaemon=true/g" -i /etc/supervisord.conf && \
    sed "s/;user=chrism/user=root/g" -i /etc/supervisord.conf

# Install/Configure/Run: nginx with self signed ssl certificate until certbot is started
COPY zammad_ssl.conf /etc/nginx/conf.d/zammad.conf

RUN <<EOF cat > /etc/supervisord.d/zammad-launcher.ini
[program:zammad-launcher]
autorestart=false
priority=2
command=/root/zammad-launcher.sh
EOF

RUN <<EOF cat > /etc/supervisord.d/nginx.ini
[program:nginx]
autostart=false
command=/usr/sbin/nginx -g "daemon off;"
EOF

RUN <<EOF cat > /etc/supervisord.d/certbot.ini
[program:certbot]
autostart=false
autorestart=false
command=/root/certbot-launcher.sh
EOF

# We accept that the first start fail
RUN <<EOF cat > /etc/supervisord.d/postgresql.ini
[program:postgresql]
priority=1
autorestart=unexpected
startretries=0
command=/usr/bin/postmaster -D /var/lib/pgsql/data
user=postgres
EOF

RUN <<EOF cat > /etc/supervisord.d/elasticsearch.ini
[program:elasticsearch]
autostart=false
priority=3
command=/usr/share/elasticsearch/bin/systemd-entrypoint
user=elasticsearch
EOF

RUN <<EOF cat > /etc/supervisord.d/zammad-web.ini
[program:zammad-web]
autostart=false
priority=6
command=/usr/bin/zammad run web
user=zammad
EOF

RUN <<EOF cat > /etc/supervisord.d/zammad-websocket.ini
[program:zammad-websocket]
autostart=false
priority=5
command=/usr/bin/zammad run websocket
user=zammad
EOF

RUN <<EOF cat > /etc/supervisord.d/zammad-worker.ini
[program:zammad-worker]
autostart=false
priority=4
command=/usr/bin/zammad run worker
user=zammad
EOF

RUN dnf clean all

COPY zammad-launcher.sh /root
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]