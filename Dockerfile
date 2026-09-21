ARG php="8.3"

## Base PHP images
FROM php:8.1-fpm-alpine@sha256:a84e0422af72d9a60a8f73756b622bcd37c5a8f85609e43e0a6e16c0a1a7820e AS php8.1
FROM php:8.2-fpm-alpine@sha256:79b4e79ebb2e7a4281ed27369a66322e5f1faf0b79a741446dcc02994791f28e AS php8.2
FROM php:8.3-fpm-alpine@sha256:62f4c401dc970c352223dd018e4f2c9d1c480e07f67351cd31bec2d1f8a8fb42 AS php8.3
FROM php:8.4-fpm-alpine@sha256:c68b19eac3042f36ed7dc7b1240712ad83d421f59e79c73357a645b520f7f68d AS php8.4
FROM php:8.5-fpm-alpine@sha256:ce1dcc234879feab0f309100e55e89e7cf21b9085e76de2a03a8240cec02751e AS php8.5

## Helper images
FROM blackfire/blackfire:2026.9.1@sha256:67f1798d39f1903df93a2dcfb53dc6b09867aa907dd1ce0e7d903bd22e0a0a9e AS blackfire
FROM composer:2@sha256:f746ca10fd351429e13a6fc9599ccd41d4fc413e036ae8b0dad9e2041adcffcd AS composer
FROM mlocati/php-extension-installer:2@sha256:386f0fe880e85f3d1a9077eb6d505d297360934f360f189f04a063231b9b9af9 AS php-extension-installer

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
