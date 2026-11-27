ARG php="8.3"

## Base PHP images
FROM php:8.2-fpm-alpine@sha256:913fab09564477f2d4fee22e6cdb7d9f88a93c6d201f7d728d347489a70581d6 AS php8.2
FROM php:8.3-fpm-alpine@sha256:1180fcd9c96923142c08b3bb6b7fac865dbf3c802fc9f42982e5323aedee97a8 AS php8.3
FROM php:8.4-fpm-alpine@sha256:c0e41e0c856bf97b2e749f40a804031ce938d0d496c4c7d91ad416d993172826 AS php8.4
FROM php:8.5-fpm-alpine@sha256:51414d5291758fe27f58a64c7e8a078465d32cc7dcef7bda803f5b36019802e0 AS php8.5

## Helper images
FROM blackfire/blackfire:2026.11.1@sha256:b4e4ec50c6d5326752e77cb2681de63e1f79a86da36cd85838aee8d329ff9090 AS blackfire
FROM composer:2@sha256:f746ca10fd351429e13a6fc9599ccd41d4fc413e036ae8b0dad9e2041adcffcd AS composer
FROM mlocati/php-extension-installer:2@sha256:584fcc217b94a10187367552f6571cd8680ee4bf22bd752f1087a7d55e35e7de AS php-extension-installer

## Custom PHP image
# hadolint ignore=DL3006
FROM php${php}

ARG php=${php}
ARG php_enable_extensions="apcu bcmath brotli calendar ctype curl dom exif fileinfo ftp gd gettext iconv intl imagick json mbstring memcached mysqli mysqlnd opcache pcntl pdo pdo_mysql pdo_pgsql pdo_sqlite phar posix readline redis shmop simplexml soap sockets sqlite3 sysvmsg sysvsem sysvshm tokenizer xml xmlreader xmlwriter xsl zip"

HEALTHCHECK --interval=10s --start-period=90s CMD [ "sh", "-c", "netstat -ltn | grep -c :9000" ]

COPY context/ /

COPY --from=php-extension-installer /usr/bin/install-php-extensions /usr/bin

RUN <<EOT
    set -eux
    apk add --no-cache bash=~5 git=~2 jq=~1 mariadb-client=~11 msmtp=~1 patch=~2 "poppler-utils>=24" unzip=~6 graphicsmagick=~1 sudo=~1 tini=~0
    install-php-extensions ${php_enable_extensions}
    if [ "${php}" = "8.5" ]; then install-php-extensions websupport-sk/pecl-memcache@main; fi
    if [ "${php}" != "8.5" ]; then install-php-extensions memcache; fi
    IPE_DONT_ENABLE=1 install-php-extensions blackfire xdebug
    adduser -H -D -S -G wheel -u 501 machost
    adduser -H -D -S -G wheel -u 1000 linuxhost
EOT

COPY --from=blackfire /usr/local/bin/blackfire /usr/bin
COPY --from=composer /usr/bin/composer /usr/bin

SHELL [ "/bin/ash", "-eo", "pipefail", "-c" ]
RUN curl https://endoflife.date/api/php/${php}.json| jq '{support,eol,lts}' > /etc/eol.json

ARG workdir=/var/www
WORKDIR "${workdir}"

ENV COMPOSER_CACHE_DIR="/tmp/composer-cache"
ENV PATH="${workdir}/vendor/bin:${PATH}"
ENV PHP_DOCUMENT_ROOT="${workdir}/web"
ENV PHP_SENDMAIL_PATH="/usr/bin/msmtp --read-recipients --read-envelope-from"

ENTRYPOINT [ "/sbin/tini", "--", "php-fpm-entrypoint" ]
CMD [ "php-fpm" ]
