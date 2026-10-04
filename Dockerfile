FROM php:7.4.33-apache@sha256:c9d7e608f73832673479770d66aacc8100011ec751d1905ff63fae3fe2e0ca6d

RUN docker-php-ext-install pdo_mysql \
    && a2enmod rewrite headers

COPY docker/lab.ini /usr/local/etc/php/conf.d/zz-adianti-lab.ini
COPY docker/apache-lab.conf /etc/apache2/conf-available/adianti-lab.conf

RUN a2enconf adianti-lab

WORKDIR /var/www/html
