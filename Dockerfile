ARG php="8.1"

## Base PHP images
FROM php:8.0-fpm-alpine@sha256:81724293e135221b0eb394b207a6b0315506018d54cab2d98de91b14af3e663d AS php8.0
FROM php:8.1-fpm-alpine@sha256:17182163ba09e71991e7358ea33db3c34f1284ffb69628f0ee578201b4b80892 AS php8.1
FROM php:8.2-rc-fpm-alpine@sha256:838b05dd02ab8a6b2d7510f9ebbc99cde20cba6200b3822e22bf581d4eab6d51 AS php8.2

## Helper images
FROM blackfire/blackfire:v2@sha256:314469d7af3a62f11bc98ecd848592ccaa3f5211510eebf957bfcc70dda90bf3 AS blackfire
FROM composer:2@sha256:3b90a326789f2d255b9b312c74a97925eed80151edf97a8d9e390d9a613e3906 AS composer
FROM mlocati/php-extension-installer:1@sha256:38d22534ae3298e3d36f715b728b017079bdf54d8f6db9661f24c3bfebc2b678 AS php-extension-installer

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

RUN apk add --no-cache bash=~5 git=~2 mariadb-client=~10 msmtp=~1 patch=~2 unzip=~6 && \
    install-php-extensions ${php_enable_extensions} && \
    IPE_DONT_ENABLE=1 install-php-extensions ${php_install_extensions}

ENV PHP_SENDMAIL_PATH="/usr/bin/msmtp --read-recipients"

ENTRYPOINT [ "reload-php-entrypoint" ]
CMD [ "php-fpm" ]
