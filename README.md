# Projeto Integrador — Cloud Computing e DevOps

Aplicação web containerizada, publicada em cluster Docker Swarm, com domínio próprio, HTTPS válido, pipeline de CI/CD automatizada e monitoramento de disponibilidade.

| Recurso | Endereço |
|---|---|
| Aplicação | https://arturdevops.duckdns.org |
| Health check | https://arturdevops.duckdns.org/health |
| Status page | https://arturdevopsstatus.duckdns.org/status/projeto |
| Repositório | https://github.com/Artur-Lima/projeto-devops |
| Pipeline | https://github.com/Artur-Lima/projeto-devops/actions |
| Imagem | ghcr.io/artur-lima/projeto-devops |

---

## 1. Descrição da aplicação

Aplicação web em Python/Flask que exibe na página inicial a disciplina e o nome completo dos integrantes do grupo. O rodapé mostra o hash do commit e a data do build que estão em produção naquele instante — é assim que se verifica, sem screenshot, qual versão do repositório está no ar.

| Rota | Função |
|---|---|
| `/` | Página inicial com disciplina e integrantes |
| `/health` | Retorna `{"status":"ok","commit":"...","build":"..."}` |

O `/health` tem três usos simultâneos: healthcheck do Docker, validação automática da pipeline após o deploy e monitor do Uptime Kuma.

## 2. Arquitetura do ambiente

```
                    ┌──────────── VPS Hostinger — 31.97.172.33 ────────────┐
                    │              Docker Swarm (2 nós)                    │
Usuário             │                                                      │
   │                │   portas publicadas no host: 80, 443 (só o Traefik)  │
   ▼                │        │                                             │
 DNS (DuckDNS)      │        ▼                                             │
 arturdevops ──────►│   ┌─────────┐   rede overlay      ┌────────────────┐ │
 .duckdns.org       │   │ Traefik │   traefik_public    │ app (2 réplicas)│ │
        │           │   │ :80/:443├────────────────────►│ gunicorn :8000 │ │
        ▼           │   │  TLS    │                     └────────────────┘ │
 31.97.172.33       │   │         │                     ┌────────────────┐ │
                    │   └─────────┴────────────────────►│ uptime-kuma    │ │
                    │                                   │ :3001          │ │
                    │                                   └────────────────┘ │
                    └──────────────────────────────────────────────────────┘

Fluxo de entrega:
git push → GitHub Actions (teste → build → push GHCR) → webhook Portainer
         → Swarm puxa a imagem → rolling update → validação automática no /health
```

Componentes:

- **DNS** traduz o nome para o IP da VPS.
- **Traefik** é o reverse proxy: é o único serviço que publica portas no host, termina o TLS e roteia pelo cabeçalho `Host` até o container certo.
- **Rede overlay `traefik_public`** liga o Traefik aos serviços; a aplicação não é alcançável de fora por outro caminho.
- **Swarm** mantém o número de réplicas desejado e reinicia o que cair.
- **Portainer** é a interface de administração do cluster e expõe o webhook usado pelo deploy.

## 3. Tecnologias utilizadas

| Camada | Tecnologia |
|---|---|
| Aplicação | Python 3.12, Flask, Gunicorn |
| Containerização | Docker, build multi-stage, usuário não-root |
| Orquestração | Docker Swarm (2 nós), administrado via Portainer CE 2.33 |
| Reverse proxy / TLS | Traefik v3 + Let's Encrypt (resolver `letsencrypt`) |
| Cloud | VPS Hostinger (AS47583) |
| DNS | DuckDNS |
| Registro de imagens | GitHub Container Registry (GHCR) |
| CI/CD | GitHub Actions + webhook de serviço do Portainer |
| Monitoramento | Uptime Kuma com status page pública |

## 4. Estrutura do projeto

```
.
├── app.py                      # Aplicação Flask
├── templates/index.html        # Página inicial
├── test_app.py                 # Testes executados pela pipeline
├── requirements.txt
├── Dockerfile                  # Build multi-stage, não-root, healthcheck
├── stack-swarm.yml             # Stack de produção (Docker Swarm)
├── docker-compose.yml          # Ambiente alternativo de host único
├── .env.example                # Modelo de variáveis (.env real não versionado)
├── .gitignore
├── RUNBOOK.md                  # Diagnóstico e recuperação
└── .github/workflows/ci-cd.yml # Pipeline
```

## 5. Ambiente Cloud

| Item | Valor |
|---|---|
| Provedor | Hostinger (VPS) |
| Sistema operacional | Linux (Ubuntu Server) |
| Orquestração | Docker Swarm, 2 nós; serviços fixados no nó `srv1230142` |
| IP público | 31.97.172.33 |
| Portas publicadas | 80 (HTTP, redireciona) e 443 (HTTPS) — ambas apenas pelo Traefik |
| Portas da aplicação | 8000 (app) e 3001 (Uptime Kuma), acessíveis somente pela rede overlay interna |
| Forma de acesso | Portainer em https://portainer.cyberselva.com, autenticado |

**Por que VPS com Swarm:** infraestrutura já existente e sob controle próprio, com orquestração que garante réplicas e reinício automático, custo previsível e disponibilidade garantida até a N2 — sem depender de crédito promocional de free tier.

## 6. Processo de instalação

A stack é criada no Portainer a partir do `stack-swarm.yml`:

1. Portainer → **Stacks** → **Add stack**
2. Name: `projeto-devops`, Build method: **Web editor**
3. Colar o conteúdo de `stack-swarm.yml`
4. **Deploy the stack**

Equivalente por linha de comando, em um nó manager:

```bash
docker stack deploy -c stack-swarm.yml projeto-devops
docker service ls | grep projeto-devops
```

Pré-requisitos já presentes no cluster: Docker Swarm inicializado, rede overlay externa `traefik_public` e Traefik com o resolver `letsencrypt` configurado.

## 7. Processo de deploy

Automático a cada push na branch `main`:

1. **test** — instala dependências e roda o pytest. Falhou, nada segue adiante.
2. **build** — constrói a imagem e publica no GHCR com duas tags: `latest` e o SHA do commit. O SHA e a data entram na imagem como build args e aparecem no rodapé da página.
3. **deploy** — dispara o webhook do Portainer, que faz o Swarm puxar a imagem nova e aplicar rolling update com `start-first`. Em seguida a própria pipeline consulta o `/health` em loop até o commit em produção bater com o commit do push; se não bater em 5 minutos, o job falha.

Esse último passo é o que torna o deploy verificável: a pipeline só fica verde se a alteração realmente chegou ao ar.

Deploy manual, se necessário:

```bash
docker service update --image ghcr.io/artur-lima/projeto-devops:latest \
  --with-registry-auth --update-order start-first projeto-devops_app
```

## 8. Configuração do Docker

`Dockerfile` em dois estágios: o primeiro instala as dependências, o segundo copia apenas o resultado e o código-fonte, o que reduz o tamanho da imagem e a superfície de ataque. O processo roda como `appuser` (UID 10001), sem privilégios de root, e há `HEALTHCHECK` consultando `/health` a cada 30s.

Na stack, a aplicação sobe com **2 réplicas** e `update_config: order: start-first` — a réplica nova entra em serviço antes da antiga sair, então o deploy não derruba o site.

Conceitos:

- **Dockerfile** é a receita.
- **Imagem** é o pacote imutável gerado a partir dela, versionado no GHCR por SHA de commit.
- **Container** é a instância em execução; no Swarm cada container é uma *task* de um *service*.
- Remover um container não apaga a imagem nem os volumes nomeados; o Swarm recria a task automaticamente para manter as réplicas.

## 9. Configuração do DNS

Dois subdomínios no DuckDNS apontando para o IP da VPS:

| Domínio | Tipo | Valor |
|---|---|---|
| `arturdevops.duckdns.org` | A | 31.97.172.33 |
| `arturdevopsstatus.duckdns.org` | A | 31.97.172.33 |

Caminho percorrido: o navegador consulta o resolver → o resolver chega aos servidores autoritativos do DuckDNS → recebe 31.97.172.33 → abre conexão TCP na porta 443 da VPS → o Traefik lê o cabeçalho `Host` e encaminha para o serviço cujo router casa com aquele nome.

Verificação: `nslookup arturdevops.duckdns.org` retorna 31.97.172.33.

## 10. Configuração do HTTPS

Certificado emitido pelo Let's Encrypt através do resolver ACME do Traefik (`certresolver=letsencrypt`), por desafio HTTP-01 na porta 80. A renovação é automática. Todo acesso em HTTP é redirecionado para HTTPS por um middleware próprio da stack (`devops-redirect`), para não interferir nos middlewares das outras aplicações do cluster.

Verificação: `curl -I https://arturdevops.duckdns.org` retorna `200 OK` com certificado válido.

## 11. Monitoramento

Uptime Kuma publicado em `arturdevopsstatus.duckdns.org`, com dois monitores HTTP(s) a cada 60 segundos — a página inicial e o `/health` — e uma status page pública em `/status/projeto` para validação externa sem precisar de login.

| Pergunta | Onde olhar |
|---|---|
| A aplicação está online? | Status page do Uptime Kuma |
| O servidor está de pé? | Portainer → Dashboard (nós do cluster) |
| O container está rodando? | Portainer → Services → `projeto-devops_app` (réplicas 2/2) |
| Como identificar indisponibilidade? | Alerta do Kuma + logs do serviço + roteiro do `RUNBOOK.md` |

## 12. Segurança

- Nenhuma porta da aplicação publicada no host: só o Traefik expõe 80 e 443.
- Container roda como usuário não-root.
- Nenhuma credencial no código: `.env` no `.gitignore`, apenas `.env.example` versionado.
- Segredos da pipeline em GitHub Secrets (`PORTAINER_WEBHOOK`), nunca no YAML.
- A URL do webhook é tratada como credencial — quem a possui consegue disparar deploy.
- HTTPS obrigatório, com redirecionamento automático de HTTP.
- Acesso administrativo ao cluster apenas via Portainer autenticado.
- Imagem pública no GHCR contém somente o código da aplicação, sem segredos embutidos.

## 13. Procedimentos básicos de recuperação

Roteiro completo em [`RUNBOOK.md`](./RUNBOOK.md).

Recuperação do serviço: `docker service update --force projeto-devops_app` recria as tasks. Recuperação da stack inteira: `docker stack deploy -c stack-swarm.yml projeto-devops`. Recuperação em servidor novo: instalar Docker, inicializar o Swarm, criar a rede `traefik_public`, subir o Traefik e aplicar a stack — tudo a partir do que está versionado neste repositório. O certificado é reemitido automaticamente após o DNS apontar para o novo IP.
