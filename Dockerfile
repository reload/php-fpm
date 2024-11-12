ARG php="8.2"

## Base PHP images
FROM php:8.0-fpm-alpine@sha256:bbf76d84a693fae1e0d2a259db70c9c47f41bd5a6ec3d339ba397939e7875dd8 AS php8.0
FROM php:8.1-fpm-alpine@sha256:5959b213747332e8d48d0539cb2fc11a428dbe61c7bb31d96cf21f4b3d5e7d19 AS php8.1
FROM php:8.2-fpm-alpine@sha256:2c988708e6a3bba0517d526db9f25fa7cb1a83ae58144d705e824322fb6f3971 AS php8.2
FROM php:8.3-fpm-alpine@sha256:1b49b540257318c62a4ae1f2ae37844e47e841a229ba032d367f9f18dd2a9b76 AS php8.3

## Helper images
FROM blackfire/blackfire:2@sha256:e4dcee49ce571886eef0587b4e4f9d273aa51b44a6efeae8b51f51da4502071a AS blackfire
FROM composer:2@sha256:cc12714aa3da014260179539c8bcfd64202cff69c25a5741642d1bb2e7d8fd62 AS composer
FROM mlocati/php-extension-installer:2@sha256:8fcb6e043170f458d6e3f916dfee4842e8b3d10364868720517d728e5be12b3f AS php-extension-installer

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
