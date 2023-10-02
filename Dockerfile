ARG php="8.2"

## Base PHP images
FROM php:8.0-fpm-alpine@sha256:5231260b03139000ac3884896e70b01fb2f1b767ec4db496dfa4a6c5f5dd2464 AS php8.0
FROM php:8.1-fpm-alpine@sha256:63340145fd8930b2d57f7f0a55c95a2640d619d475c46ba170ede575ecade1f7 AS php8.1
FROM php:8.2-fpm-alpine@sha256:a300fd33f1d59ecb9018aa853cfa3be73b38c1fc937cb08752f116fa4fa3cb26 AS php8.2

## Helper images
FROM blackfire/blackfire:2@sha256:a6c5b7b32762ef9ea19ba59ad003f55d48d6263c97ca00c5d3d59d7ba33d9a40 AS blackfire
FROM composer:2@sha256:fd0b4f28a5070d4361d5cbfe7f7807a10bf2efe9396e42009f9e63f7fa307e38 AS composer
FROM mlocati/php-extension-installer:2@sha256:e2caa5f72aa5e21009c1d36e7d5b1ae65abae41907f74c10b8c2b13fb689dcd2 AS php-extension-installer

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
