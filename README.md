# Certbot com Cloudflare para Certificados Let's Encrypt

![Certbot Logo](https://img.shields.io/badge/Certbot-v2.11.0-brightgreen) ![Docker](https://img.shields.io/badge/Docker-Supported-blue) ![Cloudflare](https://img.shields.io/badge/Cloudflare-DNS%20Plugin-orange)

## Descrição

Este repositório contém uma solução Dockerizada para gerenciar certificados SSL/TLS gratuitos do Let's Encrypt usando o Certbot, com autenticação via DNS através do plugin para Cloudflare. A imagem é baseada no Alpine Linux para ser leve e eficiente, projetada para renovar ou expandir certificados automaticamente para múltiplos domínios wildcard (ex.: `*.exemplo.com.br`).

O grande diferencial desta solução é a **integração nativa com outros serviços (como Mailcow)**. O contêiner executa o Certbot via cron a cada 6 horas. Quando uma renovação de certificado é de fato concluída, o sistema detecta a mudança através da validação de hash (MD5) e **dispara automaticamente o recarregamento dos seus serviços no host** usando o Docker Compose, garantindo que o novo certificado entre em vigor sem nenhuma intervenção manual.

Esta solução é ideal para administradores de sistemas que gerenciam múltiplos domínios hospedados no Cloudflare, precisando de certificados wildcard para subdomínios dinâmicos e de uma infraestrutura que se auto-mantenha.

### Principais Recursos
- **Autenticação DNS via Cloudflare**: Validação de domínios sem necessidade de servidor web exposto (não usa portas 80/443).
- **Restart Automático de Serviços**: Detecta quando o certificado é renovado de verdade e roda `docker compose up -d --force-recreate` no projeto alvo.
- **Suporte a Múltiplos Domínios**: Pode lidar com vários domínios wildcard listados em uma variável de ambiente.
- **Renovação Automática Inteligente**: Cron job configurado para executar a cada 6 horas, mas que só interfere e reinicia os serviços se faltarem menos de 30 dias para o vencimento.
- **Cópia de Certificados Padronizada**: Os arquivos gerados são copiados para a pasta desejada com nomes amigáveis (`cert.pem` e `key.pem`).
- **Modo Dry-Run**: Para simular execuções sem alterar certificados reais e sem gastar o limite da API do Let's Encrypt.
- **Logs Detalhados**: Todos os passos são logados em `/var/log/certificados.log` (e na saída padrão do Docker) para fácil depuração.

Esta imagem está disponível no Docker Hub como `aprendendolinux/certbot-mailcow:latest`. Para uso no GitHub, clone o repositório e construa a imagem localmente.

## Pré-requisitos

Antes de usar esta solução, certifique-se de ter:
- **Docker** (versão 20.10 ou superior recomendada).
- **Docker Compose** (versão 1.29 ou superior ou o novo plugin `docker-compose`).
- **Conta Cloudflare**: Com acesso à API Global (ou Scoped) para DNS. Você precisará de um e-mail e chave API.
- **Domínios Configurados no Cloudflare**: Os domínios listados em `MY_DOMAINS` devem ter os nameservers apontados para o Cloudflare.

**Atenção**: O contêiner precisará de acesso ao socket do Docker do host (`/var/run/docker.sock`) para poder enviar comandos de restart para outros serviços.

## Instalação

### Via Docker Hub
Puxe a imagem pré-construída:
```bash
docker pull aprendendolinux/certbot-mailcow:latest

```

### Construindo Localmente (para GitHub)

Clone o repositório:

```
git clone https://github.com/AprendendoLinux/certbot-mailcow.git
cd certbot-mailcow
docker build -t aprendendolinux/certbot-mailcow:latest .
```

### Configuração via Docker Compose

Use o arquivo `docker-compose.yml` fornecido como base. **Aviso importante**: Evite usar aspas (`"`) nos caminhos de diretório nas variáveis de ambiente.

Exemplo de `docker-compose.yml` otimizado para o Mailcow:

```yaml
services:
  certbot:
    image: aprendendolinux/certbot-mailcow:latest
    restart: always
    container_name: certbot
    hostname: certbot
    volumes:
      # Mapeia a raiz do projeto alvo (Mailcow) para que o Compose consiga ler todo o contexto do projeto ao reiniciar
      - /srv/mailcow-dockerized:/srv/mailcow-dockerized
      
      # Mapeamento do socket do Docker (Necessário para a automação de restart)
      - /var/run/docker.sock:/var/run/docker.sock
      
      # Armazenamento persistente e logs do Let's Encrypt
      - /srv/certbot/letsencrypt/data:/etc/letsencrypt
      - /srv/certbot/logs:/var/log/letsencrypt
    environment:
      - TZ=America/Sao_Paulo
      - CLOUDFLARE_EMAIL=seu@email.com.br
      - CLOUDFLARE_API_KEY=sua-api-da-cloudflare-aqui
      - MY_DOMAINS=*.dominio1.com.br,*.dominio2.com.br
      - DRY_RUN=false
      
      # (Opcional) Define onde os arquivos cert.pem e key.pem serão injetados
      - CERT_OUTPUT_DIR=/srv/mailcow-dockerized/data/assets/ssl
      
      # (Opcional) Define qual projeto Docker Compose deverá ser recriado ao renovar os certificados
      - TARGET_COMPOSE_FILE=/srv/mailcow-dockerized/docker-compose.yml

```

Inicie o serviço:

```bash
docker compose up -d

```

## Uso e Variáveis de Ambiente

As seguintes variáveis devem ser definidas no bloco `environment`:

### Obrigatórias

* `CLOUDFLARE_EMAIL`: E-mail associado à sua conta Cloudflare.
* `CLOUDFLARE_API_KEY`: Chave API do Cloudflare (Global API Key ou token restrito à edição de DNS).
* `MY_DOMAINS`: Lista de domínios separados por vírgula (ex.: `*.site1.com,*.site2.com`). Suporta wildcards para cobrir subdomínios ilimitados.
* `DRY_RUN`: Defina como `true` para simular uma execução (testes) ou `false` para emissão real.

### Opcionais / Automação

* `TZ`: Timezone do container (padrão: `America/Sao_Paulo`).
* `CERT_OUTPUT_DIR`: O caminho interno (mapeado pelo volume) onde os certificados finais serão entregues. (Padrão: `/certificates`).
* `TARGET_COMPOSE_FILE`: O caminho absoluto (mapeado pelo volume) do arquivo `docker-compose.yml` que o script deverá executar caso os certificados sejam renovados.

## Como o recarregamento automático funciona?

Para evitar reiniciar seu servidor 4 vezes ao dia desnecessariamente, desenvolvemos uma lógica inteligente:

1. O cron acorda a cada 6 horas.
2. O Certbot avalia se faltam menos de 30 dias para o certificado vencer. Se faltar mais, ele encerra sem fazer nada.
3. Se estiver na janela de renovação, o Certbot altera os registros DNS, emite os novos certificados e salva em `/etc/letsencrypt`.
4. Nosso script calcula o Hash MD5 do certificado novo e compara com o certificado em uso pelo seu servidor.
5. Se for detectada a alteração estrutural do arquivo, os certificados são copiados e o script executa nativamente `docker compose -f $TARGET_COMPOSE_FILE up -d --force-recreate`.

## Depuração e Solução de Problemas

* **Acompanhar logs:** Todo o fluxo pode ser visto facilmente rodando: `docker logs -f certbot`.
* **Como forçar um teste de restart:** Se quiser testar o acionamento do gatilho do Docker Compose sem esgotar sua cota no Let's Encrypt, basta renomear o certificado atual de destino (ex: `mv cert.pem cert.pem.bkp`) e rodar manualmente a verificação: `docker exec -it certbot /usr/local/bin/docker-certbot`. O sistema assumirá que é um certificado inédito e disparará o restart.
* **Falha de TARGET_COMPOSE_FILE não encontrada:** Se o log apontar que o arquivo Compose está inacessível, verifique se você não inseriu aspas (`"`) na declaração da variável no arquivo compose e certifique-se de que a pasta raiz do projeto foi corretamente montada nos `volumes`.
* **Erro de Autenticação Cloudflare:** Verifique se a sua Chave API realmente tem permissão de leitura/edição de zonas DNS na sua conta e se os domínios declarados estão hospedados lá.

## Contribuição

Contribuições são sempre bem-vindas!

1. Faça um Fork do repositório.
2. Crie sua branch de funcionalidade (`git checkout -b feature/nova-funcionalidade`).
3. Faça o commit de suas alterações (`git commit -m 'Adiciona funcionalidade X'`).
4. Faça o push para a branch (`git push origin feature/nova-funcionalidade`).
5. Abra um Pull Request.

## Licença

Este projeto é licenciado sob a MIT License

Mantenedor: [Henrique Fagundes](https://henrique.tec.br)
