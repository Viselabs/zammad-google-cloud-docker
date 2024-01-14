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

#    runuser postgres -c '/usr/bin/createdb -E UTF8 zammad'
    runuser postgres -c $'psql -c \'CREATE USER zammad;\''
#    runuser postgres -c $'psql -c \'GRANT ALL PRIVILEGES ON DATABASE zammad TO zammad;\''
    runuser postgres -c $'psql -c \'ALTER USER zammad CREATEDB;\''

    zammad run rake db:create
    if ! "zammad run rake db:seed"; then
      zammad run rake db:migrate
      zammad run rake db:seed
    fi

    zammad run rails r "Setting.set('es_url', 'http://localhost:9200')"
#    zammad run rails r "Setting.set('es_attachment_ignore', \
#                        [ '.png', '.jpg', '.jpeg', '.mpeg', '.mpg', '.mov', \
#                        '.bin', '.exe', '.box', '.mbox' ] )"

    echo "Initial setup of Zammad is complete."
fi

#zammad run rake db:migrate
#zammad run rails r Cache.clear
#zammad run rails r Locale.sync
#zammad run rails r Translation.sync
zammad run rake zammad:searchindex:rebuild[2]

supervisorctl start zammad-worker
supervisorctl start zammad-websocket
supervisorctl start zammad-web

openssl req -nodes -x509 -newkey rsa:"$SSL_CERT_RSA_KEY_BITS" -days "$SSL_CERT_DAYS_VALID" \
    -subj "/CN=$DOMAIN/O=$SSL_CERT_O/OU=$SSL_CERT_OU/C=$SSL_CERT_C" \
    -keyout /etc/nginx/ssl/"$DOMAIN"-privkey.pem \
    -out /etc/nginx/ssl/"$DOMAIN"-fullchain.pem
sed "s/example.com/$DOMAIN/g" -i /etc/nginx/conf.d/zammad.conf
supervisorctl start nginx

<<EOF cat > /root/certbot-launcher.sh && chmod +x /root/certbot-launcher.sh
#!/bin/bash
set -xe
mkdir -p /var/www/html && \
while true
do
    certbot certonly \
        --cert-name $DOMAIN \
        -n \
        --agree-tos \
        --webroot -w /var/www/html \
        -d $DOMAIN \
        --rsa-key-size $SSL_CERT_RSA_KEY_BITS \
        -m $CERTBOT_EMAIL && \

    ln -sf /etc/letsencrypt/live/$DOMAIN/privkey.pem /etc/nginx/ssl/$DOMAIN-privkey.pem && \
    ln -sf /etc/letsencrypt/live/$DOMAIN/fullchain.pem /etc/nginx/ssl/$DOMAIN-fullchain.pem && \

    supervisorctl restart nginx

    sleep 24h
done
EOF
supervisorctl start certbot
