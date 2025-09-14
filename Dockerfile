# Usar imagem base Alpine
FROM alpine:latest

# Definir mantenedor
LABEL maintainer="Henrique Fagundes <henrique@henrique.tec.br>"

# Definir argumentos para TimeZone
ARG TZ=America/Sao_Paulo

RUN apk update \
    && apk upgrade \
    && apk add \
    tzdata \
    bash \
    python3 \
    py3-pip \
    python3-dev \
    musl-dev \
    libffi-dev \
    gcc \
    openssl-dev \
    make \
    && rm -rf /var/cache/apk/* \
    && sed -i 's/root:x:0:0:root:\/root:\/bin\/sh/root:x:0:0:root:\/root:\/bin\/bash/' /etc/passwd \
    && bash \
    && cp /usr/share/zoneinfo/${TZ} /etc/localtime \
    && echo "${TZ}" > /etc/timezone \
    && python3 -m venv /opt/certbot \
    && source /opt/certbot/bin/activate \
    && pip install --upgrade pip \
    && pip install \
    certbot \
    certbot-dns-cloudflare \
    && pip cache purge \
    && deactivate \
    && ln -sf /dev/stdout /var/log/certificados.log

COPY ./entrypont.sh /entrypont.sh
COPY ./docker-certbot /usr/local/bin/docker-certbot

RUN echo "0 */6 * * * /usr/local/bin/docker-certbot" >> /etc/crontabs/root \
	&& chmod +x /entrypont.sh /usr/local/bin/docker-certbot

VOLUME ["/etc/letsencrypt", "/var/log/letsencrypt"]

ENTRYPOINT ["/entrypont.sh"]
