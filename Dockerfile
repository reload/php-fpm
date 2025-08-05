ARG php="8.3"

## Base PHP images
FROM php:8.1-fpm-alpine@sha256:9db61cdcdfb1177c72de2d930ffda0db5fbad74726064ff06be2efdf75823262 AS php8.1
FROM php:8.2-fpm-alpine@sha256:9c5e86aba802fad6e74c91bc8310254416d09d47d130c3d9c049255572dcfb72 AS php8.2
FROM php:8.3-fpm-alpine@sha256:51e5db7ca7b201be1119e9aa9b55f9121a49d4fb34151b93ebd97c4b443c1ad2 AS php8.3
FROM php:8.4-fpm-alpine@sha256:0f6792146a1ec71ab4206adece8be0180ffb20aeb82e6e573e250fa0734575bc AS php8.4

## Helper images
FROM blackfire/blackfire:2@sha256:e02be50a6b8ad9908e8d49c4fb547d1c1fa4f22305684baacd03293c4e7d6f29 AS blackfire
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
ENV PATH="${workdir}/vendor/bin:${PATH}"
ENV PHP_DOCUMENT_ROOT="${workdir}/web"
ENV PHP_SENDMAIL_PATH="/usr/bin/msmtp --read-recipients --read-envelope-from"

ENTRYPOINT [ "/sbin/tini", "--", "php-fpm-entrypoint" ]
CMD [ "php-fpm" ]
