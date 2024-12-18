ARG php="8.2"

## Base PHP images
FROM php:8.1-fpm-alpine@sha256:857e617d937d7425433a3e194594147c4553af6aeffb6d58192d1e2f78f04e8d AS php8.1
FROM php:8.2-fpm-alpine@sha256:2e4805627ecfd6bc83037b0cfd9c89f834d5a57e68da1e3bc52727600fda9f07 AS php8.2
FROM php:8.3-fpm-alpine@sha256:e33c5c3be36c66846266d71475f47f88cf3ce05361ad2e2f5687ff8220436b2a AS php8.3
FROM php:8.4-fpm-alpine@sha256:dcbcd25f19919d0d80eff895322d8f8d75f0aa75ff21f906e3da11a63bd74fb3 AS php8.4

## Helper images
FROM blackfire/blackfire:2@sha256:1df0d05684ae180dc37a139d8bf01485fdbc37f654ef91ccbdb8072172110daa AS blackfire
FROM composer:2@sha256:26bbf85fccb36247181de6f4a2beddac47d4b352c0c19249a3b4fa2abf1e38ad AS composer
FROM mlocati/php-extension-installer:2@sha256:59f654413f5a4e0ed408fc68e3289a8bee7a1b06e5e231b01b7cb8e2e1d70b0d AS php-extension-installer

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
