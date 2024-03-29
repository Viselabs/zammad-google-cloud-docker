FROM quay.io/centos/centos:stream8

ARG BUILD_DATE

ENV DOMAIN="support.coloryzer.com"

EXPOSE 80/tcp 443/tcp

LABEL org.label-schema.docker.cmd="docker run --rm -ti --memory=4g --memory-swap=0 -p 9001:9001 -p 80:80 -p 443:443 viselabs/zammad" \
      org.label-schema.name="Zammad" \
      org.opencontainers.image.authors="drindt@viselabs.com" \
      org.label-schema.build-date="$BUILD_DATE"

# Set the system time zone
RUN ln -sf /usr/share/zoneinfo/Europe/Berlin /etc/localtime

# Only use fast mirror servers
RUN echo "fastestmirror=1" >> /etc/dnf/dnf.conf

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
RUN rm /usr/share/elasticsearch/modules/x-pack-security/nimbus-jose-jwt-9.23.jar
RUN rm /usr/share/elasticsearch/modules/x-pack-identity-provider/xmlsec-2.1.4.jar /usr/share/elasticsearch/modules/x-pack-security/xmlsec-2.1.4.jar
RUN cd /usr/share/elasticsearch/modules/x-pack-identity-provider/ && curl -O https://repo1.maven.org/maven2/org/apache/santuario/xmlsec/2.2.6/xmlsec-2.2.6.jar
RUN cp /usr/share/elasticsearch/modules/x-pack-identity-provider/xmlsec-2.2.6.jar /usr/share/elasticsearch/modules/x-pack-security/
RUN rm /usr/share/elasticsearch/bin/elasticsearch-sql-cli-7.17.17.jar
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
RUN rm -rf /usr/share/nginx/html
RUN mkdir -p /etc/nginx/ssl
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

# Setup acme.sh
RUN dnf -y install socat
RUN (cd /root/ && curl -O https://raw.githubusercontent.com/acmesh-official/acme.sh/master/acme.sh && chmod +x acme.sh)
RUN <<EOF cat > /etc/supervisord.d/acme.ini
[program:acme]
autorestart=false
autostart=false
command=/root/acme-launcher.sh
EOF

# clean-up
RUN dnf -y clean all

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]
