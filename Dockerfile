ARG php="8.2"

## Base PHP images
FROM php:8.0-fpm-alpine@sha256:9dc2c863b01f55c60ffc8f9ede3502b3d4a10cccf17aa22bc5bb837bef6ab3e0 AS php8.0
FROM php:8.1-fpm-alpine@sha256:b6fe49f90df0f66259c55efc2d2e417213b7b8500ebca246363bad853036100c AS php8.1
FROM php:8.2-fpm-alpine@sha256:22222bc837513d55ab67786b02007970a54e9538d3acfe8f84c18fe5585b7267 AS php8.2

## Helper images
FROM blackfire/blackfire:2@sha256:c58e3d1778fa34c35f92c9fb5a893f8d4c6e9740f38f61330a27636270fcaf1f AS blackfire
FROM composer:2@sha256:cd217ccf96d788820353ba1159b861414ae6bb16c67ee2b3f348627bfa38449d AS composer
FROM mlocati/php-extension-installer:1@sha256:c421c4c601061eae3196db73f2a2ed021a607047767d3d5eac0a6f67e38a6dba AS php-extension-installer

## Custom PHP image
# hadolint ignore=DL3006
FROM php${php}

ARG php_enable_extensions="bcmath calendar ctype curl dom exif fileinfo ftp gd gettext iconv imagick intl json mbstring memcache memcached mysqli mysqlnd opcache pdo pdo_mysql pdo_sqlite phar posix readline redis shmop simplexml soap sockets sqlite3 sysvmsg sysvsem sysvshm tokenizer xml xmlreader xmlwriter xsl zip"
ARG php_install_extensions="blackfire xdebug"

HEALTHCHECK CMD netstat -ltn | grep -c ":9000"

COPY context/ /

COPY --from=blackfire /usr/local/bin/blackfire /usr/bin
COPY --from=composer /usr/bin/composer /usr/bin
COPY --from=php-extension-installer /usr/bin/install-php-extensions /usr/bin

RUN apk add --no-cache bash=~5 git=~2 jq=~1 mariadb-client=~10 msmtp=~1 patch=~2 unzip=~6 graphicsmagick=~1 sudo=~1 tini=~0 && \
    install-php-extensions ${php_enable_extensions} && \
    IPE_DONT_ENABLE=1 install-php-extensions ${php_install_extensions} && \
    adduser -H -D -S -G wheel -u 501 machost && \
    adduser -H -D -S -G wheel -u 1000 linuxhost

ARG workdir=/var/www
WORKDIR "${workdir}"

ENV COMPOSER_CACHE_DIR="/tmp/composer-cache"
ENV GIT_CEILING_DIRECTORIES="${workdir}"
ENV PATH="${workdir}/vendor/bin:${PATH}"
ENV PHP_DOCUMENT_ROOT="${workdir}/web"
ENV PHP_SENDMAIL_PATH="/usr/bin/msmtp --read-recipients --read-envelope-from"

ENTRYPOINT [ "/sbin/tini", "--" ]
CMD [ "reload-php-entrypoint", "php-fpm" ]
