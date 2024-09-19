ARG php="8.2"

## Base PHP images
FROM php:8.0-fpm-alpine@sha256:bbf76d84a693fae1e0d2a259db70c9c47f41bd5a6ec3d339ba397939e7875dd8 AS php8.0
FROM php:8.1-fpm-alpine@sha256:d25c61d176d62c1929bd1d155fc4073b5d8d0db3f4a2d1ae67f580439409fc7f AS php8.1
FROM php:8.2-fpm-alpine@sha256:a16bc43404e602adb0f8f9662a1319f83d85daf23110bf7e02152a8a0e3d7e5e AS php8.2
FROM php:8.3-fpm-alpine@sha256:421373ae5f16b3afa03506de0ecbb4dcf39e4fe817b2a40b5f5c1f23c041dffa AS php8.3

## Helper images
FROM blackfire/blackfire:2@sha256:1bf4085d14fc70d420249e1f982dba55cb67d0562d7211f4fcd4c86a3479e069 AS blackfire
FROM composer:2@sha256:8008ba4d8723edf5f3566bd94e9330a5cdff3d6125ed34a8502718f8d2289515 AS composer
FROM mlocati/php-extension-installer:2@sha256:4f626471edb7f87a8f00ef83f4a8eed3433e33332aa34aa830446f0fabfbe9f8 AS php-extension-installer

## Custom PHP image
# hadolint ignore=DL3006
FROM php${php}

ARG php=${php}
ARG php_enable_extensions="apcu bcmath calendar ctype curl dom exif fileinfo ftp gd gettext iconv imagick/imagick@master intl json mbstring memcache memcached mysqli mysqlnd opcache pdo pdo_mysql pdo_sqlite phar posix readline redis shmop simplexml soap sockets sqlite3 sysvmsg sysvsem sysvshm tokenizer xml xmlreader xmlwriter xsl zip"
ARG php_install_extensions="blackfire xdebug"

HEALTHCHECK --interval=10s --start-period=90s CMD netstat -ltn | grep -c ":9000"

COPY context/ /

COPY --from=php-extension-installer /usr/bin/install-php-extensions /usr/bin

RUN <<EOT
    set -eux
    apk add --no-cache bash=~5 git=~2 jq=~1 mariadb-client=~10 msmtp=~1 patch=~2 unzip=~6 graphicsmagick=~1 sudo=~1 tini=~0
    install-php-extensions ${php_enable_extensions}
    IPE_DONT_ENABLE=1 install-php-extensions ${php_install_extensions}
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
