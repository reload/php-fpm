ARG php="8.3"

## Base PHP images
FROM php:8.1-fpm-alpine@sha256:9e20c084a69820d87ef2ee96e1b7fe21ecf1ce49dd0abeafce6a6d25e14e350a AS php8.1
FROM php:8.2-fpm-alpine@sha256:681c369da9d85525ff8ce081456fa79988e5a0e39fc286a1e59e179cbcb2711c AS php8.2
FROM php:8.3-fpm-alpine@sha256:309bfcac0de6214394ace398458dd669054b372cc58f0f6ac3403c4db2b7549e AS php8.3
FROM php:8.4-fpm-alpine@sha256:d445d374b3b72968124be3a3a3040a995192dc88d36373bf12d406ac5475098d AS php8.4

## Helper images
FROM blackfire/blackfire:2@sha256:bc34d45dcd7c7e2ae5ef9a282f7c0145e03d6bf7907522b8f56fa4a090798587 AS blackfire
FROM composer:2@sha256:d9d52c36baea592479eb7e024d4c1afaba9bdea27d67566c588d290a31b4b0d1 AS composer
FROM mlocati/php-extension-installer:2@sha256:5e7b5042f9d2b80a285f6e9712a4456199b79e27de6c74e67e889c56f06b9ccc AS php-extension-installer

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
    apk add --no-cache bash=~5 git=~2 jq=~1 mariadb-client=~11 msmtp=~1 patch=~2 poppler-utils=~24 unzip=~6 graphicsmagick=~1 sudo=~1 tini=~0
    install-php-extensions ${php_enable_extensions}
    if [ "${php}" != "8.4" ]; then IPE_DONT_ENABLE=1 install-php-extensions blackfire; fi
    IPE_DONT_ENABLE=1 install-php-extensions xdebug
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
