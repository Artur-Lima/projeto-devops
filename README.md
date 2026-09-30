# Projeto Integrador — Cloud Computing e DevOps

Aplicação web containerizada, publicada em nuvem com domínio próprio, HTTPS válido, pipeline de CI/CD automatizada e monitoramento de disponibilidade.

- **Aplicação:** https://devops.seudominio.com.br
- **Status page:** https://status.seudominio.com.br/status/projeto
- **Pipeline:** aba **Actions** deste repositório

> Substitua os domínios acima pelos reais antes de enviar o repositório.

---

## 1. Descrição da aplicação

Aplicação web em Python/Flask que exibe na página inicial a disciplina e o nome completo de todos os integrantes do grupo. O rodapé mostra o hash do commit e a data do build que estão em produção naquele momento — é a forma de verificar, sem screenshot, que a pipeline realmente levou o código até o ar.

Rotas:

| Rota      | Função |
|-----------|--------|
| `/`       | Página inicial com disciplina e integrantes |
| `/health` | Retorna `{"status":"ok"}` — usado pelo healthcheck do Docker, pelo teste da pipeline e pelo Uptime Kuma |

## 2. Arquitetura do ambiente

```
                        ┌──────────────────── VPS (Ubuntu 24.04) ────────────────────┐
                        │                                                            │
Usuário                 │   UFW: 22, 80, 443                                         │
   │                    │        │                                                   │
   ▼                    │        ▼                                                   │
 DNS (registro A)  ────► │   ┌─────────┐   rede interna "web"    ┌──────────────┐     │
 devops.dominio.com.br  │   │ Traefik │ ─────────────────────► │ app :8000    │     │
        │               │   │ :80/:443│                        │ (Flask +      │     │
        ▼               │   │  TLS    │ ─────────────────────► │  gunicorn)    │     │
   IP da VPS            │   └─────────┘                        └──────────────┘     │
                        │        │                              ┌──────────────┐     │
                        │        └────────────────────────────► │ uptime-kuma  │     │
                        │                                       │ :3001        │     │
                        │                                       └──────────────┘     │
                        └────────────────────────────────────────────────────────────┘

Fluxo de entrega:
git push → GitHub Actions (teste → build → push GHCR) → SSH na VPS → docker compose pull && up -d
```

Somente o Traefik publica portas no host. A aplicação e o Uptime Kuma são alcançáveis apenas pela rede interna do Docker.

## 3. Tecnologias utilizadas

| Camada | Tecnologia |
|---|---|
| Aplicação | Python 3.12, Flask, Gunicorn |
| Containerização | Docker, Docker Compose (build multi-stage) |
| Reverse proxy / TLS | Traefik v3 + Let's Encrypt (ACME HTTP-01) |
| Cloud | VPS Linux |
| CI/CD | GitHub Actions + GitHub Container Registry (GHCR) |
| Monitoramento | Uptime Kuma |
| Segurança | UFW, SSH por chave, segredos em `.env` e GitHub Secrets |

## 4. Estrutura do projeto

```
.
├── app.py                      # Aplicação Flask
├── templates/index.html        # Página inicial
├── test_app.py                 # Testes executados pela pipeline
├── requirements.txt
├── Dockerfile                  # Build multi-stage, usuário não-root, healthcheck
├── docker-compose.yml          # app + traefik + uptime-kuma
├── .env.example                # Modelo de variáveis (o .env real não é versionado)
├── .gitignore
├── RUNBOOK.md                  # Diagnóstico e recuperação
└── .github/workflows/ci-cd.yml # Pipeline
```

## 5. Ambiente Cloud

| Item | Valor |
|---|---|
| Provedor | *(preencher)* |
| Sistema operacional | Ubuntu Server 24.04 LTS |
| Recursos | *(vCPU / RAM / disco)* |
| IP público | *(preencher)* |
| Portas abertas | 22 (SSH), 80 (HTTP → redirect), 443 (HTTPS) |
| Forma de acesso | SSH com chave pública: `ssh -i ~/.ssh/chave usuario@IP` |

**Por que VPS:** controle total do sistema operacional, Docker nativo sem camada de abstração de serviço gerenciado, custo previsível e permanência garantida até a N2.

## 6. Processo de instalação

```bash
# Na VPS, como usuário comum com sudo
sudo apt update && sudo apt install -y docker.io docker-compose-v2 git ufw
sudo usermod -aG docker $USER && newgrp docker

# Firewall
sudo ufw allow 22/tcp && sudo ufw allow 80/tcp && sudo ufw allow 443/tcp
sudo ufw enable

# Projeto
git clone https://github.com/SEU-USUARIO/projeto-devops.git ~/projeto-devops
cd ~/projeto-devops
cp .env.example .env && nano .env      # preencher domínios, imagem e e-mail
docker compose up -d
```

## 7. Processo de deploy

Deploy automático a cada push na branch `main`:

1. `test` — instala dependências e roda o pytest. Se falhar, nada segue adiante.
2. `build` — constrói a imagem e publica no GHCR com duas tags: `latest` e o SHA do commit.
3. `deploy` — conecta na VPS por SSH, faz `git pull`, `docker compose pull` e `docker compose up -d`.

Verificação: o rodapé da página passa a exibir o novo hash de commit.

Deploy manual, se necessário:

```bash
cd ~/projeto-devops && git pull && docker compose pull && docker compose up -d
```

## 8. Configuração do Docker

`Dockerfile` em dois estágios: o primeiro instala as dependências, o segundo copia apenas o resultado e o código, o que reduz o tamanho da imagem. O container roda com usuário `appuser` (UID 10001), sem privilégios de root, e possui `HEALTHCHECK` batendo em `/health` a cada 30s.

O `docker-compose.yml` orquestra três serviços na rede `web`, todos com `restart: unless-stopped`. Apenas o Traefik mapeia portas para o host. O socket do Docker é montado somente leitura.

Diferença fundamental: **Dockerfile** é a receita, **imagem** é o pacote imutável gerado a partir dela, **container** é a instância em execução da imagem. Remover o container não apaga a imagem; dados que precisam sobreviver ficam em volumes (`traefik_certs`, `kuma_data`).

## 9. Configuração do DNS

Registros no painel do domínio:

| Tipo | Nome | Valor | Proxy |
|---|---|---|---|
| A | `devops` | IP da VPS | desligado (DNS only) |
| A | `status` | IP da VPS | desligado (DNS only) |

Caminho: o navegador consulta o resolver → chega ao servidor autoritativo do domínio → recebe o IP da VPS → abre conexão TCP na porta 443 → o Traefik lê o cabeçalho `Host` e encaminha ao container correspondente.

Verificação: `dig +short devops.seudominio.com.br` deve retornar o IP da VPS.

## 10. Configuração do HTTPS

Certificado emitido pelo Let's Encrypt através do resolver ACME do Traefik, usando desafio HTTP-01 na porta 80. A renovação é automática e os certificados ficam no volume `traefik_certs`. Todo acesso HTTP é redirecionado para HTTPS pelo entrypoint `web`.

Verificação: `curl -vI https://devops.seudominio.com.br` — o certificado deve ser emitido por Let's Encrypt e estar dentro da validade.

## 11. Monitoramento

Uptime Kuma em `status.seudominio.com.br`, com dois monitores HTTP(s) apontando para `/health` da aplicação e para a própria página inicial, checagem a cada 60 segundos e uma status page pública para validação externa.

Camadas de verificação:

| Pergunta | Onde olhar |
|---|---|
| A aplicação está online? | Status page do Uptime Kuma |
| O servidor está de pé? | `ssh` na VPS, `uptime`, `df -h` |
| O container está rodando? | `docker compose ps` (coluna STATUS mostra `healthy`) |
| Como identificar indisponibilidade? | Alerta do Kuma + `docker logs` + roteiro do `RUNBOOK.md` |

## 12. Segurança

- SSH apenas por chave; login de root e autenticação por senha desabilitados.
- UFW liberando somente 22, 80 e 443.
- Aplicação e Uptime Kuma sem portas publicadas no host.
- Container roda como usuário não-root.
- Nenhuma credencial no código: `.env` está no `.gitignore` (apenas `.env.example` é versionado) e os segredos da pipeline ficam em GitHub Secrets.
- Painel do Traefik desabilitado.
- HTTPS obrigatório, com redirecionamento automático de HTTP.
- Socket do Docker montado somente leitura.

Segredos usados na pipeline: `VPS_HOST`, `VPS_USER`, `VPS_SSH_KEY`, `VPS_PORT`.

## 13. Procedimentos básicos de recuperação

Roteiro completo de diagnóstico e recuperação em [`RUNBOOK.md`](./RUNBOOK.md).

Recuperação total do ambiente (servidor novo): instalar Docker → `git clone` → criar `.env` → `docker compose up -d`. Nada além do `.env` e dos volumes precisa ser reconstruído manualmente.
