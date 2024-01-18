#!/bin/bash
# The script is intended to act as a starter. If a database has already been initialized,
# it is assumed that the system setup is already complete.

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
    (cd /var/lib/pgsql && runuser postgres -c '/usr/bin/initdb -D /var/lib/pgsql/data')

    sed '/shared_buffers/c\shared_buffers = 2GB' -i /var/lib/pgsql/data/postgresql.conf
    sed '/temp_buffers/c\temp_buffers = 256MB' -i /var/lib/pgsql/data/postgresql.conf
    sed '/work_mem/c\work_mem = 10MB' -i /var/lib/pgsql/data/postgresql.conf
    sed '/max_stack_depth/c\max_stack_depth = 5MB' -i /var/lib/pgsql/data/postgresql.conf

    start_postgres_sync

    runuser postgres -c $'psql -c \'CREATE USER zammad;\''
    runuser postgres -c $'psql -c \'ALTER USER zammad CREATEDB;\''

    zammad run rake db:create
    zammad run rake db:migrate
    zammad run rake db:seed

    zammad run rails r "Setting.set('es_url', 'http://localhost:9200')" &
    zammad run rails r Locale.sync
    zammad run rails r Translation.sync
fi

supervisorctl start zammad-worker
supervisorctl start zammad-websocket
supervisorctl start zammad-web

<<EOF cat > /root/acme-launcher.sh && chmod +x /root/acme-launcher.sh
#!/bin/bash
ACME_HOME="/var/lib/pgsql/acme"
WWW_HOME="/var/www/html"
mkdir -p \${ACME_HOME} \${WWW_HOME}
while true
do
  /root/acme.sh --issue \
                --preferred-chain "isrg" \
                --server letsencrypt \
                -d ${DOMAIN} \
                -k ec-521 \
                -w \${WWW_HOME} \
                --home \${ACME_HOME}

  ln -sf \${ACME_HOME}/${DOMAIN}_ecc/${DOMAIN}.key /etc/nginx/ssl/${DOMAIN}-privkey.pem && \
  ln -sf \${ACME_HOME}/${DOMAIN}_ecc/fullchain.cer /etc/nginx/ssl/${DOMAIN}-fullchain.pem && \
  ln -sf \${ACME_HOME}/${DOMAIN}_ecc/ca.cer /etc/nginx/ssl/lets-encrypt-x3-cross-signed.pem && \

  supervisorctl restart nginx

  echo "I'll try again in 24 hours..."
  sleep 24h
done
EOF
supervisorctl start acme
