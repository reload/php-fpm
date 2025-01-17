ARG php="8.3"

## Base PHP images
FROM php:8.1-fpm-alpine@sha256:7aa2fdbecb57e55500c34804913c77aafddbbc0ad16b199f302de811d879a71f AS php8.1
FROM php:8.2-fpm-alpine@sha256:383bb5ca709d9e6b44736684eb837cff4ecacbc8bed69c083074d65e2937fc29 AS php8.2
FROM php:8.3-fpm-alpine@sha256:1a63b88442974e176f14842a70ab21691827ee68711033b72c94a47b053c0311 AS php8.3
FROM php:8.4-fpm-alpine@sha256:e0193902cbbfd8e830fe593a231f901bedf15d6f1897cdda7509aad5aeb54337 AS php8.4

## Helper images
FROM blackfire/blackfire:2@sha256:7fcbf4efcf1539a644fd0c8d9cd028bfbdb0832a5fc889c101048c125dcd5691 AS blackfire
FROM composer:2@sha256:26bbf85fccb36247181de6f4a2beddac47d4b352c0c19249a3b4fa2abf1e38ad AS composer
FROM mlocati/php-extension-installer:2@sha256:ad5e1b633d7be95709c10be626952000fc1a8ce6e7f441ed723b090fcef29015 AS php-extension-installer

## Custom PHP image
# hadolint ignore=DL3006
FROM php${php}

ARG php=${php}
ARG php_enable_extensions="apcu bcmath calendar ctype curl dom exif fileinfo ftp gd gettext iconv imagick intl json mbstring memcache memcached mysqli mysqlnd opcache pdo pdo_mysql pdo_sqlite phar posix readline redis shmop simplexml soap sockets sqlite3 sysvmsg sysvsem sysvshm tokenizer xml xmlreader xmlwriter xsl zip"

HEALTHCHECK --interval=10s --start-period=90s CMD netstat -ltn | grep -c ":9000"

COPY context/ /

COPY --from=php-extension-installer /usr/bin/install-php-extensions /usr/bin

RUN <<EOT
    set -eux
    apk add --no-cache bash=~5 git=~2 jq=~1 mariadb-client=~11 msmtp=~1 patch=~2 unzip=~6 graphicsmagick=~1 sudo=~1 tini=~0
    install-php-extensions ${php_enable_extensions}
    if [ "${php}" != "8.4" ]; then IPE_DONT_ENABLE=1 install-php-extensions blackfire; fi
    IPE_DONT_ENABLE=1 install-php-extensions xdebug
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
