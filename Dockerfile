ARG php="8.2"

## Base PHP images
FROM php:8.0-fpm-alpine@sha256:6c4b8ba35f935851213a6415de85556acaa7c9431cbf8dd59d2465f3d36d49b2 AS php8.0
FROM php:8.1-fpm-alpine@sha256:9068c48794296677bfa3ed2a10e775687614d33cea7a922e02005e77335b3cf6 AS php8.1
FROM php:8.2-fpm-alpine@sha256:8ea546347aa67ebe9d31f0d38598c2ecabe5473f2143661a0159d48d6749490f AS php8.2

## Helper images
FROM blackfire/blackfire:2@sha256:66cae2c5f513f396a6c89dfc77c63f1a9ef7edc4c0ffde1da8e98dd984137eba AS blackfire
FROM composer:2@sha256:622effa24be2e4c4099c2e655d6f88652fa0294605503b41288469bf71e1c198 AS composer
FROM mlocati/php-extension-installer:2@sha256:e183edc7b3d663c7ab317c68f01db9bf7f4bfb0217f5d750faece9a65b2b7dd2 AS php-extension-installer

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
