ARG php="8.2"

## Base PHP images
FROM php:8.0-fpm-alpine@sha256:5231260b03139000ac3884896e70b01fb2f1b767ec4db496dfa4a6c5f5dd2464 AS php8.0
FROM php:8.1-fpm-alpine@sha256:c8d6c3c8912ceab990232bf0e9f2761cc7981b2f2364178bd2b6f7f212f61c4a AS php8.1
FROM php:8.2-fpm-alpine@sha256:f8bb977c4abe7a4e0c9c64f13cfb959a949d4e2d076b90e070034013d832d759 AS php8.2

## Helper images
FROM blackfire/blackfire:2@sha256:974e3c6a027c8e9bb37adb40285a22fe27a6514c2e0505486dbd88a5492b7ab4 AS blackfire
FROM composer:2@sha256:7c03aa544494973299998db9e51f3c4ca880f2d51475b78a4bca4214a8a4fe82 AS composer
FROM mlocati/php-extension-installer:2@sha256:a40d9155260ed303be5de24bac5d30bdd43da8b0610a8776b9d166f4278e570d AS php-extension-installer

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
