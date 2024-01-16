FROM quay.io/centos/centos:stream8

ARG BUILD_DATE

ENV CERTBOT_EMAIL="hostmaster@viselabs.com"
ENV DOMAIN="support.coloryzer.com"
ENV SSL_CERT_C="DE"
ENV SSL_CERT_DAYS_VALID=90
ENV SSL_CERT_O="Viselabs"
ENV SSL_CERT_OU="IT-Department"
ENV SSL_CERT_RSA_KEY_BITS=4096

EXPOSE 80/tcp 443/tcp

LABEL org.label-schema.docker.cmd="docker run --rm -ti --memory=4g --memory-swap=0 -p 9001:9001 -p 80:80 -p 443:443 viselabs/zammad" \
      org.label-schema.name="Zammad" \
      org.opencontainers.image.authors="drindt@viselabs.com" \
      org.label-schema.build-date="$BUILD_DATE"

# Set the system time zone
RUN ln -sf /usr/share/zoneinfo/Europe/Berlin /etc/localtime

# Bring everything up to date
RUN dnf -y install epel-release glibc-langpack-en
RUN dnf -y update --refresh
RUN dnf -y distro-sync

# Setup Supervisor
RUN dnf -y install supervisor
RUN sed "s/;user=chrism/user=root/g" -i /etc/supervisord.conf
RUN sed "s/nodaemon=false/nodaemon=true/g" -i /etc/supervisord.conf

# Setup for Elasticsearch v7.17.16
RUN <<EOF cat > /etc/yum.repos.d/elasticsearch.repo
[elasticsearch]
autorefresh=1
baseurl=https://artifacts.elastic.co/packages/7.x/yum
enabled=1
gpgcheck=1
gpgkey=https://artifacts.elastic.co/GPG-KEY-elasticsearch
name=Elasticsearch repository for 7.x packages
repo_gpgcheck=1
type=rpm-md
EOF
RUN dnf -y install elasticsearch
RUN sed "s/\/var\/run\/elasticsearch/\/run\/elasticsearch/g" -i /usr/lib/tmpfiles.d/elasticsearch.conf
RUN echo "http.max_content_length: 400mb" >> /etc/elasticsearch/elasticsearch.yml
RUN echo "indices.query.bool.max_clause_count: 2000" >> /etc/elasticsearch/elasticsearch.yml
RUN echo -e "-Xms1g\n-Xmx1g" > /etc/elasticsearch/jvm.options.d/e2-medium.options
RUN echo "y" | /usr/share/elasticsearch/bin/elasticsearch-plugin install ingest-attachment
RUN <<EOF cat > /etc/supervisord.d/elasticsearch.ini
[program:elasticsearch]
command=/usr/share/elasticsearch/bin/systemd-entrypoint -p /var/lib/elasticsearch/elasticsearch.pid --quiet
priority=3
user=elasticsearch
EOF
# Security fixes
RUN rm /usr/share/elasticsearch/modules/x-pack-identity-provider/guava-19.0.jar /usr/share/elasticsearch/modules/x-pack-security/guava-19.0.jar
RUN cp /usr/share/elasticsearch/modules/x-pack-watcher/guava-32.0.1-jre.jar /usr/share/elasticsearch/modules/x-pack-identity-provider/guava-19.0.jar
RUN cp /usr/share/elasticsearch/modules/x-pack-watcher/guava-32.0.1-jre.jar /usr/share/elasticsearch/modules/x-pack-security/guava-19.0.jar
RUN rm /usr/share/elasticsearch/plugins/ingest-attachment/commons-io-2.6.jar
RUN cd /usr/share/elasticsearch/plugins/ingest-attachment/ && curl -O https://repo1.maven.org/maven2/commons-io/commons-io/2.7/commons-io-2.7.jar
RUN rm /usr/share/elasticsearch/modules/x-pack-security/nimbus-jose-jwt-9.23.jar
RUN find /usr/share/elasticsearch/modules/ -type f -name httpclient-4.5.10.jar -exec rm -rf {} \;
RUN cd /usr/share/elasticsearch/modules/ingest-common/ && curl -O https://repo1.maven.org/maven2/org/apache/httpcomponents/httpclient/4.5.13/httpclient-4.5.13.jar
RUN cp /usr/share/elasticsearch/modules/ingest-common/httpclient-4.5.13.jar /usr/share/elasticsearch/modules/kibana/
RUN cp /usr/share/elasticsearch/modules/ingest-common/httpclient-4.5.13.jar /usr/share/elasticsearch/modules/reindex/
RUN cp /usr/share/elasticsearch/modules/ingest-common/httpclient-4.5.13.jar /usr/share/elasticsearch/modules/repository-url/
RUN cp /usr/share/elasticsearch/modules/ingest-common/httpclient-4.5.13.jar /usr/share/elasticsearch/modules/x-pack-core/
RUN rm /usr/share/elasticsearch/plugins/ingest-attachment/poi-scratchpad-4.1.2.jar
RUN cd /usr/share/elasticsearch/plugins/ingest-attachment/ && curl -O https://repo1.maven.org/maven2/org/apache/poi/poi-scratchpad/5.2.1/poi-scratchpad-5.2.1.jar
RUN rm /usr/share/elasticsearch/modules/x-pack-identity-provider/xmlsec-2.1.4.jar /usr/share/elasticsearch/modules/x-pack-security/xmlsec-2.1.4.jar
RUN cd /usr/share/elasticsearch/modules/x-pack-identity-provider/ && curl -O https://repo1.maven.org/maven2/org/apache/santuario/xmlsec/2.2.6/xmlsec-2.2.6.jar
RUN cp /usr/share/elasticsearch/modules/x-pack-identity-provider/xmlsec-2.2.6.jar /usr/share/elasticsearch/modules/x-pack-security/
RUN rm /usr/share/elasticsearch/plugins/ingest-attachment/tika-core-1.27.jar
RUN cd /usr/share/elasticsearch/plugins/ingest-attachment/ && curl -O https://repo1.maven.org/maven2/org/apache/tika/tika-core/1.28.3/tika-core-1.28.3.jar
RUN rm /usr/share/elasticsearch/lib/tools/plugin-cli/bc-fips-1.0.2.jar
RUN cd /usr/share/elasticsearch/lib/tools/plugin-cli/ && curl -O https://repo1.maven.org/maven2/org/bouncycastle/bc-fips/1.0.2.4/bc-fips-1.0.2.4.jar
RUN rm /usr/share/elasticsearch/lib/tools/security-cli/bcprov-jdk15on-1.64.jar /usr/share/elasticsearch/plugins/ingest-attachment/bcprov-jdk15on-1.64.jar
RUN cd /usr/share/elasticsearch/lib/tools/security-cli/ && curl -O https://repo1.maven.org/maven2/org/bouncycastle/bcprov-jdk15on/1.70/bcprov-jdk15on-1.70.jar
RUN cp /usr/share/elasticsearch/lib/tools/security-cli/bcprov-jdk15on-1.70.jar /usr/share/elasticsearch/plugins/ingest-attachment/
RUN rm /usr/share/elasticsearch/bin/elasticsearch-sql-cli-7.17.16.jar
RUN rm /usr/share/elasticsearch/lib/snakeyaml-1.33.jar
RUN cd /usr/share/elasticsearch/lib/ && curl -O https://repo1.maven.org/maven2/org/yaml/snakeyaml/2.2/snakeyaml-2.2.jar

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
RUN dnf -y install zammad
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
# Security fixes
RUN /opt/zammad/vendor/ruby-3.1.3/bin/gem install time -v 0.2.2
RUN rm /opt/zammad/vendor/ruby-3.1.3/lib/ruby/gems/3.1.0/specifications/default/time-0.2.0.gemspec
RUN /opt/zammad/vendor/ruby-3.1.3/bin/gem install uri -v 0.11.2
RUN rm /opt/zammad/vendor/ruby-3.1.3/lib/ruby/gems/3.1.0/specifications/default/uri-0.11.0.gemspec

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
EOF

# Setup certbot
RUN dnf -y install certbot
RUN <<EOF cat > /etc/supervisord.d/certbot.ini
[program:certbot]
autorestart=false
autostart=false
command=/root/certbot-launcher.sh
EOF

# clean-up
RUN dnf -y clean all

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]
