ARG php="8.3"

## Base PHP images
FROM php:8.1-fpm-alpine@sha256:9e20c084a69820d87ef2ee96e1b7fe21ecf1ce49dd0abeafce6a6d25e14e350a AS php8.1
FROM php:8.2-fpm-alpine@sha256:681c369da9d85525ff8ce081456fa79988e5a0e39fc286a1e59e179cbcb2711c AS php8.2
FROM php:8.3-fpm-alpine@sha256:4375336d58c0e7fc8501247932b8211d2f7abf77b34dcb9e270400d393d06d2b AS php8.3
FROM php:8.4-fpm-alpine@sha256:dff1989605e5d831ffa7d79316d0f56be8faabb2d560756bf886669118d5faa9 AS php8.4

## Helper images
FROM blackfire/blackfire:2@sha256:bc67a55c3afb132c050f26f840d7044bbb1d373a8afb551c2b0aa956816553ca AS blackfire
FROM composer:2@sha256:d9d52c36baea592479eb7e024d4c1afaba9bdea27d67566c588d290a31b4b0d1 AS composer
FROM mlocati/php-extension-installer:2@sha256:d9ea6c09af765334e0efa156f2c1f571b911d218032cc225f61456fa06785646 AS php-extension-installer

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
    apk add --no-cache bash=~5 git=~2 jq=~1 mariadb-client=~11 msmtp=~1 patch=~2 poppler-utils=~24 unzip=~6 graphicsmagick=~1 sudo=~1 tini=~0
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
