# syntax = docker/dockerfile:1.3-labs
FROM centos:centos8

ARG BUILD_DATE

# Environment configuration
ARG DOMAIN="crm.ayxon-dynamics.com"
ARG SSL_CERT_RSA_KEY_BITS=3072
ARG SSL_CERT_DAYS_VALID=24855
ARG SSL_CERT_CN=$DOMAIN
ARG SSL_CERT_O="Ayxon-Dynamics GmbH"
ARG SSL_CERT_OU="IT-Department"
ARG SSL_CERT_C="DE"
ARG CERTBOT_EMAIL="hostmaster@ayxon-dynamics.com"

LABEL org.label-schema.build-date="$BUILD_DATE" \
      org.label-schema.name="Zammad" \
      org.opencontainers.image.authors="drindt@ayxon-dynamics.com" \
      org.label-schema.docker.cmd="docker run -ti --memory=4g --memory-swap=0 -p 9001:9001 -p 80:80 -p 443:443 -v pgsql:/var/lib/pgsql ayxon-dynamics/zammad"

# Install required packages for this build
RUN dnf install -y epel-release glibc-langpack-en wget

# Configure: timezone
RUN ln -sf /usr/share/zoneinfo/Europe/Berlin /etc/localtime

# Install/Configure/Run: elasticsearch
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
RUN dnf install -y elasticsearch
# Fix/Migration: tmpfiles.d/elasticsearch.conf:1 drop-in file
RUN sed "s/\/var\/run\/elasticsearch/\/run\/elasticsearch/g" -i /usr/lib/tmpfiles.d/elasticsearch.conf

# Install/Configure/Run: postgresql
RUN dnf install -y postgresql-server
# Fix/Migration: tmpfiles.d/postgresql.conf:1 drop-in file
RUN sed "s/\/var\/run\/postgresql/\/run\/postgresql/g" -i /usr/lib/tmpfiles.d/postgresql.conf

# Install/Configure/Run: zammad
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
RUN dnf install -y zammad
RUN <<EOF cat > /root/zammad-launcher.sh && chmod +x /root/zammad-launcher.sh
#!/bin/bash
# The script is intended to act as a starter. If a database has already been initialized,
# it is assumed that the system setup is already complete.
set -ex

function start_postgres_sync () {
    if [ -f /var/lib/pgsql/data/postgresql.conf ]; then
        if [ ! -S /run/supervisor/supervisor.sock ]; then
            echo "The supervisord must be started before this script is called."
            exit 2
        fi

        supervisorctl start postgresql

        until runuser postgres -c 'psql -c "select version()"' &> /dev/null; do
            echo "Waiting for PostgreSQL to be ready..."
            sleep 1s
        done
    fi
}

if [ ! -f /var/lib/pgsql/data/postgresql.conf ]; then
    echo "Start PostgreSQL initial setup"

    chown postgres:postgres /var/lib/pgsql
    pushd /var/lib/pgsql
    runuser postgres -c '/usr/bin/initdb -D /var/lib/pgsql/data'

    sed '/shared_buffers/c\shared_buffers = 2GB' -i /var/lib/pgsql/data/postgresql.conf
    sed '/temp_buffers/c\temp_buffers = 256MB' -i /var/lib/pgsql/data/postgresql.conf
    sed '/work_mem/c\work_mem = 10MB' -i /var/lib/pgsql/data/postgresql.conf
    sed '/max_stack_depth/c\max_stack_depth = 5MB' -i /var/lib/pgsql/data/postgresql.conf

    start_postgres_sync

    runuser postgres -c '/usr/bin/createdb -E UTF8 zammad'
    runuser postgres -c $'psql -c \'CREATE USER zammad;\''
    runuser postgres -c $'psql -c \'GRANT ALL PRIVILEGES ON DATABASE zammad TO zammad;\''

    zammad run rake db:migrate
    zammad run rake db:seed
fi

start_postgres_sync

zammad run rails r Cache.clear
zammad run rails r Locale.sync
zammad run rails r Translation.sync

supervisorctl start zammad-worker
supervisorctl start zammad-websocket
supervisorctl start zammad-web
supervisorctl start nginx
supervisorctl start certbot
EOF

# Install/Configure/Run: nginx with self signed ssl certificate until certbot is started
RUN mkdir -p /etc/nginx/ssl
RUN wget https://letsencrypt.org/certs/lets-encrypt-x3-cross-signed.pem -P /etc/nginx/ssl
RUN openssl dhparam -out /etc/nginx/ssl/dhparam.pem $SSL_CERT_RSA_KEY_BITS
RUN openssl req -nodes -x509 -newkey rsa:$SSL_CERT_RSA_KEY_BITS -days $SSL_CERT_DAYS_VALID \
    -subj "/CN=$SSL_CERT_CN/O=$SSL_CERT_O/OU=$SSL_CERT_OU/C=$SSL_CERT_C" \
    -keyout /etc/nginx/ssl/$DOMAIN-privkey.pem \
    -out /etc/nginx/ssl/$DOMAIN-fullchain.pem
COPY zammad_ssl.conf /etc/nginx/conf.d/zammad.conf
RUN sed "s/example.com/$DOMAIN/g" -i /etc/nginx/conf.d/zammad.conf
RUN sed "s/error_log  \/var\/log\/nginx\/zammad.error.log/error_log \/dev\/stderr error/g" -i /etc/nginx/conf.d/zammad.conf
RUN sed "s/access_log \/var\/log\/nginx\/zammad.access.log/access_log \/dev\/stdout/g" -i /etc/nginx/conf.d/zammad.conf

# Install/Configure: certbot
RUN dnf install -y certbot
RUN <<EOF cat > /root/run-certbot.sh && chmod +x /root/run-certbot.sh
#!/bin/bash
set -ex
mkdir -p /var/www/html && \
while true
do
    certbot certonly -n --agree-tos \
        --webroot -w /var/www/html \
        -d $DOMAIN \
        --rsa-key-size $SSL_CERT_RSA_KEY_BITS \
        -m $CERTBOT_EMAIL && \

    ln -sf /etc/letsencrypt/live/crm.ayxon-dynamics.com/privkey.pem /etc/nginx/ssl/$DOMAIN-privkey.pem && \
    ln -sf /etc/letsencrypt/live/crm.ayxon-dynamics.com/fullchain.pem /etc/nginx/ssl/$DOMAIN-fullchain.pem && \

    supervisorctl restart nginx

    sleep 24h
done
EOF

# Install/Configure/Run: supervisord
RUN dnf install -y supervisor
RUN sed "s/nodaemon=false/nodaemon=true/g" -i /etc/supervisord.conf && \
    sed "s/;user=chrism/user=root/g" -i /etc/supervisord.conf

RUN <<EOF cat > /etc/supervisord.d/zammad-launcher.ini
[program:zammad-launcher]
autorestart=false
command=/root/zammad-launcher.sh
EOF

RUN <<EOF cat > /etc/supervisord.d/nginx.ini
[program:nginx]
autostart=false
priority=98
command=/usr/sbin/nginx -g "daemon off;"
EOF
EXPOSE 80/tcp 443/tcp

RUN <<EOF cat > /etc/supervisord.d/certbot.ini
[program:certbot]
autostart=false
priority=99
autorestart=false
command=/root/run-certbot.sh
EOF

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

# Update system and clean up dnf
RUN dnf update --security -y && dnf clean all

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]