ARG php="8.2"

## Base PHP images
FROM php:8.0-fpm-alpine@sha256:173daec831fa47844c876258a19741c7a1928524b5e1936a2b1e7c1f58ec1b12 AS php8.0
FROM php:8.1-fpm-alpine@sha256:abb1c726b9d076af9e7c4c0832aa981474534bbae458b2db21e7a22c6b50d858 AS php8.1
FROM php:8.2-fpm-alpine@sha256:9fe7b8986b361acbd9ee9a6d5f32d75c68218d9df0974c44d3b7878662b9fce8 AS php8.2
FROM php:8.3-fpm-alpine@sha256:38fd55c46362e365f8f6b669bc836528cf7faa0225df1d1a7b1e38562d384065 AS php8.3

## Helper images
FROM blackfire/blackfire:2@sha256:ddc8cb9dbe2574ef55a20feddd18c5dabf1dfc1928e3a2f9a15440c742030bfe AS blackfire
FROM composer:2@sha256:ee4676ef56f97c82f11b421717386bcf9353a53bee9276c414ad80a0a4dc0e02 AS composer
FROM mlocati/php-extension-installer:2@sha256:54f3ca3e932fa2c9d1f630f046dc0f3efdda94dd85569c0922ce9710d6411f08 AS php-extension-installer

## Custom PHP image
# hadolint ignore=DL3006
FROM php${php}

ARG php=${php}
ARG php_enable_extensions="apcu bcmath calendar ctype curl dom exif fileinfo ftp gd gettext iconv imagick/imagick@master intl json mbstring memcache memcached mysqli mysqlnd opcache pdo pdo_mysql pdo_sqlite phar posix readline redis shmop simplexml soap sockets sqlite3 sysvmsg sysvsem sysvshm tokenizer xml xmlreader xmlwriter xsl zip"
ARG php_install_extensions="blackfire xdebug"

HEALTHCHECK --interval=10s --start-period=90s CMD netstat -ltn | grep -c ":9000"

COPY context/ /

COPY --from=blackfire /usr/local/bin/blackfire /usr/bin
COPY --from=composer /usr/bin/composer /usr/bin
COPY --from=php-extension-installer /usr/bin/install-php-extensions /usr/bin

RUN <<EOT
    set -eux
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
