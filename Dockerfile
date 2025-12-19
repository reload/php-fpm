ARG php="8.3"

## Base PHP images
FROM php:8.1-fpm-alpine@sha256:16e30a08fa5ffca9238bd6b5e02abd6a2931f3e449e8b71994dce2598e505565 AS php8.1
FROM php:8.2-fpm-alpine@sha256:85da534a7143712636e463037aedadda6a7c5d3c09f23b14c3a3bbae42cffb26 AS php8.2
FROM php:8.3-fpm-alpine@sha256:4feab66ad2daf97362ae8f0b760a5e5bc1237bd64dd86bbafe8e65d40f89ccca AS php8.3
FROM php:8.4-fpm-alpine@sha256:1edb1b9eb9c4449f6c264ff2e9cb83c1621ba5da208140de426b8d40b2d4a241 AS php8.4
FROM php:8.5-fpm-alpine@sha256:08bd6cf897c1ea3eade57fb7a20c6c77c7817552dcdb8d5715c2efcca4edd58f AS php8.5

## Helper images
FROM blackfire/blackfire:2@sha256:4df57965cd4688e6efa20d0a91f5a056b16ce33958c12563c3fd4ad4fffbc276 AS blackfire
FROM composer:2@sha256:d9d52c36baea592479eb7e024d4c1afaba9bdea27d67566c588d290a31b4b0d1 AS composer
FROM mlocati/php-extension-installer:2@sha256:b17b8107fe8480d5f88c7865b83bb121a344876272eb6b7c9e9f331c931695be AS php-extension-installer

## Custom PHP image
# hadolint ignore=DL3006
FROM php${php}

ARG php=${php}
ARG php_enable_extensions="apcu bcmath calendar ctype curl dom exif fileinfo ftp gd gettext iconv intl imagick json mbstring memcached mysqli mysqlnd opcache pdo pdo_mysql pdo_sqlite phar posix readline redis shmop simplexml soap sockets sqlite3 sysvmsg sysvsem sysvshm tokenizer xml xmlreader xmlwriter xsl zip"

HEALTHCHECK --interval=10s --start-period=90s CMD netstat -ltn | grep -c ":9000"

COPY context/ /

COPY --from=php-extension-installer /usr/bin/install-php-extensions /usr/bin

RUN <<EOT
    set -eux
    apk add --no-cache bash=~5 git=~2 jq=~1 mariadb-client=~11 msmtp=~1 patch=~2 "poppler-utils>=24" unzip=~6 graphicsmagick=~1 sudo=~1 tini=~0
    install-php-extensions ${php_enable_extensions}
    if [ "${php}" = "8.5" ]; then install-php-extensions websupport-sk/pecl-memcache@main; fi
    if [ "${php}" != "8.5" ]; then install-php-extensions memcache; fi
    IPE_DONT_ENABLE=1 install-php-extensions xdebug
    if [ "${php}" != "8.5" ]; then IPE_DONT_ENABLE=1 install-php-extensions blackfire; fi
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
