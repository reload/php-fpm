## Helper images
FROM blackfire/blackfire:2@sha256:c58e3d1778fa34c35f92c9fb5a893f8d4c6e9740f38f61330a27636270fcaf1f AS blackfire
FROM composer:2@sha256:356d2db112a3e4c0fbcf4955668d3f64ee43f848baf4fd20f00cfcb6f98245ad AS composer
FROM mlocati/php-extension-installer:1@sha256:94e21d8175d3a06a4332f79a2d3e6285007ce6e0661c559d4e6fcb74fdb97b9b AS php-extension-installer

## Custom PHP image
# hadolint ignore=DL3006
FROM reload-php

ARG php_enable_extensions="bcmath calendar ctype curl dom exif fileinfo ftp gd gettext iconv imagick intl json mbstring memcache memcached mysqli mysqlnd opcache pdo pdo_mysql pdo_sqlite phar posix readline redis shmop simplexml soap sockets sqlite3 sysvmsg sysvsem sysvshm tokenizer xml xmlreader xmlwriter xsl zip"
ARG php_install_extensions="xdebug"

HEALTHCHECK CMD netstat -ltn | grep -c ":9000"

COPY context/ /

COPY --from=blackfire /usr/local/bin/blackfire /usr/bin
COPY --from=composer /usr/bin/composer /usr/bin
COPY --from=php-extension-installer /usr/bin/install-php-extensions /usr/bin

RUN apk add --no-cache bash=~5 git=~2 mariadb-client=~10 msmtp=~1 patch=~2 unzip=~6 && \
    install-php-extensions ${php_enable_extensions} && \
    IPE_DONT_ENABLE=1 install-php-extensions ${php_install_extensions}

ENV PHP_SENDMAIL_PATH="/usr/bin/msmtp --read-recipients"

ENTRYPOINT [ "reload-php-entrypoint" ]
CMD [ "php-fpm" ]
