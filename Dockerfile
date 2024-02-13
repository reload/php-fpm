ARG php="8.2"

## Base PHP images
FROM php:8.0-fpm-alpine@sha256:173daec831fa47844c876258a19741c7a1928524b5e1936a2b1e7c1f58ec1b12 AS php8.0
FROM php:8.1-fpm-alpine@sha256:fed51bf5b0a3c41418d6252e276d3b82c3077517099095eee67e1d652ea4372c AS php8.1
FROM php:8.2-fpm-alpine@sha256:b15e71c6d9e549d4b69d4200a6f9d49386c5ae617c38e27fc79dc146dc7fd407 AS php8.2
FROM php:8.3-fpm-alpine@sha256:13644664abd18d3c06de89702aa02df13a82c4c1ddff8b06434180baa1fc0b61 AS php8.3

## Helper images
FROM blackfire/blackfire:2@sha256:8dd3debf44167038897cd4524ed7d689fcc53dae23396fb585934b6acc5b2b82 AS blackfire
FROM composer:2@sha256:06e4100b3f9051781b45597d39fbadbd5f2560823ce5736906b5047f275ba582 AS composer
FROM mlocati/php-extension-installer:2@sha256:c6e9f4e02e3ac4f7eee4b41c8c413e4a06bb6f73eefa4e890c586f80e20a4056 AS php-extension-installer

## Custom PHP image
# hadolint ignore=DL3006
FROM php${php}

ARG php=${php}
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
