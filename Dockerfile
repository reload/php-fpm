ARG php="8.2"

## Base PHP images
FROM php:8.0-fpm-alpine@sha256:6c4b8ba35f935851213a6415de85556acaa7c9431cbf8dd59d2465f3d36d49b2 AS php8.0
FROM php:8.1-fpm-alpine@sha256:35d14c74fa777025c7c34f70e3514f17b011d5677c67c1067b1fb5eb8c02f835 AS php8.1
FROM php:8.2-fpm-alpine@sha256:5285716b0dbb46679c07bfcbf8bb01d1d7f6224628f176cab9d6bc095f81a17a AS php8.2

## Helper images
FROM blackfire/blackfire:2@sha256:fafe520a09252ae189ff5e3b69a70ff7e2c0e5ef04f81e53df0f662c91842f13 AS blackfire
FROM composer:2@sha256:d718bf3b9e308a8616a12924c5e74ef565a44f83264191bb0e37aafee5254134 AS composer
FROM mlocati/php-extension-installer:2@sha256:d71e64e19ccb107744140201c892bb4b2e4d02bca119de87aaa5cce0fb869aed AS php-extension-installer

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
