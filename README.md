# Docker PHP FPM images for development use

This is a PHP FPM Docker image tuned to be used in Docker Compose
setups for development environments.

We have tried to hit a sweet stuff between not doing too much magic,
but still be an easy fit for how we do work at [Reload
A/S](https://reload.dk).

A simple example of usage would be having a `php` service providing
FPM like this:

```yaml
services:
  php:
    image: 'ghcr.io/reload/php-fpm:8.3'
    ports:
      - '9000'
    user: '${UID:-501}:${GID:-20}'
    volumes:
      - '.:/var/www'
    environment:
      USE_FEATURES: >-
        root-php-ini
 ```

## PHP versions

We provide PHP 8.1, 8.2, 8.3 and 8.4 images.

The images are based on the official [`php:8.x-fpm-alpine` Docker
images](https://hub.docker.com/_/php). We build new images when new
upstream versions are released.

The image has some PHP settings set for development / debugging use,
see
[`debug.ini`](/blob/main/context/usr/local/etc/php/conf.d/debug.ini). They
can be disabled with `no-debug` feature mentioned later in this
document.

## User

The images are designed to be able to run as root inside the container
or as UID `501` (macOS typical user ID) or UID `1000` (Linux typical
user ID). Other user ID's might work as well.

This being an image for development use, we have installed `sudo` and
configured all users in the container to use it without providing a
password.

## Volumes

We recommend mounting the project root of your repository into the
Docker workdir, `/var/www`.

## PHP Document root

FPM expects PHP's document root to be located in `/var/www/web`. That
would be a `web` folder inside your project root if you follow our
practice.

If you would like the document root to be located elsewhere, you
should set the environment variable `PHP_DOCUMENT_ROOT` to the desired
location.

## PHP extensions

The images come with the following extensions installed and enabled:

- apcu
- bcmath
- calendar
- ctype
- curl
- dom
- exif
- fileinfo
- ftp
- gd
- gettext
- iconv
- imagick
- intl
- json
- mbstring
- memcache
- memcached
- mysqli
- mysqlnd
- opcache
- pdo
- pdo_mysql
- pdo_sqlite
- phar
- posix
- readline
- redis
- shmop
- simplexml
- soap
- sockets
- sqlite3
- sysvmsg
- sysvsem
- sysvshm
- tokenizer
- xml
- xmlreader
- xmlwriter
- xsl
- zip

In addition, the `blackfire` and `xdebug` extensions are installed but
not enabled in the images.

The
[php-extension-installer](https://github.com/mlocati/docker-php-extension-installer)
tool is installed if you want to install additional extensions
yourself.

## Entry point scripts

If you place executables (e.g., by mounting them there) in
`/etc/entrypoint.d` they will be run before starting FPM.

## Reloading php-fpm

If you have changed PHP configuration or enabled or disabled some PHP
extensions, you can restart the `php-fpm` process with the
`/usr/local/bin/reload` command. E.g.

```console
docker compose exec php reload
```

## "Features"

The images come with a concept called "features".

Features a predefined entry point scripts with common functionality
you can opt in to using.

Features a run before the entry point scripts mentioned before.

You opt in to using them by setting the `USE_FEATURES` to a space
separated list of their names.

### `install-composer-extensions` feature

If you have a `composer.json` in your workdir (`/var/www`) this
feature will locate required dependencies on PHP extensions `ext-*`
and install them using the aforementioned `php-extension-installer`
tool.

Notice: if this needs to install numerous libraries and do a lot of
compilation, this could take quite some time when creating the
container.

### `root-php-ini` feature

If you have a `php.ini` in your workdir (`/var/www`) this will be
loaded by FPM.

### `no-debug` feature

Disable the PHP ini settings in
[`debug.ini`](/blob/main/context/usr/local/etc/php/conf.d/debug.ini).

### `update-ca-certificates`

If your container needs to use custom CA certificates, place them in
`/usr/local/share/ca-certificates/` using volumes and using the
feature `update-ca-certificates`.

```yaml
services:
  php:
    image: 'ghcr.io/reload/php-fpm:8.3'
    volumes:
      - '.:/var/www'
      - './my-ca.pem:/usr/local/share/ca-certificates/my-ca.pem:ro'
    environment:
      USE_FEATURES: >-
        update-ca-certificates
 ```

## Xdebug

Xdebug is disabled by default, but the extension is available. To
enable the xdebug-extension execute `/usr/local/bin/xdebug` via
Docker, e.g.,

```console
docker exec -it <container id> xdebug
```

Or via Docker Compose, e.g., if the image is used by a service called
`php`:

```console
docker compose exec php xdebug
```

The script keeps xdebug enabled while running and is terminated by
typing enter.

## Blackfire

To send profiles to Blackfire, you'll need to have a Blackfire agent,
reachable by the php-fpm image and the appropriate credentials.

Providing an agent in docker compose is easy, as it's just starting
the original Blackfire image.

```yaml
  php:
    image: 'ghcr.io/reload/php-fpm:8.3'
    environment:
      BLACKFIRE_CLIENT_ID: <your client key>
      BLACKFIRE_CLIENT_TOKEN: <your client token>
  blackfire:
    image: 'blackfire/blackfire'
    environment:
      BLACKFIRE_SERVER_ID: <your server key>
      BLACKFIRE_SERVER_TOKEN: <your server token>
```

The correct ID's and tokens can be found by viewing the [Blackfire
setup documentation](https://blackfire.io/docs/php/configuration) when
logged in.

## Mail

The image has [`mstmp`](https://marlam.de/msmtp/) installed. `msmtp`
is an SMTP client.

For simple development setups, we recommend combining it with
[Mailpit](https://github.com/axllent/mailpit):

```yaml
  php:
    image: 'ghcr.io/reload/php-fpm:8.3'
    environment:
      SMTPSERVER: 'mail'
  mail:
    image: 'axllent/mailpit'
    ports:
      - '25'
      - '80'
    environment:
      MP_SMTP_BIND_ADDR: '0.0.0.0:25'
      MP_UI_BIND_ADDR: '0.0.0.0:80'
```

For more advanced usages, you can add a system-wide configuration file
for msmtp at `/etc/msmtprc` in the php-fpm image.
