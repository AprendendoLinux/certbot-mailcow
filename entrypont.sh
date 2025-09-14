#!/bin/bash

# Roda o script
/usr/local/bin/docker-certbot

# Aguarda um breve momento para garantir que o crond inicie
sleep 1

# Inicia o serviço crond em segundo plano comnivel de log
/usr/sbin/crond -f -l 1 2
