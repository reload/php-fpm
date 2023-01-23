ARG php="8.2"

## Base PHP images
FROM php:8.0-fpm-alpine@sha256:9dc2c863b01f55c60ffc8f9ede3502b3d4a10cccf17aa22bc5bb837bef6ab3e0 AS php8.0
FROM php:8.1-fpm-alpine@sha256:d62e52cfcd75a668cd6fcc6ca526dfd2676e18aa818cef553f93a1f68b1dbfaa AS php8.1
FROM php:8.2-fpm-alpine@sha256:207429b4f960e028ad993cbde1d0ce509bb5507bebfffa66328c47593a876e2b AS php8.2

## Helper images
FROM blackfire/blackfire:2@sha256:c58e3d1778fa34c35f92c9fb5a893f8d4c6e9740f38f61330a27636270fcaf1f AS blackfire
FROM composer:2@sha256:34da7f25f8f1582b34861afd6c6e780b4f5cc571ffa0e94b91754d403a2d4371 AS composer
FROM mlocati/php-extension-installer:2@sha256:0fbf52c4855291889c0f108aba8bffa3f40f6bb036b142a08a8ecb8c3ad3a990 AS php-extension-installer

## Custom PHP image
# hadolint ignore=DL3006
FROM php${php}

ARG php_enable_extensions="bcmath calendar ctype curl dom exif fileinfo ftp gd gettext iconv imagick intl json mbstring memcache memcached mysqli mysqlnd opcache pdo pdo_mysql pdo_sqlite phar posix readline redis shmop simplexml soap sockets sqlite3 sysvmsg sysvsem sysvshm tokenizer xml xmlreader xmlwriter xsl zip"
ARG php_install_extensions="blackfire xdebug"

HEALTHCHECK --interval=10s --start-period=90s CMD netstat -ltn | grep -c ":9000"

COPY context/ /

COPY --from=blackfire /usr/local/bin/blackfire /usr/bin
COPY --from=composer /usr/bin/composer /usr/bin
COPY --from=php-extension-installer /usr/bin/install-php-extensions /usr/bin

RUN <<EOT
    apk add --no-cache bash=~5 git=~2 jq=~1 mariadb-client=~10 msmtp=~1 patch=~2 unzip=~6 graphicsmagick=~1 sudo=~1 tini=~0
    install-php-extensions ${php_enable_extensions}
    IPE_DONT_ENABLE=1 install-php-extensions ${php_install_extensions}
    adduser -H -D -S -G wheel -u 501 machost
    adduser -H -D -S -G wheel -u 1000 linuxhost
EOT

ARG workdir=/var/www
WORKDIR "${workdir}"

ENV COMPOSER_CACHE_DIR="/tmp/composer-cache"
ENV GIT_CEILING_DIRECTORIES="${workdir}"
ENV PATH="${workdir}/vendor/bin:${PATH}"
ENV PHP_DOCUMENT_ROOT="${workdir}/web"
ENV PHP_SENDMAIL_PATH="/usr/bin/msmtp --read-recipients --read-envelope-from"

ENTRYPOINT [ "/sbin/tini", "--", "reload-php-entrypoint" ]
CMD [ "php-fpm" ]
