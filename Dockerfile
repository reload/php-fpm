ARG php="8.3"

## Base PHP images
FROM php:8.1-fpm-alpine@sha256:a84e0422af72d9a60a8f73756b622bcd37c5a8f85609e43e0a6e16c0a1a7820e AS php8.1
FROM php:8.2-fpm-alpine@sha256:8037f541f2d5ccfe1a9c90c1e2cfe4005c5e879bacb2f3a0cdf50268293c16ed AS php8.2
FROM php:8.3-fpm-alpine@sha256:25c27116b3c8e0e5e0a7ddadc26ed03b73ee7641a38fce37abae0425af56a1a9 AS php8.3
FROM php:8.4-fpm-alpine@sha256:c2cab9d2e743ffc879bd946317d454b5bbb439e480c9a96d6258afec212d0e06 AS php8.4
FROM php:8.5-fpm-alpine@sha256:61d907150e23483d73402c290c5654297a177f28fbf1f5d52359d6ce9025b260 AS php8.5

## Helper images
FROM blackfire/blackfire:2@sha256:1a318548f9a71db4f8fdf2125a0892ec73aab5740e769c51d8b0ca14b01b7964 AS blackfire
FROM composer:2@sha256:f746ca10fd351429e13a6fc9599ccd41d4fc413e036ae8b0dad9e2041adcffcd AS composer
FROM mlocati/php-extension-installer:2@sha256:84950d61e2873817f814fd2c486d0143566a5b7aa36b9c926a138dafb9a07753 AS php-extension-installer

## Custom PHP image
# hadolint ignore=DL3006
FROM php${php}

ARG php=${php}
ARG php_enable_extensions="apcu bcmath calendar ctype curl dom exif fileinfo ftp gd gettext iconv intl imagick json mbstring memcached mysqli mysqlnd opcache pdo pdo_mysql pdo_sqlite phar posix readline redis shmop simplexml soap sockets sqlite3 sysvmsg sysvsem sysvshm tokenizer xml xmlreader xmlwriter xsl zip"

HEALTHCHECK --interval=10s --start-period=90s CMD netstat -ltn | grep -c ":9000"

COPY context/ /

COPY --from=php-extension-installer /usr/bin/install-php-extensions /usr/bin

RUN <<EOT
    set -eux
    apk add --no-cache bash=~5 git=~2 jq=~1 mariadb-client=~11 msmtp=~1 patch=~2 "poppler-utils>=24" unzip=~6 graphicsmagick=~1 sudo=~1 tini=~0
    install-php-extensions ${php_enable_extensions}
    if [ "${php}" = "8.5" ]; then install-php-extensions websupport-sk/pecl-memcache@main; fi
    if [ "${php}" != "8.5" ]; then install-php-extensions memcache; fi
    IPE_DONT_ENABLE=1 install-php-extensions blackfire xdebug
    adduser -H -D -S -G wheel -u 501 machost
    adduser -H -D -S -G wheel -u 1000 linuxhost
EOT

COPY --from=blackfire /usr/local/bin/blackfire /usr/bin
COPY --from=composer /usr/bin/composer /usr/bin

SHELL ["/bin/ash", "-eo", "pipefail", "-c"]
RUN curl https://endoflife.date/api/php/${php}.json| jq '{support,eol,lts}' > /etc/eol.json

ARG workdir=/var/www
WORKDIR "${workdir}"

ENV COMPOSER_CACHE_DIR="/tmp/composer-cache"
ENV PATH="${workdir}/vendor/bin:${PATH}"
ENV PHP_DOCUMENT_ROOT="${workdir}/web"
ENV PHP_SENDMAIL_PATH="/usr/bin/msmtp --read-recipients --read-envelope-from"

ENTRYPOINT [ "/sbin/tini", "--", "php-fpm-entrypoint" ]
CMD [ "php-fpm" ]
