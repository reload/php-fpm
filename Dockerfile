ARG php="8.3"

## Base PHP images
FROM php:8.1-fpm-alpine@sha256:7365744e81a154b196d92bd6c473ba9d87df64e29a8f1b43c869e57007e58687 AS php8.1
FROM php:8.2-fpm-alpine@sha256:d94ae5bf39dddd20d93d4af5598295d43d7854908d57d89b8a03e2b30104c2ae AS php8.2
FROM php:8.3-fpm-alpine@sha256:03844765c10c33de1b4574d3129fcf62c07a959710e50a317646cb2607f6623f AS php8.3
FROM php:8.4-fpm-alpine@sha256:5fa6e07f2377507b80e06b149c7bd4414ceda77fe4a2fc151e7bd950fd16468a AS php8.4

## Helper images
FROM blackfire/blackfire:2@sha256:e7b70c275461a5f3f2bf223612f681e9ebb823490dfd34bda0987645ca6c41e5 AS blackfire
FROM composer:2@sha256:d9d52c36baea592479eb7e024d4c1afaba9bdea27d67566c588d290a31b4b0d1 AS composer
FROM mlocati/php-extension-installer:2@sha256:693f97d7f4c9ea8022bbddeb45abdbd1599714ff1f187fe5d13c12b2e95eb5f9 AS php-extension-installer

## Custom PHP image
# hadolint ignore=DL3006
FROM php${php}

ARG php=${php}
ARG php_enable_extensions="apcu bcmath calendar ctype curl dom exif fileinfo ftp gd gettext iconv imagick intl json mbstring memcache memcached mysqli mysqlnd opcache pdo pdo_mysql pdo_sqlite phar posix readline redis shmop simplexml soap sockets sqlite3 sysvmsg sysvsem sysvshm tokenizer xml xmlreader xmlwriter xsl zip"

HEALTHCHECK --interval=10s --start-period=90s CMD netstat -ltn | grep -c ":9000"

COPY context/ /

COPY --from=php-extension-installer /usr/bin/install-php-extensions /usr/bin

RUN <<EOT
    set -eux
    apk add --no-cache bash=~5 git=~2 jq=~1 mariadb-client=~11 msmtp=~1 patch=~2 "poppler-utils>=24" unzip=~6 graphicsmagick=~1 sudo=~1 tini=~0
    install-php-extensions ${php_enable_extensions}
    IPE_DONT_ENABLE=1 install-php-extensions blackfire xdebug
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
ENV PATH="${workdir}/vendor/bin:${PATH}"
ENV PHP_DOCUMENT_ROOT="${workdir}/web"
ENV PHP_SENDMAIL_PATH="/usr/bin/msmtp --read-recipients --read-envelope-from"

ENTRYPOINT [ "/sbin/tini", "--", "php-fpm-entrypoint" ]
CMD [ "php-fpm" ]
