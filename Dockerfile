ARG php="8.2"

## Base PHP images
FROM php:8.0-fpm-alpine@sha256:6c4b8ba35f935851213a6415de85556acaa7c9431cbf8dd59d2465f3d36d49b2 AS php8.0
FROM php:8.1-fpm-alpine@sha256:f9474fa2dde6b61958737ed9eec6e0e4f5bf5167db42bdd1ac652087ec1ebc2b AS php8.1
FROM php:8.2-fpm-alpine@sha256:5285716b0dbb46679c07bfcbf8bb01d1d7f6224628f176cab9d6bc095f81a17a AS php8.2

## Helper images
FROM blackfire/blackfire:2@sha256:a99fae2e0213534f4da2c6a0fc59d9a1282b6edb6abdc6d21e15eb8a03de743c AS blackfire
FROM composer:2@sha256:2ebb1374af89af9060ee71a15b7f5f626e8a23d8e2ed9366ef151e519630e685 AS composer
FROM mlocati/php-extension-installer:2@sha256:411199c389824c50ce90afbd79e279db510a3776c42e5ad28bddba31cef7f74e AS php-extension-installer

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
