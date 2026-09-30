# RUNBOOK — Diagnóstico e Recuperação

Roteiro de investigação **de fora para dentro**: DNS → rede → proxy → container → aplicação → recursos.

## Triagem rápida

```bash
dig +short devops.seudominio.com.br        # 1. DNS resolve para o IP certo?
curl -I https://devops.seudominio.com.br   # 2. Responde? Qual código HTTP?
docker compose ps                          # 3. Containers up e healthy?
docker compose logs --tail=50 app          # 4. O que a aplicação diz?
docker compose logs --tail=50 traefik      # 5. Roteamento e certificado
df -h && free -h                           # 6. Disco e memória
```

## Cenários

### Site fora do ar, DNS respondendo

```bash
docker compose ps                    # container parado ou "unhealthy"?
docker compose logs --tail=100 app
docker compose up -d app             # sobe novamente
```

### Container reiniciando em loop

```bash
docker compose logs --tail=100 app   # o erro aparece repetido no fim do log
docker inspect app --format '{{.State.ExitCode}} {{.State.Health.Status}}'
```

Causas comuns: erro de sintaxe no código, variável de ambiente ausente no `.env`, porta errada no gunicorn.

### DNS não resolve ou aponta para o IP errado

```bash
dig +short devops.seudominio.com.br
dig +short devops.seudominio.com.br @8.8.8.8   # compara com resolver externo
```

Corrigir o registro A no painel do domínio e aguardar o TTL. Se estiver usando Cloudflare, o proxy deve estar **desligado** (DNS only).

### HTTPS quebrado ou certificado inválido

```bash
docker compose logs traefik | grep -i acme
curl -vI https://devops.seudominio.com.br 2>&1 | grep -i 'expire\|issuer'
sudo ufw status                       # a porta 80 precisa estar aberta para o ACME
```

O Let's Encrypt valida pelo desafio HTTP-01: se a porta 80 estiver fechada, a emissão falha. Cuidado com o limite de tentativas — não fique repetindo `up -d` em loop.

### Porta bloqueada

```bash
sudo ufw status numbered
sudo ufw allow 443/tcp
ss -tulpn | grep -E ':80|:443'
```

### 404 ou 502 vindo do Traefik

502 significa que o Traefik encontrou a rota mas não conseguiu falar com o container; 404 significa que nenhuma regra bateu com o `Host`.

```bash
docker compose logs traefik --tail=50
docker inspect app --format '{{json .Config.Labels}}' | tr ',' '\n' | grep traefik
docker network inspect projeto-devops_web | grep -A3 Name
```

Confira se `APP_DOMAIN` no `.env` é exatamente o domínio acessado e se app e traefik estão na mesma rede.

### Disco cheio

```bash
df -h
docker system df
docker system prune -af --volumes    # atenção: remove volumes não usados
journalctl --vacuum-time=3d
```

### Deploy falhou na pipeline

Abrir a aba **Actions** e ver qual job falhou:

- `test` vermelho → o código quebrou; o deploy nem chegou a rodar (comportamento correto).
- `build` vermelho → erro no Dockerfile ou permissão de `packages: write`.
- `deploy` vermelho → SSH: conferir os secrets `VPS_HOST`, `VPS_USER`, `VPS_PORT`, `VPS_SSH_KEY`.

Deploy manual enquanto investiga:

```bash
cd ~/projeto-devops && git pull && docker compose pull && docker compose up -d
```

### Voltar para a versão anterior (rollback)

```bash
# Toda imagem é publicada também com a tag do SHA do commit
docker compose pull
APP_IMAGE=ghcr.io/seu-usuario/projeto-devops:<sha-anterior> docker compose up -d app
```

## Recuperação total do ambiente

Se a VPS for perdida:

```bash
sudo apt update && sudo apt install -y docker.io docker-compose-v2 git ufw
sudo ufw allow 22/tcp && sudo ufw allow 80/tcp && sudo ufw allow 443/tcp && sudo ufw enable
git clone https://github.com/SEU-USUARIO/projeto-devops.git ~/projeto-devops
cd ~/projeto-devops && cp .env.example .env && nano .env
docker compose up -d
```

Depois: apontar o registro A para o novo IP e reconfigurar os monitores do Uptime Kuma (o histórico se perde se o volume `kuma_data` não tiver backup). O certificado é reemitido sozinho.

## Perguntas de defesa

**Ponto único de falha:** a VPS. Ela hospeda proxy, aplicação e monitoramento; se cair, tudo cai junto — inclusive o monitoramento, que por estar na mesma máquina não conseguiria reportar a queda.

**Como tornar mais resiliente:** monitoramento externo (fora da VPS), múltiplas réplicas da aplicação atrás do proxy, backup automatizado dos volumes, snapshot periódico da VPS e, em outro nível, orquestração multi-nó com balanceador na frente.

**O que acontece ao remover o container:** a imagem permanece e os volumes nomeados permanecem; perde-se apenas o estado gravado na camada de escrita do container. `docker compose up -d` recria tudo a partir da imagem.
