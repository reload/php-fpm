ARG php="8.2"

## Base PHP images
FROM php:8.0-fpm-alpine@sha256:b54f77ba8fe72256b065d12abbe1b2486c8bde322fa77afc59be87b4693cab6b AS php8.0
FROM php:8.1-fpm-alpine@sha256:23ed2079988481279436e8ecacddb6e94507b766b4655daf1ad21647961be99a AS php8.1
FROM php:8.2-fpm-alpine@sha256:b76665c0dab82d9b20074be6b6999027cbee075e5dad5e99b91c062d750e6701 AS php8.2

## Helper images
FROM blackfire/blackfire:2@sha256:c58e3d1778fa34c35f92c9fb5a893f8d4c6e9740f38f61330a27636270fcaf1f AS blackfire
FROM composer:2@sha256:dd04fd83caef4d59ccfa0b760e49869be2ec4ce1bd23e230fb74c80a6b5391be AS composer
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
