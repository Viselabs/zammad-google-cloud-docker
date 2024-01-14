FROM quay.io/centos/centos:stream8

ARG BUILD_DATE

ENV CERTBOT_EMAIL="hostmaster@viselabs.com"
ENV DOMAIN="support.coloryzer.com"
ENV SSL_CERT_C="DE"
ENV SSL_CERT_DAYS_VALID=90
ENV SSL_CERT_O="Viselabs"
ENV SSL_CERT_OU="IT-Department"
ENV SSL_CERT_RSA_KEY_BITS=3072

EXPOSE 80/tcp 443/tcp

LABEL org.label-schema.docker.cmd="docker run --rm -ti --memory=4g --memory-swap=0 -p 9001:9001 -p 80:80 -p 443:443 viselabs/zammad" \
      org.label-schema.name="Zammad" \
      org.opencontainers.image.authors="drindt@viselabs.com" \
      org.label-schema.build-date="$BUILD_DATE"

# Set the system time zone
RUN ln -sf /usr/share/zoneinfo/Europe/Berlin /etc/localtime

# Bring everything up to date
RUN dnf -y install epel-release
RUN dnf -y update --refresh
RUN dnf -y distro-sync

# Setup Supervisor
RUN dnf -y install supervisor
RUN sed "s/;user=chrism/user=root/g" -i /etc/supervisord.conf
RUN sed "s/nodaemon=false/nodaemon=true/g" -i /etc/supervisord.conf

# Setup for Elasticsearch (version 8.x is the latest release)
RUN <<EOF cat > /etc/yum.repos.d/elasticsearch.repo
[elasticsearch]
autorefresh=1
baseurl=https://artifacts.elastic.co/packages/8.x/yum
enabled=1
gpgcheck=1
gpgkey=https://artifacts.elastic.co/GPG-KEY-elasticsearch
name=Elasticsearch repository for 8.x packages
repo_gpgcheck=1
type=rpm-md
EOF
RUN dnf -y install elasticsearch
RUN sed "s/\/var\/run\/elasticsearch/\/run\/elasticsearch/g" -i /usr/lib/tmpfiles.d/elasticsearch.conf
RUN echo "http.max_content_length: 400mb" >> /etc/elasticsearch/elasticsearch.yml
RUN sed -i 's/xpack.security.enabled: true/xpack.security.enabled: false/' /etc/elasticsearch/elasticsearch.yml
RUN echo -e "-Xms1g\n-Xmx1g" > /etc/elasticsearch/jvm.options.d/e2-medium.options
RUN <<EOF cat > /etc/supervisord.d/elasticsearch.ini
[program:elasticsearch]
command=/usr/share/elasticsearch/bin/systemd-entrypoint
priority=3
#stderr_logfile=/dev/stderr
#stdout_logfile=/dev/stdout
user=elasticsearch
EOF

# Setup PostgreSQL Server
RUN dnf -y install postgresql-server
RUN sed "s/\/var\/run\/postgresql/\/run\/postgresql/g" -i /usr/lib/tmpfiles.d/postgresql.conf
# We accept that the first start fail
RUN <<EOF cat > /etc/supervisord.d/postgresql.ini
[program:postgresql]
autorestart=unexpected
command=/usr/bin/postmaster -D /var/lib/pgsql/data
priority=1
startretries=1
user=postgres
EOF

# Setup Zammad
RUN <<EOF cat > /etc/yum.repos.d/zammad.repo
[zammad]
baseurl=https://dl.packager.io/srv/rpm/zammad/zammad/stable/el/8/\$basearch
enabled=1
gpgcheck=0
gpgkey=https://dl.packager.io/srv/zammad/zammad/key
name=Zammad for CentOS 8 - Zammad
repo_gpgcheck=1
EOF
RUN dnf -y install zammad libxcrypt-compat compat-openssl11 sendmail
RUN <<EOF cat > /etc/supervisord.d/redis.ini
[program:redis]
autostart=true
command=/usr/bin/redis-server
priority=1
EOF
RUN <<EOF cat > /etc/supervisord.d/zammad-web.ini
[program:zammad-web]
autostart=false
command=/usr/bin/zammad run web
priority=6
user=zammad
EOF
RUN <<EOF cat > /etc/supervisord.d/zammad-websocket.ini
[program:zammad-websocket]
autostart=false
command=/usr/bin/zammad run websocket
priority=5
user=zammad
EOF
RUN <<EOF cat > /etc/supervisord.d/zammad-worker.ini
[program:zammad-worker]
autostart=false
command=/usr/bin/zammad run worker
priority=4
user=zammad
EOF

# Setup Nginx
RUN dnf -y install wget
RUN rm -rf /usr/share/nginx/html
RUN mkdir -p /etc/nginx/ssl
RUN wget https://letsencrypt.org/certs/lets-encrypt-x3-cross-signed.pem -P /etc/nginx/ssl
RUN openssl dhparam -out /etc/nginx/ssl/dhparam.pem "$SSL_CERT_RSA_KEY_BITS"
COPY zammad_ssl.conf /etc/nginx/conf.d/zammad.conf
RUN sed -i "s/example.com/$DOMAIN/" /etc/nginx/conf.d/zammad.conf
RUN <<EOF cat > /etc/supervisord.d/nginx.ini
[program:nginx]
autostart=false
command=/usr/sbin/nginx -g "daemon off;"
EOF

# Create launcher script
COPY zammad-launcher.sh /root
RUN <<EOF cat > /etc/supervisord.d/zammad-launcher.ini
[program:zammad-launcher]
autorestart=false
command=/root/zammad-launcher.sh
priority=2
#stdout_logfile=/dev/stdout
EOF

# Setup certbot
RUN dnf -y install certbot
RUN <<EOF cat > /etc/supervisord.d/certbot.ini
[program:certbot]
autorestart=false
autostart=false
command=/root/certbot-launcher.sh
#stdout_logfile=/dev/stdout
EOF

# clean-up
RUN dnf -y clean all

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]
