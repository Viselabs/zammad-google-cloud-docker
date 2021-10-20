# syntax = docker/dockerfile:1.3-labs
FROM ayxon-dynamics/centos-zammad:5.0.1

ARG BUILD_DATE

ENV DOMAIN="crm.ayxon-dynamics.com"
ENV SSL_CERT_RSA_KEY_BITS=3072
ENV SSL_CERT_DAYS_VALID=90
ENV SSL_CERT_O="Ayxon-Dynamics GmbH"
ENV SSL_CERT_OU="IT-Department"
ENV SSL_CERT_C="DE"
ENV CERTBOT_EMAIL="hostmaster@ayxon-dynamics.com"

EXPOSE 80/tcp 443/tcp

LABEL org.label-schema.build-date="$BUILD_DATE" \
      org.label-schema.name="Zammad" \
      org.opencontainers.image.authors="drindt@ayxon-dynamics.com" \
      org.label-schema.docker.cmd="docker run --rm -ti --memory=4g --memory-swap=0 -p 9001:9001 -p 80:80 -p 443:443 ayxon-dynamics/zammad"

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

COPY zammad-launcher.sh /root
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]