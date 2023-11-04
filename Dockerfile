ARG php="8.2"

## Base PHP images
FROM php:8.0-fpm-alpine@sha256:173daec831fa47844c876258a19741c7a1928524b5e1936a2b1e7c1f58ec1b12 AS php8.0
FROM php:8.1-fpm-alpine@sha256:53b41cf30f082d8d6f05ae6c718226e230805b309045fbfc40732907829be123 AS php8.1
FROM php:8.2-fpm-alpine@sha256:c0fca44d0e3f6bf9555bb8bafa2402fe278f0f947afc4a30729deba5e3f50410 AS php8.2
FROM php:8.3-rc-fpm-alpine@sha256:0fd27d03937fceed301c946f4d08b5c0946e67069b9c2053d3d221b49e84960a AS php8.3

## Helper images
FROM blackfire/blackfire:2@sha256:8e29a1ea0ff2500e196881650f9826ebf27aa763cc7edeb750a145b73ac49cf2 AS blackfire
FROM composer:2@sha256:fb3c5a283f2dc08e08841048498e8a82c3864648c84255b5ad7243b38d33a8db AS composer
FROM mlocati/php-extension-installer:2@sha256:b3efbf19c140bbd85033f7cd15329e394bd36aaa919eee8b2217f271da9749ec AS php-extension-installer

## Custom PHP image
# hadolint ignore=DL3006
FROM php${php}

ARG php=${php}
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
