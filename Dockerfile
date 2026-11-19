ARG php="8.3"

## Base PHP images
FROM php:8.2-fpm-alpine@sha256:913fab09564477f2d4fee22e6cdb7d9f88a93c6d201f7d728d347489a70581d6 AS php8.2
FROM php:8.3-fpm-alpine@sha256:30b1b9bfbfce33272aa2821a079e63fcad86b8c070122a798e131d8773524d0d AS php8.3
FROM php:8.4-fpm-alpine@sha256:48b0daad6d12699089e45dd5ad2a7620982fa08d18426f94bf83d926e8495f9f AS php8.4
FROM php:8.5-fpm-alpine@sha256:dae9c4dc795324d7ee1122644c870e9c9a3d05a9f52de27fd904cc33af20bae3 AS php8.5
FROM php:8.6-fpm-alpine@sha256:3892978a38794b348f73d6926fb63e352b5338f8b302cdd2cf0ed968f63b50c5 AS php8.6

## Helper images
FROM blackfire/blackfire:2026.11.0@sha256:d3dd7b34cb2427bee6c91d7eade7350fc91eb03556cde4fd62d632c0a12344ed AS blackfire
FROM composer:2@sha256:f746ca10fd351429e13a6fc9599ccd41d4fc413e036ae8b0dad9e2041adcffcd AS composer
FROM mlocati/php-extension-installer:2@sha256:4fd45396c16685266d32bf147a24ecd5e81029d3820295895bf4a90131190ac9 AS php-extension-installer

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
    apk add --no-cache bash=~5 git=~2 jq=~1 mariadb-client=~11 msmtp=~1 oniguruma-dev=~6 patch=~2 "poppler-utils>=24" unzip=~6 graphicsmagick=~1 sudo=~1 tini=~0
    docker-php-ext-install mbstring # Bootstrap mbstring extention for use by `install-php-extensions`
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
