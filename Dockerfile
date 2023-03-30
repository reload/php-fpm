ARG php="8.2"

## Base PHP images
FROM php:8.0-fpm-alpine@sha256:6c4b8ba35f935851213a6415de85556acaa7c9431cbf8dd59d2465f3d36d49b2 AS php8.0
FROM php:8.1-fpm-alpine@sha256:9068c48794296677bfa3ed2a10e775687614d33cea7a922e02005e77335b3cf6 AS php8.1
FROM php:8.2-fpm-alpine@sha256:8ea546347aa67ebe9d31f0d38598c2ecabe5473f2143661a0159d48d6749490f AS php8.2

## Helper images
FROM blackfire/blackfire:2@sha256:c58e3d1778fa34c35f92c9fb5a893f8d4c6e9740f38f61330a27636270fcaf1f AS blackfire
FROM composer:2@sha256:7ac744b7fab81c0662c13163b9570a0a2c9e0667bc23bc15957182e4e808fd20 AS composer
FROM mlocati/php-extension-installer:2@sha256:7de4ad3b096f7e689d532ed49fa44c78017bea2c7faf0b6eac8518ce0f1b67fc AS php-extension-installer

## Custom PHP image
# hadolint ignore=DL3006
FROM php${php}

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

ARG workdir=/var/www
WORKDIR "${workdir}"

ENV COMPOSER_CACHE_DIR="/tmp/composer-cache"
ENV GIT_CEILING_DIRECTORIES="${workdir}"
ENV PATH="${workdir}/vendor/bin:${PATH}"
ENV PHP_DOCUMENT_ROOT="${workdir}/web"
ENV PHP_SENDMAIL_PATH="/usr/bin/msmtp --read-recipients --read-envelope-from"

ENTRYPOINT [ "/sbin/tini", "--", "php-fpm-entrypoint" ]
CMD [ "php-fpm" ]
