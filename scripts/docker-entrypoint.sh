#!/bin/bash

set -xe

if [ "$1" = 'app' ]; then

  export rakeSecret=$(rake secret)
  echo "===> Configuring Sharetribe for production please wait..."
  sed -e "s#production:#${RAILS_ENV}:#" -e "s#.*adapter:.*#  adapter: mysql2#" -e "s#.*username:.*#  username: ${STRIBE_DB_USER}#" -e "s#.*password:.*#  password: ${STRIBE_DB_PASS}#" -e "s#.*database:.*#  database: ${STRIBE_DB}\n  host: ${STRIBE_DB_HOST}#" < ${STRIBE_DIR}/config/database.yml.pkgr > ${STRIBE_DIR}/config/database.yml
  cd ${STRIBE_DIR}
  # echo "===> Running db:schema:load..."
  # bundle exec rake db:schema:load
  echo "===> Running db:migrate..."
  bundle exec rake db:migrate
  echo "===> Running db:seed..."
  bundle exec rake db:seed

  secret_key_base=$(ruby -r securerandom -e "puts SecureRandom.hex(64)")
  export secret_key_base

  # assets precompile
  echo "===> Running assets:precompile..."
  bundle exec rake assets:precompile

  echo "==> setting hostname now..."
  sed -e "s#.*server_name.*#    server_name ${STRIBE_URL};#" < /stribe.conf.pkgr > /etc/nginx/sites-enabled/stribe.conf

  echo "==> starting nginx, postfix and memcached..."
  service nginx start; service postfix start; service memcached start

  echo "===> Starting Sharetribe...."


  exec bundle exec passenger \
     start \
     -p "${PORT-3000}" \
     --log-file "/dev/stdout" \
     --min-instances "${PASSENGER_MIN_INSTANCES-1}" \
     --max-pool-size "${PASSENGER_MAX_POOL_SIZE-1}"

  # run shell
  /bin/bash

fi