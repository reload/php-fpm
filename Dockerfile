ARG php="8.2"

## Base PHP images
FROM php:8.0-fpm-alpine@sha256:8c29a2403a1067239d7496542789573e782d8be283c7f43178bed124f293f6a0 AS php8.0
FROM php:8.1-fpm-alpine@sha256:a402fe4a2a089932dfbcdd74e320731f77ef664443315ce40fa7129f942212ec AS php8.1
FROM php:8.2-fpm-alpine@sha256:922fa9038781e96eca5faabf57ff4e23821c1956047da32d98c78023cc006f57 AS php8.2

## Helper images
FROM blackfire/blackfire:2@sha256:c58e3d1778fa34c35f92c9fb5a893f8d4c6e9740f38f61330a27636270fcaf1f AS blackfire
FROM composer:2@sha256:6fb16d897d4376d711880522b13743c8375b29d4c57183555b58c5be751fc164 AS composer
FROM mlocati/php-extension-installer:1@sha256:64e849acdeb0aa37ebd4ce0d687495296d6bdc8a18724b7e62324227ec269334 AS php-extension-installer

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

RUN apk add --no-cache bash=~5 git=~2 jq=~1 mariadb-client=~10 msmtp=~1 patch=~2 unzip=~6 graphicsmagick=~1 && \
    install-php-extensions ${php_enable_extensions} && \
    IPE_DONT_ENABLE=1 install-php-extensions ${php_install_extensions}

ARG workdir=/var/www
WORKDIR "${workdir}"
ENV PHP_DOCUMENT_ROOT="${workdir}/web"

ENV PHP_SENDMAIL_PATH="/usr/bin/msmtp --read-recipients --read-envelope-from"

ENTRYPOINT [ "reload-php-entrypoint" ]
CMD [ "php-fpm" ]
