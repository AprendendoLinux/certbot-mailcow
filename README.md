# Certbot com Cloudflare para Certificados Let's Encrypt

![Certbot Logo](https://img.shields.io/badge/Certbot-v2.11.0-brightgreen) ![Docker](https://img.shields.io/badge/Docker-Supported-blue) ![Cloudflare](https://img.shields.io/badge/Cloudflare-DNS%20Plugin-orange)

## Descrição

Este repositório contém uma solução Dockerizada para gerenciar certificados SSL/TLS gratuitos do Let's Encrypt usando o Certbot, com autenticação via DNS através do plugin para Cloudflare. A imagem é baseada no Alpine Linux para ser leve e eficiente, e é projetada para renovar ou expandir certificados automaticamente para múltiplos domínios wildcard (ex.: `*.exemplo.com.br`).

O foco principal é facilitar a integração com ambientes como Mailcow (ou outros serviços que precisem de certificados compartilhados), permitindo a cópia automática dos certificados gerados para um diretório montado. O container executa o Certbot via cron a cada 6 horas, garantindo renovação automática, e suporta modo "dry-run" para testes sem impacto real.

Esta solução é ideal para administradores de sistemas que gerenciam múltiplos domínios hospedados no Cloudflare, precisando de certificados wildcard para subdomínios dinâmicos. Ela evita a necessidade de exposição de portas HTTP/HTTPS para validação, usando em vez disso a propagação DNS para autenticação.

### Principais Recursos
- **Autenticação DNS via Cloudflare**: Suporte para API do Cloudflare para validar domínios sem necessidade de servidor web exposto.
- **Suporte a Múltiplos Domínios**: Pode lidar com vários domínios wildcard listados em uma variável de ambiente.
- **Renovação Automática**: Cron job configurado para executar o Certbot a cada 6 horas.
- **Cópia de Certificados**: Os certificados gerados são copiados para um diretório montado (ex.: `/certificates`) com nomes padronizados (`cert.pem` e `key.pem`).
- **Modo Dry-Run**: Para simular execuções sem alterar certificados reais.
- **Logs Detalhados**: Todos os passos são logados em `/var/log/certificados.log` para depuração.
- **Imagem Leve**: Baseada em Alpine Linux, com dependências mínimas instaladas.
- **Integração com Docker Compose**: Arquivo de exemplo fornecido para deploy rápido.

Esta imagem está disponível no Docker Hub como `aprendendolinux/certbot-mailcow:latest`. Para uso no GitHub, clone o repositório e construa a imagem localmente.

## Pré-requisitos

Antes de usar esta solução, certifique-se de ter:
- **Docker** instalado (versão 20.10 ou superior recomendada).
- **Docker Compose** (versão 1.29 ou superior) para deploy via `docker-compose.yml`.
- **Conta Cloudflare**: Com acesso à API Global (ou Scoped) para DNS. Você precisará de um e-mail e chave API.
- **Domínios Configurados no Cloudflare**: Os domínios listados em `MY_DOMAINS` devem estar gerenciados pelo Cloudflare para autenticação DNS funcionar.
- **Permissões de Escrita**: No host, certifique-se de que os diretórios montados como volumes tenham permissões adequadas (ex.: `chmod 700` para diretórios sensíveis).
- **Timezone Configurado**: O container usa `America/Sao_Paulo` por padrão, mas pode ser alterado via variável `TZ`.

**Atenção**: Certificados Let's Encrypt são válidos por 90 dias, mas o cron renova automaticamente. Use domínios wildcard (`*.exemplo.com`) para cobrir subdomínios ilimitados.

## Instalação

### Via Docker Hub
Puxe a imagem pré-construída:
```
docker pull aprendendolinux/certbot-mailcow:latest
```

### Construindo Localmente (para GitHub)
Clone o repositório:
```
git clone https://github.com/AprendendoLinux/certbot-mailcow.git
cd certbot-cloudflare-docker
```

Construa a imagem:
```
docker build -t aprendendolinux/certbot-mailcow:latest .
```

### Configuração via Docker Compose
Use o arquivo `docker-compose.yml` fornecido como base. Edite as variáveis de ambiente conforme necessário.

Exemplo de `docker-compose.yml`:
```yaml
services:
  certbot:
    image: aprendendolinux/certbot-mailcow:latest
    restart: always
    container_name: certbot
    hostname: certbot
    volumes:
      - /srv/mailcow-dockerized/data/assets/ssl:/certificates  # Diretório para copiar certificados (ex.: para Mailcow)
      - /srv/certbot/letsencrypt/data:/etc/letsencrypt        # Armazenamento persistente de certificados
      - /srv/certbot/logs:/var/log/letsencrypt                # Logs do Let's Encrypt
    environment:
      - TZ=America/Sao_Paulo                                 # Timezone do container
      - CLOUDFLARE_EMAIL="seu@email.com.br"                  # E-mail da conta Cloudflare
      - CLOUDFLARE_API_KEY="sua-api-da-cloudflare-aqui"      # Chave API Global do Cloudflare
      - MY_DOMAINS="*.dominio1.com.br,*.dominio2.com.br,*.dominio3.com.br,*.dominio4.com.br,*.dominio5.com.br"  # Lista de domínios wildcard separados por vírgula
      - DRY_RUN="false"                                      # "true" para modo de teste (sem alterações reais)
```

Inicie o serviço:
```
docker-compose up -d
```

## Uso

### Executando o Container
Após configurar o `docker-compose.yml`, o container inicia automaticamente o script de entrada (`entrypoint.sh`), que executa o Certbot uma vez e inicia o cron para renovações periódicas.

- **Ver Logs**: Use `docker logs certbot` para ver a saída inicial. Logs detalhados estão em `/var/log/certificados.log` (montado via volume).
- **Forçar Renovação**: Execute manualmente dentro do container: `docker exec -it certbot /usr/local/bin/docker-certbot`.
- **Ver Certificados**: Os arquivos `cert.pem` (fullchain) e `key.pem` (privkey) serão copiados para o diretório `/certificates` montado.

### Variáveis de Ambiente
As seguintes variáveis são obrigatórias e devem ser definidas no `environment` do Docker Compose ou via `docker run -e`:

- `TZ`: Timezone do container (padrão: `America/Sao_Paulo`).
- `CLOUDFLARE_EMAIL`: E-mail associado à conta Cloudflare. Use aspas se necessário, mas o script remove aspas extras.
- `CLOUDFLARE_API_KEY`: Chave API do Cloudflare (Global API Key recomendada para simplicidade).
- `MY_DOMAINS`: Lista de domínios separados por vírgula (ex.: `*.exemplo1.com,*.exemplo2.com`). Suporta wildcards para subdomínios.
- `DRY_RUN`: "true" para simular a execução (útil para testes); "false" para modo real.

Variáveis opcionais:
- `CERT_OUTPUT_DIR`: Diretório para copiar certificados (padrão: `/certificates`).

### Volumes
Monte os seguintes volumes para persistência:
- `/etc/letsencrypt`: Armazena certificados e configurações do Certbot.
- `/var/log/letsencrypt`: Logs do Certbot e script customizado.
- `/certificates`: Diretório de saída para os certificados copiados (integração com outros serviços como Mailcow).

Exemplo em Docker Run:
```
docker run -d \
  --name certbot \
  -v /srv/certbot/letsencrypt/data:/etc/letsencrypt \
  -v /srv/certbot/logs:/var/log/letsencrypt \
  -v /srv/mailcow/ssl:/certificates \
  -e TZ=America/Sao_Paulo \
  -e CLOUDFLARE_EMAIL="seu@email.com" \
  -e CLOUDFLARE_API_KEY="sua-chave" \
  -e MY_DOMAINS="*.exemplo.com" \
  -e DRY_RUN="false" \
  aprendendolinux/certbot-mailcow:latest
```

## Detalhes Técnicos

### Dockerfile
O Dockerfile constrói a imagem a partir do Alpine Linux:
- Atualiza e instala pacotes essenciais: `tzdata`, `bash`, `python3`, `py3-pip`, etc.
- Configura o timezone via `ARG TZ`.
- Cria um virtualenv em `/opt/certbot` e instala `certbot` e `certbot-dns-cloudflare`.
- Copia scripts customizados: `entrypoint.sh` e `docker-certbot`.
- Configura cron para executar `/usr/local/bin/docker-certbot` a cada 6 horas.
- Define volumes para `/etc/letsencrypt` e `/var/log/letsencrypt`.
- Entrypoint: `/entrypoint.sh`.

### Script de Entrada (entrypoint.sh)
- Executa o script `docker-certbot` para geração inicial de certificados.
- Inicia o `crond` em foreground com logs nivelados para monitoramento.

### Script Principal (docker-certbot)
- Ativa o virtualenv do Certbot.
- Verifica variáveis de ambiente obrigatórias.
- Limpa e processa `CLOUDFLARE_EMAIL` e `MY_DOMAINS` (remove aspas e espaços).
- Cria `/etc/cloudflare.ini` com credenciais.
- Monta argumentos para Certbot: `--dns-cloudflare`, `--expand` para wildcards, `--non-interactive`, etc.
- Adiciona `--dry-run` se ativado.
- Executa `certbot certonly` para obter/renovar certificados.
- Copia certificados do primeiro domínio (removendo prefixo wildcard) para `/certificates` como `cert.pem` e `key.pem`.
- Logs todos os passos em `/var/log/certificados.log`.

### Cron Job
Configurado no Dockerfile: `0 */6 * * * /usr/local/bin/docker-certbot` (executa a cada 6 horas).

## Depuração e Solução de Problemas

- **Erro de Variáveis**: Verifique se todas as env vars estão definidas. O script sai com erro se faltar alguma.
- **Falha na Autenticação Cloudflare**: Certifique-se de que a API Key tem permissões para DNS:Edit. Teste com `DRY_RUN=true`.
- **Logs**: Acesse `/var/log/certificados.log` para detalhes. Use `docker cp certbot:/var/log/certificados.log .` para copiar.
- **Certificados Não Copiados**: Verifique se o diretório `/etc/letsencrypt/live/<dominio>` existe após execução.
- **Propagação DNS Lenta**: O script usa `--dns-cloudflare-propagation-seconds 15`; aumente se necessário editando o script.
- **Container Não Inicia**: Verifique permissões nos volumes e se o timezone é válido.

Para mais depuração, entre no container: `docker exec -it certbot bash`.

## Exemplos

### Certificados para Múltiplos Domínios
Defina `MY_DOMAINS="*.site1.com,*.site2.com"` e execute. O Certbot gerará um certificado compartilhado para todos.

### Integração com Mailcow
Monte o volume como no exemplo de docker-compose, e o Mailcow usará `/certificates/cert.pem` e `key.pem` para SSL.

### Teste Dry-Run
Defina `DRY_RUN=true` e verifique logs para simulação.

## Contribuição

Contribuições são bem-vindas! Abra uma issue para reportar bugs ou sugira melhorias. Para pull requests:
1. Fork o repositório.
2. Crie uma branch: `git checkout -b feature/nova-funcionalidade`.
3. Commit suas mudanças: `git commit -m 'Adiciona nova funcionalidade'`.
4. Push: `git push origin feature/nova-funcionalidade`.
5. Abra um Pull Request.

## Licença

Este projeto é licenciado sob a MIT License - veja o arquivo [LICENSE](LICENSE) para detalhes.

Mantenedor: Henrique Fagundes <henrique@henrique.tec.br>

Para mais informações, visite o [GitHub Repository](https://github.com/AprendendoLinux/certbot-mailcow) ou o [Docker Hub Page](https://hub.docker.com/r/aprendendolinux/certbot-mailcow).
