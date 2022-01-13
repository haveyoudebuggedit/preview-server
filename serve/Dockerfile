FROM nginx

ENV ROOT_DOMAIN=example.com

COPY nginx.conf /etc/nginx/nginx.conf
RUN useradd -rm -d "/var/www" -s /bin/bash -u 1000 "deploy" && \
    useradd -rm -d "/var/www" -s /bin/bash -u 1001 "www" && \
    rm -rf /var/www && \
    mkdir -p /var/www/ /var/www/previews /var/www/deployments && \
    chown -R deploy:www /var/www && \
    chmod 0750 /var/www

HEALTHCHECK --start-period=10s CMD curl http://127.0.0.1

USER 1000