ARG php="8.2"

## Base PHP images
FROM php:8.0-fpm-alpine@sha256:bbf76d84a693fae1e0d2a259db70c9c47f41bd5a6ec3d339ba397939e7875dd8 AS php8.0
FROM php:8.1-fpm-alpine@sha256:8ac8bf3413dc08471bb8134846018f19ec688c961d2581493bd7fe91cd72b9d2 AS php8.1
FROM php:8.2-fpm-alpine@sha256:1a6fc2aaa306a3c12264b3d1d6832a598e98f1237090ff853dc6af5db8e5a8f2 AS php8.2
FROM php:8.3-fpm-alpine@sha256:17fa7702b3d48eb0c064e3410474c81f703b3bcb7a7fe8073503e6c7f157a29a AS php8.3

## Helper images
FROM blackfire/blackfire:2@sha256:17d628b0d16b1c297c1a346118d8d134e4f43e0c07658cee1bbb316cf693fc0a AS blackfire
FROM composer:2@sha256:26bbf85fccb36247181de6f4a2beddac47d4b352c0c19249a3b4fa2abf1e38ad AS composer
FROM mlocati/php-extension-installer:2@sha256:0b77a6b5d06eda448cd5833ad881208a43a05effd760b4d027ce9ed65f6b6c2f AS php-extension-installer

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
