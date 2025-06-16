ARG php="8.3"

## Base PHP images
FROM php:8.1-fpm-alpine@sha256:9e20c084a69820d87ef2ee96e1b7fe21ecf1ce49dd0abeafce6a6d25e14e350a AS php8.1
FROM php:8.2-fpm-alpine@sha256:3977c73c4953104322c4f752c1f8bbff2ca827edd89a3ec97299d2ca10304c12 AS php8.2
FROM php:8.3-fpm-alpine@sha256:6ad8d400fff9de2b39b3558bd4bd40aafc16ad310d007cf7af8bd6c05419d0a3 AS php8.3
FROM php:8.4-fpm-alpine@sha256:4a746bcf1b58a93605d0abab1ae3ce0fac7c7f20a83b3fa641f506bfa0269209 AS php8.4

## Helper images
FROM blackfire/blackfire:2@sha256:489a27a637a0c857b24ac253a38215b3ad7e21e07b9b1dfc87c6389ebeef78aa AS blackfire
FROM composer:2@sha256:d9d52c36baea592479eb7e024d4c1afaba9bdea27d67566c588d290a31b4b0d1 AS composer
FROM mlocati/php-extension-installer:2@sha256:f7ccc60a7e07cdaf814d53c6eae481a39da4416482b29ac772564a737ad9b48a AS php-extension-installer

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
ENV GIT_CEILING_DIRECTORIES="${workdir}"
ENV PATH="${workdir}/vendor/bin:${PATH}"
ENV PHP_DOCUMENT_ROOT="${workdir}/web"
ENV PHP_SENDMAIL_PATH="/usr/bin/msmtp --read-recipients --read-envelope-from"

ENTRYPOINT [ "/sbin/tini", "--", "php-fpm-entrypoint" ]
CMD [ "php-fpm" ]
