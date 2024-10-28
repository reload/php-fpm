ARG php="8.2"

## Base PHP images
FROM php:8.0-fpm-alpine@sha256:bbf76d84a693fae1e0d2a259db70c9c47f41bd5a6ec3d339ba397939e7875dd8 AS php8.0
FROM php:8.1-fpm-alpine@sha256:473d821f7cff9a5fe8bd2879c69518afdd2a4396c842607bafcf0a1eefa00eb7 AS php8.1
FROM php:8.2-fpm-alpine@sha256:42e3b846676ef8556edc9bfd0ebc3867780e62c32bd5618f374d9df538c136cd AS php8.2
FROM php:8.3-fpm-alpine@sha256:a3243d8481654bd5c5d7099665d1f4498d3d5d9d45be6bd964a358ecf05f04a5 AS php8.3

## Helper images
FROM blackfire/blackfire:2@sha256:00713cf8ca8401a674d05cde7c8687b7410b4df97da591d451b97253e4259949 AS blackfire
FROM composer:2@sha256:0d9ed84312bc8f0094c372b5074ddf89abffddd6e8b91d46f9d39f98cbd512b4 AS composer
FROM mlocati/php-extension-installer:2@sha256:690a89231b571fca0003dd4383a50cdbe23828612cebf80c4cca6bb10ae3e42e AS php-extension-installer

## Custom PHP image
# hadolint ignore=DL3006
FROM php${php}

ARG php=${php}
ARG php_enable_extensions="apcu bcmath calendar ctype curl dom exif fileinfo ftp gd gettext iconv imagick/imagick@master intl json mbstring memcache memcached mysqli mysqlnd opcache pdo pdo_mysql pdo_sqlite phar posix readline redis shmop simplexml soap sockets sqlite3 sysvmsg sysvsem sysvshm tokenizer xml xmlreader xmlwriter xsl zip"
ARG php_install_extensions="blackfire xdebug"

HEALTHCHECK --interval=10s --start-period=90s CMD netstat -ltn | grep -c ":9000"

COPY context/ /

COPY --from=php-extension-installer /usr/bin/install-php-extensions /usr/bin

RUN <<EOT
    set -eux
    apk add --no-cache bash=~5 git=~2 jq=~1 mariadb-client=~10 msmtp=~1 patch=~2 unzip=~6 graphicsmagick=~1 sudo=~1 tini=~0
    install-php-extensions ${php_enable_extensions}
    IPE_DONT_ENABLE=1 install-php-extensions ${php_install_extensions}
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
ENV GIT_CEILING_DIRECTORIES="${workdir}"
ENV PATH="${workdir}/vendor/bin:${PATH}"
ENV PHP_DOCUMENT_ROOT="${workdir}/web"
ENV PHP_SENDMAIL_PATH="/usr/bin/msmtp --read-recipients --read-envelope-from"

ENTRYPOINT [ "/sbin/tini", "--", "php-fpm-entrypoint" ]
CMD [ "php-fpm" ]
