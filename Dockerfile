ARG php="8.3"

## Base PHP images
FROM php:8.2-fpm-alpine@sha256:913fab09564477f2d4fee22e6cdb7d9f88a93c6d201f7d728d347489a70581d6 AS php8.2
FROM php:8.3-fpm-alpine@sha256:1180fcd9c96923142c08b3bb6b7fac865dbf3c802fc9f42982e5323aedee97a8 AS php8.3
FROM php:8.4-fpm-alpine@sha256:c0e41e0c856bf97b2e749f40a804031ce938d0d496c4c7d91ad416d993172826 AS php8.4
FROM php:8.5-fpm-alpine@sha256:51414d5291758fe27f58a64c7e8a078465d32cc7dcef7bda803f5b36019802e0 AS php8.5
FROM php:8.6-fpm-alpine@sha256:3892978a38794b348f73d6926fb63e352b5338f8b302cdd2cf0ed968f63b50c5 AS php8.6

## Helper images
FROM blackfire/blackfire:2026.11.1@sha256:b4e4ec50c6d5326752e77cb2681de63e1f79a86da36cd85838aee8d329ff9090 AS blackfire
FROM composer:2@sha256:f746ca10fd351429e13a6fc9599ccd41d4fc413e036ae8b0dad9e2041adcffcd AS composer
FROM mlocati/php-extension-installer:2@sha256:584fcc217b94a10187367552f6571cd8680ee4bf22bd752f1087a7d55e35e7de AS php-extension-installer

## Custom PHP image
# hadolint ignore=DL3006
FROM php${php}

ARG php=${php}
ARG php_enable_extensions="apcu bcmath brotli calendar ctype curl dom exif fileinfo ftp gd gettext iconv intl imagick json mbstring memcached mysqli mysqlnd opcache pcntl pdo pdo_mysql pdo_pgsql pdo_sqlite phar posix readline redis shmop simplexml soap sockets sqlite3 sysvmsg sysvsem sysvshm tokenizer xml xmlreader xmlwriter xsl zip"

HEALTHCHECK --interval=10s --start-period=90s CMD [ "sh", "-c", "netstat -ltn | grep -c :9000" ]

COPY context/ /

COPY --from=php-extension-installer /usr/bin/install-php-extensions /usr/bin

SHELL [ "/bin/ash", "-eo", "pipefail", "-c" ]

# The extension list must split into words.
# hadolint ignore=SC2086
RUN <<EOT
    set -eux
    apk add --no-cache bash=~5 git=~2 jq=~1 mariadb-client=~11 msmtp=~1 oniguruma-dev=~6 patch=~2 "poppler-utils>=24" unzip=~6 graphicsmagick=~1 sudo=~1 tini=~0
    docker-php-ext-install mbstring # Bootstrap mbstring extention for use by `install-php-extensions`
    if [ "${php}" = "8.6" ]; then
        # The PECL releases of apcu, imagick, memcache, memcached, redis
        # and xdebug do not build against PHP 8.6 yet. Build apcu,
        # imagick, memcached and xdebug from upstream commits that
        # support PHP 8.6. Leave out memcache and redis until upstream
        # merges their PHP 8.6 fixes.
        for extension in apcu imagick memcached redis; do
            php_enable_extensions=$(echo " ${php_enable_extensions} " | sed "s/ ${extension} / /")
        done
        install-php-extensions ${php_enable_extensions} Imagick/imagick@55ed2e9fda264395636a2e27e51f31673f5566ab
        # The apcu package.xml version (5.1.29-dev) makes `pecl` fail, and
        # memcached has a new configure question that `install-php-extensions`
        # does not expect. Build both with `docker-php-ext-install` instead.
        apk add --no-cache libmemcached-libs=~1
        apk add --no-cache --virtual .build-deps libmemcached-dev=~1 zlib-dev=~1
        mkdir -p /usr/src/apcu /usr/src/memcached
        curl -fsSL https://github.com/krakjoe/apcu/archive/fb2c942552a3f5dab7f4dea4afb5cf0831222c57.tar.gz | tar -xz --strip-components=1 -C /usr/src/apcu
        curl -fsSL https://github.com/php-memcached-dev/php-memcached/archive/0b52d3657140750fa0eddd20cdbfc6edc8fbdadd.tar.gz | tar -xz --strip-components=1 -C /usr/src/memcached
        docker-php-ext-configure /usr/src/memcached --disable-memcached-igbinary --disable-memcached-msgpack --enable-memcached-json --disable-memcached-protocol --enable-memcached-sasl --enable-memcached-session
        docker-php-ext-install /usr/src/apcu /usr/src/memcached
        apk del .build-deps
        rm -rf /usr/src/apcu /usr/src/memcached
        IPE_DONT_ENABLE=1 install-php-extensions blackfire xdebug/xdebug@5e19866c1766e38c527f9f94faa170370dc4209f
    else
        install-php-extensions ${php_enable_extensions}
        if [ "${php}" = "8.5" ]; then install-php-extensions websupport-sk/pecl-memcache@main; fi
        if [ "${php}" != "8.5" ]; then install-php-extensions memcache; fi
        IPE_DONT_ENABLE=1 install-php-extensions blackfire xdebug
    fi
    adduser -H -D -S -G wheel -u 501 machost
    adduser -H -D -S -G wheel -u 1000 linuxhost
EOT

COPY --from=blackfire /usr/local/bin/blackfire /usr/bin
COPY --from=composer /usr/bin/composer /usr/bin

# endoflife.date answers 404 for a PHP version that is not released yet.
# Then the support and end-of-life dates are null and no warnings show.
RUN <<EOT
    status=$(curl -sS -o /tmp/eol.json -w '%{http_code}' "https://endoflife.date/api/php/${php}.json")
    if [ "${status}" = "404" ]; then echo '{}' > /tmp/eol.json; elif [ "${status}" != "200" ]; then exit 1; fi
    jq '{support,eol,lts}' /tmp/eol.json > /etc/eol.json
    rm /tmp/eol.json
EOT

ARG workdir=/var/www
WORKDIR "${workdir}"

ENV COMPOSER_CACHE_DIR="/tmp/composer-cache"
ENV PATH="${workdir}/vendor/bin:${PATH}"
ENV PHP_DOCUMENT_ROOT="${workdir}/web"
ENV PHP_SENDMAIL_PATH="/usr/bin/msmtp --read-recipients --read-envelope-from"

ENTRYPOINT [ "/sbin/tini", "--", "php-fpm-entrypoint" ]
CMD [ "php-fpm" ]
