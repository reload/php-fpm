ARG php="8.2"

## Base PHP images
FROM php:8.0-fpm-alpine@sha256:173daec831fa47844c876258a19741c7a1928524b5e1936a2b1e7c1f58ec1b12 AS php8.0
FROM php:8.1-fpm-alpine@sha256:a13add2aa7bdf1debe91ec56ba951823261295c907e00c2b6ffec69e842ba992 AS php8.1
FROM php:8.2-fpm-alpine@sha256:f445071227e858c52d0aab62372ad4a7b4f939584fd8df3ef04071f953571f1e AS php8.2
FROM php:8.3-fpm-alpine@sha256:f3249e872fc3d01493e22774d92757591d28bb8e4b20dc574ff2878a8efb68e7 AS php8.3

## Helper images
FROM blackfire/blackfire:2@sha256:a701c54bdba874443b76ce27d2a6fbbe30e8ee517eb38823df4337b3461eef69 AS blackfire
FROM composer:2@sha256:65a2e581e5393b16936e72b592dc75ffe9bd28196a9d2fa9b42bab484e6990fa AS composer
FROM mlocati/php-extension-installer:2@sha256:ec28e7f57df76424cf3c46cc30ebcdbeb30e9305910828e6ba338fe16b9ab74b AS php-extension-installer

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
