ARG php="8.2"

## Base PHP images
FROM php:8.0-fpm-alpine@sha256:2bc92340a0e10466527947c858d4219a1fb8ce6882220cdc1f641ca19ab55682 AS php8.0
FROM php:8.1-fpm-alpine@sha256:4c1c0464c0e0a2b9782f029548e32f99333541569ad343c3eb1e7c82ceb22de5 AS php8.1
FROM php:8.2-fpm-alpine@sha256:1c499a0d6ba8ac079a820a06403e520d632ba56b8f4098191baca2946b9c9bfd AS php8.2

## Helper images
FROM blackfire/blackfire:2@sha256:a99fae2e0213534f4da2c6a0fc59d9a1282b6edb6abdc6d21e15eb8a03de743c AS blackfire
FROM composer:2@sha256:a43a90c9e746f6c3f967cd3489ed0d0ddc6b09f666f3f93ebc8aeb3aa94a562a AS composer
FROM mlocati/php-extension-installer:2@sha256:c16e0e6ddea36ced2fe5380e4bdcb5aab6abb77c966f87fd111445b9505d283f AS php-extension-installer

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
