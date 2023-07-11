ARG php="8.2"

## Base PHP images
FROM php:8.0-fpm-alpine@sha256:671260765202209c4d850f5e4d09543d5ac58ab0cd0d119706bd95892e17be4e AS php8.0
FROM php:8.1-fpm-alpine@sha256:7ed8828fdf0747474d79b597bd818c80b59d43e32329aaf7197cd809e368da58 AS php8.1
FROM php:8.2-fpm-alpine@sha256:4247080cc6241b047bd1197c51a41bc9796162120e601b5ba3f3530fee9494f7 AS php8.2

## Helper images
FROM blackfire/blackfire:2@sha256:d2f474e27186fde915cb6542ba4e3759803bc72d219aace7ba0230d04d58c8c1 AS blackfire
FROM composer:2@sha256:572a3d91b1233a8dc9397627f41832a6aa4d0dc63b18c1da816490e6b7f9536a AS composer
FROM mlocati/php-extension-installer:2@sha256:cc0f4449c17bbe7d09d7e5f34188acf9f8f60426f7d3e49eaac1dc5ccf77f6a0 AS php-extension-installer

## Custom PHP image
# hadolint ignore=DL3006
FROM php${php}

ARG php_enable_extensions="apcu bcmath calendar ctype curl dom exif fileinfo ftp gd gettext iconv imagick intl json mbstring memcache memcached mysqli mysqlnd opcache pdo pdo_mysql pdo_sqlite phar posix readline redis shmop simplexml soap sockets sqlite3 sysvmsg sysvsem sysvshm tokenizer xml xmlreader xmlwriter xsl zip"
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

ENTRYPOINT [ "/sbin/tini", "--", "php-fpm-entrypoint" ]
CMD [ "php-fpm" ]
