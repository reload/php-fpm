ARG php="8.3"

## Base PHP images
FROM php:8.1-fpm-alpine@sha256:8f9b0ef69baf2f2e9dc926257c6a37ad33d29a6a1e1a71aa36ea80ddec6d6c51 AS php8.1
FROM php:8.2-fpm-alpine@sha256:9164b9e896ab929d74b298a1ffb7b8ec52d0094fdc082a54a2b1df31e5fa4f1d AS php8.2
FROM php:8.3-fpm-alpine@sha256:03d363cdf111ca810e8df3adfe31ecebb074f488ff77394a4d9593440481c95a AS php8.3
FROM php:8.4-fpm-alpine@sha256:4520979d3cb0abd2c6f73a5ff0eef5e411bd5dce05171dbcf2ad5a43f958d8b4 AS php8.4

## Helper images
FROM blackfire/blackfire:2@sha256:933d32e2d7b456d6622af0acec0a6a359731017be0f8ae3d78537bccfd8ac340 AS blackfire
FROM composer:2@sha256:d9d52c36baea592479eb7e024d4c1afaba9bdea27d67566c588d290a31b4b0d1 AS composer
FROM mlocati/php-extension-installer:2@sha256:5d2a8b6dd8ae8ff898513c6491135baa635394d278f8eeb6ed5757261c034c22 AS php-extension-installer

## Custom PHP image
# hadolint ignore=DL3006
FROM php${php}

ARG php=${php}
ARG php_enable_extensions="apcu bcmath calendar ctype curl dom exif fileinfo ftp gd gettext iconv imagick intl json mbstring memcache memcached mysqli mysqlnd opcache pdo pdo_mysql pdo_sqlite phar posix readline redis shmop simplexml soap sockets sqlite3 sysvmsg sysvsem sysvshm tokenizer xml xmlreader xmlwriter xsl zip"

HEALTHCHECK --interval=10s --start-period=90s CMD netstat -ltn | grep -c ":9000"

COPY context/ /

COPY --from=php-extension-installer /usr/bin/install-php-extensions /usr/bin

RUN <<EOT
    set -eux
    apk add --no-cache bash=~5 git=~2 jq=~1 mariadb-client=~11 msmtp=~1 patch=~2 "poppler-utils>=24" unzip=~6 graphicsmagick=~1 sudo=~1 tini=~0
    install-php-extensions ${php_enable_extensions}
    IPE_DONT_ENABLE=1 install-php-extensions blackfire xdebug
    adduser -H -D -S -G wheel -u 501 machost
    adduser -H -D -S -G wheel -u 1000 linuxhost
EOT

COPY --from=blackfire /usr/local/bin/blackfire /usr/bin
COPY --from=composer /usr/bin/composer /usr/bin

SHELL ["/bin/ash", "-eo", "pipefail", "-c"]
RUN curl https://endoflife.date/api/php/${php}.json| jq '{support,eol,lts}' > /etc/eol.json

ARG workdir=/var/www
WORKDIR "${workdir}"

ENV COMPOSER_CACHE_DIR="/tmp/composer-cache"
ENV GIT_CEILING_DIRECTORIES="${workdir}"
ENV PATH="${workdir}/vendor/bin:${PATH}"
ENV PHP_DOCUMENT_ROOT="${workdir}/web"
ENV PHP_SENDMAIL_PATH="/usr/bin/msmtp --read-recipients --read-envelope-from"

ENTRYPOINT [ "/sbin/tini", "--", "php-fpm-entrypoint" ]
CMD [ "php-fpm" ]
