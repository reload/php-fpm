ARG php="8.3"

## Base PHP images
FROM php:8.2-fpm-alpine@sha256:f7d0ea0acdaa28bef474b3741ef0ee00423f05078e216d31f1aa5c4a681ae6d4 AS php8.2
FROM php:8.3-fpm-alpine@sha256:25e15cf35ed0f5b75d8cf14fc2c4ed7e0e6bee00d359e681b7fa3e91a7bee49f AS php8.3
FROM php:8.4-fpm-alpine@sha256:93aa3f61216b73cc6f878235c9772849449f4efc18dfe3d6678eed645076c00d AS php8.4
FROM php:8.5-fpm-alpine@sha256:4c2818074ec49f6abe46620f3965e0cb75bc3a5f2b417edd1aacaba6f091c40e AS php8.5

## Helper images
FROM blackfire/blackfire:2026.10.0@sha256:28e324ba896b8178a23e8cc511894c6f25e31ec1c4aa59bf91a2f6efdd9bffb0 AS blackfire
FROM composer:2@sha256:f746ca10fd351429e13a6fc9599ccd41d4fc413e036ae8b0dad9e2041adcffcd AS composer
FROM mlocati/php-extension-installer:2@sha256:ac4b252c153a9f6de5578ff2c417790aba836bb49855543144606033eceda253 AS php-extension-installer

## Custom PHP image
# hadolint ignore=DL3006
FROM php${php}

ARG php=${php}
ARG php_enable_extensions="apcu bcmath brotli calendar ctype curl dom exif fileinfo ftp gd gettext iconv intl imagick json mbstring memcached mysqli mysqlnd opcache pcntl pdo pdo_mysql pdo_pgsql pdo_sqlite phar posix readline redis shmop simplexml soap sockets sqlite3 sysvmsg sysvsem sysvshm tokenizer xml xmlreader xmlwriter xsl zip"

HEALTHCHECK --interval=10s --start-period=90s CMD [ "sh", "-c", "netstat -ltn | grep -c :9000" ]

COPY context/ /

COPY --from=php-extension-installer /usr/bin/install-php-extensions /usr/bin

RUN <<EOT
    set -eux
    apk add --no-cache bash=~5 git=~2 jq=~1 mariadb-client=~11 msmtp=~1 patch=~2 "poppler-utils>=24" unzip=~6 graphicsmagick=~1 sudo=~1 tini=~0
    install-php-extensions ${php_enable_extensions}
    if [ "${php}" = "8.5" ]; then install-php-extensions websupport-sk/pecl-memcache@main; fi
    if [ "${php}" != "8.5" ]; then install-php-extensions memcache; fi
    IPE_DONT_ENABLE=1 install-php-extensions blackfire xdebug
    adduser -H -D -S -G wheel -u 501 machost
    adduser -H -D -S -G wheel -u 1000 linuxhost
EOT

COPY --from=blackfire /usr/local/bin/blackfire /usr/bin
COPY --from=composer /usr/bin/composer /usr/bin

SHELL [ "/bin/ash", "-eo", "pipefail", "-c" ]
RUN curl https://endoflife.date/api/php/${php}.json| jq '{support,eol,lts}' > /etc/eol.json

ARG workdir=/var/www
WORKDIR "${workdir}"

ENV COMPOSER_CACHE_DIR="/tmp/composer-cache"
ENV PATH="${workdir}/vendor/bin:${PATH}"
ENV PHP_DOCUMENT_ROOT="${workdir}/web"
ENV PHP_SENDMAIL_PATH="/usr/bin/msmtp --read-recipients --read-envelope-from"

ENTRYPOINT [ "/sbin/tini", "--", "php-fpm-entrypoint" ]
CMD [ "php-fpm" ]
