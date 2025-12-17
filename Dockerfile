ARG php="8.3"

## Base PHP images
FROM php:8.1-fpm-alpine@sha256:16e30a08fa5ffca9238bd6b5e02abd6a2931f3e449e8b71994dce2598e505565 AS php8.1
FROM php:8.2-fpm-alpine@sha256:370a4d6deb983afb28dd7dde6daf27870c983f81d83c81309f1f47efeb10d5e4 AS php8.2
FROM php:8.3-fpm-alpine@sha256:ad9c85042666b757f0d196a3b11994f26d07df49b1fac92971d0c48454053106 AS php8.3
FROM php:8.4-fpm-alpine@sha256:74d654eccf3a4d2b132d2ddcd7ee14eb1340095fd3374bc1bd45fd06635406fe AS php8.4
FROM php:8.5-fpm-alpine@sha256:5ed9ba668b6eef9b5a64bd5ce64d2d055c57778a68845ae819d93af5c75fd493 AS php8.5

## Helper images
FROM blackfire/blackfire:2@sha256:931af7fdf6a3d651c05cf86bb9edc919194d726082b6ed84502d0277a300ba67 AS blackfire
FROM composer:2@sha256:d9d52c36baea592479eb7e024d4c1afaba9bdea27d67566c588d290a31b4b0d1 AS composer
FROM mlocati/php-extension-installer:2@sha256:067d6f813699f809edaee06b60a3fedcbfb424ceeb2cc5492806ce71ad249db7 AS php-extension-installer

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
