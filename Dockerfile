ARG php="8.2"

## Base PHP images
FROM php:8.1-fpm-alpine@sha256:2c43b8bd86bd92783b699b711b9bff3b4e327fbf7ad54596421e34ba92637302 AS php8.1
FROM php:8.2-fpm-alpine@sha256:c523472426f614a75900f6078825db8e43dac2b7b3eba2bbe979b794014a944d AS php8.2
FROM php:8.3-fpm-alpine@sha256:f629de30ba229744bf7a4019e146940cda8a50808f1c3fd0d05ddc72908ab71b AS php8.3
FROM php:8.4-fpm-alpine@sha256:27ec40542bee352cb92da944c8598211bf40a8fd6af8006bf90d39c91672fc0a AS php8.4

## Helper images
FROM blackfire/blackfire:2@sha256:1df0d05684ae180dc37a139d8bf01485fdbc37f654ef91ccbdb8072172110daa AS blackfire
FROM composer:2@sha256:26bbf85fccb36247181de6f4a2beddac47d4b352c0c19249a3b4fa2abf1e38ad AS composer
FROM mlocati/php-extension-installer:2@sha256:b98dc41933abaae1daf6ebdafd59b4108f70c24ebc1416d60d6ecc3a5bb138a2 AS php-extension-installer

## Custom PHP image
# hadolint ignore=DL3006
FROM php${php}

ARG php=${php}
ARG php_enable_extensions="apcu bcmath calendar ctype curl dom exif fileinfo ftp gd gettext iconv imagick intl json mbstring memcache memcached mysqli mysqlnd opcache pdo pdo_mysql pdo_sqlite phar posix readline redis shmop simplexml soap sockets sqlite3 sysvmsg sysvsem sysvshm tokenizer xml xmlreader xmlwriter xsl zip"
ARG php_install_extensions="blackfire xdebug"

HEALTHCHECK --interval=10s --start-period=90s CMD netstat -ltn | grep -c ":9000"

COPY context/ /

COPY --from=php-extension-installer /usr/bin/install-php-extensions /usr/bin

RUN <<EOT
    set -eux
    apk add --no-cache bash=~5 git=~2 jq=~1 mariadb-client=~11 msmtp=~1 patch=~2 unzip=~6 graphicsmagick=~1 sudo=~1 tini=~0
    install-php-extensions ${php_enable_extensions}
    if [ "${php}" != "8.4" ]; then IPE_DONT_ENABLE=1 install-php-extensions ${php_install_extensions}; fi
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
