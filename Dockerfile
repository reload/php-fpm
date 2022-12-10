ARG php="8.1"

## Base PHP images
FROM php:8.0-fpm-alpine@sha256:81724293e135221b0eb394b207a6b0315506018d54cab2d98de91b14af3e663d AS php8.0
FROM docker.io/library/php:8.2-fpm-alpine@sha256:241bfbe2984aaeccd858f65553eef4024ba7d604cf0514e56b089aca3c047ca4 AS php8.1
FROM php:8.2-rc-fpm-alpine@sha256:838b05dd02ab8a6b2d7510f9ebbc99cde20cba6200b3822e22bf581d4eab6d51 AS php8.2

## Helper images
FROM blackfire/blackfire:2@sha256:c58e3d1778fa34c35f92c9fb5a893f8d4c6e9740f38f61330a27636270fcaf1f AS blackfire
FROM composer:2@sha256:6fb16d897d4376d711880522b13743c8375b29d4c57183555b58c5be751fc164 AS composer
FROM mlocati/php-extension-installer:1@sha256:94e21d8175d3a06a4332f79a2d3e6285007ce6e0661c559d4e6fcb74fdb97b9b AS php-extension-installer

## Custom PHP image
# hadolint ignore=DL3006
FROM php${php}

ARG php_enable_extensions="bcmath calendar ctype curl dom exif fileinfo ftp gd gettext iconv imagick intl json mbstring memcache memcached mysqli mysqlnd opcache pdo pdo_mysql pdo_sqlite phar posix readline redis shmop simplexml soap sockets sqlite3 sysvmsg sysvsem sysvshm tokenizer xml xmlreader xmlwriter xsl zip"
ARG php_install_extensions="xdebug"

HEALTHCHECK CMD netstat -ltn | grep -c ":9000"

COPY context/ /

COPY --from=blackfire /usr/local/bin/blackfire /usr/bin
COPY --from=composer /usr/bin/composer /usr/bin
COPY --from=php-extension-installer /usr/bin/install-php-extensions /usr/bin

RUN apk add --no-cache bash=~5 git=~2 mariadb-client=~10 msmtp=~1 patch=~2 unzip=~6 graphicsmagick=~1 && \
    install-php-extensions ${php_enable_extensions} && \
    IPE_DONT_ENABLE=1 install-php-extensions ${php_install_extensions}

ENV PHP_SENDMAIL_PATH="/usr/bin/msmtp --read-recipients"

ENTRYPOINT [ "reload-php-entrypoint" ]
CMD [ "php-fpm" ]
