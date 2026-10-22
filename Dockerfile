# Optional argument to select base image.
# Example:
# docker build . \
#  --build-arg APP_BASE_IMAGE=211125698795.dkr.ecr.us-east-1.amazonaws.com/base-php-fpm:None-debian
ARG PHP_VERSION=None
ARG APP_BASE_IMAGE=211125698795.dkr.ecr.us-east-1.amazonaws.com/base-php-fpm:${PHP_VERSION}-debian
ARG NODE_IMAGE=node:lts-slim
ARG APP_DIR=/srv/app/current

FROM ${APP_BASE_IMAGE} AS service
ARG APP_DIR

# ENV PHP_FPM_PM_MAX_CHILDREN=500 \
#     PHP_FPM_PM_MAX_REQUESTS=500

RUN echo "List of installed extensions: " && \
    php -m
# expected output like this: mbstring pdo curl xml ctype tokenizer fileinfo

# This is example only of how to add regular php extensions (extensions below is already installed in base image)
# RUN docker-php-ext-install sockets zip pdo_mysql bcmath

# this is example only how to add pecl extensions (redis already installed in base image)
# RUN pecl install redis && \
#     rm -rf /tmp/pear && \
#     docker-php-ext-enable redis

# See base images readme for more php and php-fpm tuning options.
# Also it is possible to override these values in kustomize environment overlay.
# ENV PHP_FPM_PM_MAX_CHILDREN=500 \
#     PHP_FPM_PM_MAX_REQUESTS=500
WORKDIR ${APP_DIR}
COPY . ./

RUN ls -la ${APP_DIR}

RUN mkdir -p -m 0700 ~/.ssh && \
    ssh-keyscan github.com >> ~/.ssh/known_hosts

RUN --mount=type=ssh composer install \
    --optimize-autoloader \
    --no-progress \
    --no-interaction \
    --classmap-authoritative \
    --no-dev

# RUN ln -sf /dev/stdout storage/logs/general.log

# Uncomment and modify if you need to replace something on the fly using env variables
# RUN envsubst < ${APP_DIR}/.env.example > ${APP_DIR}/.env

# setup permissons
RUN chown -R www-data:www-data ${APP_DIR} && \
    chmod -R 775 ${APP_DIR}/storage ${APP_DIR}/bootstrap/cache

# Laravel workers under supervisor in the app pod. The 4 leading spaces inside each
# echoed path must be preserved so supervisord reads them as [include] entries.
# event-bus:work follows the event-bus subscription; queue:work and the scheduler are opt-in.
# The scheduler runs schedule:run on every replica — enable only when a K8s CronJob isn't already doing it.

USER www-data