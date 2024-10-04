FROM composer:latest AS composer

# build flox
RUN \
  echo "**** building flox ****" && \
  apk add git && \
  git clone https://github.com/Simounet/flox.git /build/flox && \
  cd /build/flox/backend && \
  composer install --no-dev -o --prefer-dist

###########################################

FROM debian:latest

# set version label
ARG BUILD_VERSION
ENV FLOX_VERSION=${BUILD_VERSION}
LABEL version="${BUILD_VERSION}"
LABEL maintainer="Ivan Schaller"
LABEL description="A personal watchlist"


# copy app from build step
COPY --from=composer /build/flox /app/flox


# install packages
ARG db_path='/flox/backend/database/db.sqlite'
RUN \
  echo "**** installing base packages ****" && \
  apt-get update && \
  apt-get install -y --no-install-recommends \
      sqlite3 \
      php8.2 \
      php8.2-sqlite3 \
      php-fpm \
      php-xml \
      php-mbstring \
      php-bcmath \
      php-opcache \
      nginx \
      && \
  echo "**** prepare app ****" && \
  touch "/app${db_path}" && \
  cd /app/flox/backend && \
  php artisan flox:init --no-interaction "${db_path}" && \
  sed -i \
      -e 's,DB_CONNECTION=.*,DB_CONNECTION=sqlite,g' \
      -e 's,DB_DATABASE=.*,DB_DATABASE='"${db_path}"',g' \
          /app/flox/backend/.env && \
  echo "**** other preparation ****" && \
  mkdir -p /run/php/ && \
  touch /run/php/php8.2-fpm.sock && \
  sed -i \
      -e 's,user =.*,user = abc,g' \
      -e 's,group =.*,group = abc,g' \
      -e 's,listen.owner =.*,listen.owner = abc,g' \
      -e 's,listen.group =.*,listen.group = abc,g' \
          /etc/php/8.2/fpm/pool.d/www.conf && \
  chown -R abc:abc /app/flox && \
  echo "**** cleanup ****" && \
  apt-get purge --auto-remove -y && \
  apt-get clean && \
  rm -rf \
    /tmp/* \
    /var/lib/apt/lists/* \
    /var/tmp/*


# copy files to container
COPY rootfs /

WORKDIR /flox

EXPOSE 8080

