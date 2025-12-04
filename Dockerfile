ARG php="8.3"

## Base PHP images
FROM php:8.1-fpm-alpine@sha256:16e30a08fa5ffca9238bd6b5e02abd6a2931f3e449e8b71994dce2598e505565 AS php8.1
FROM php:8.2-fpm-alpine@sha256:f5cbb745950ec7ae49117fc1e326fddcd07ec2d0a47e230918e2eaa65f1b80b0 AS php8.2
FROM php:8.3-fpm-alpine@sha256:85f6888a577eaf8cce7c5cc6a5b3960adb7da5939b0142d0f7ecc0b4ba5cf7d3 AS php8.3
FROM php:8.4-fpm-alpine@sha256:ad846930aa226fad969e037bf14845bca0fae2371e7c53c49f160b27aa4540c9 AS php8.4
FROM php:8.5-fpm-alpine@sha256:ec716b3d7e4d6bb719c5cdaae4ea62de6605e2fd506876adf234613d808854b4 AS php8.5

## Helper images
FROM blackfire/blackfire:2@sha256:931af7fdf6a3d651c05cf86bb9edc919194d726082b6ed84502d0277a300ba67 AS blackfire
FROM composer:2@sha256:d9d52c36baea592479eb7e024d4c1afaba9bdea27d67566c588d290a31b4b0d1 AS composer
FROM mlocati/php-extension-installer:2@sha256:ea0b30ca4023202aad494e9d18f9ed220c31536c7665c75cbbc1dd26215f1ed9 AS php-extension-installer

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
    if [ "${php}" = "8.5" ]; then IPE_DONT_ENABLE=1 install-php-extensions xdebug/xdebug@master; fi
    if [ "${php}" != "8.5" ]; then IPE_DONT_ENABLE=1 install-php-extensions blackfire xdebug; fi
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
