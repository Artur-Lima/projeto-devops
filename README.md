# Projeto Integrador — Cloud Computing e DevOps

Aplicação web containerizada, publicada em cluster Docker Swarm, com domínio próprio, HTTPS válido, pipeline de CI/CD automatizada e monitoramento de disponibilidade.

**Integrantes:** Artur Lima da Silva e Thiago Emanuel

**N2:** o ambiente inteiro é reproduzível com Ansible em qualquer servidor Linux novo — ver [seção 14](#14-automação-com-ansible-n2).

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
| Automação de infraestrutura (N2) | Ansible (ansible-core, apenas módulos builtin) + ansible-lint |
| Provisionamento (N2, diferencial) | Terraform com provider `oracle/oci` |

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
├── ansible/                    # N2 — automação do servidor e do deploy (seção 14)
├── terraform/                  # N2 — provisionamento da VM na Oracle Cloud (seção 14.9)
├── evidencias/                 # N2 — evidências geradas pelo Ansible
├── .ansible-lint               # Regras de qualidade do código Ansible
└── .github/workflows/
    ├── ci-cd.yml               # Pipeline da aplicação (teste → build → deploy)
    ├── ansible.yml             # Pipeline do Ansible (lint + teste em VM limpa + execução manual)
    └── terraform.yml           # Pipeline do Terraform (fmt + validate)
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

Recuperação do serviço: `docker service update --force projeto-devops_app` recria as tasks. Recuperação da stack inteira: `docker stack deploy -c stack-swarm.yml projeto-devops`. Recuperação em servidor novo: um comando, `ansible-playbook site.yml` (seção 14), instala o Docker, inicializa o Swarm e sobe a stack completa — tudo a partir do que está versionado neste repositório. Com domínio configurado, o certificado é reemitido automaticamente após o DNS apontar para o novo IP.

---

## 14. Automação com Ansible (N2)

A N1 publicou a aplicação num cluster que já existia. A N2 prova que o ambiente é **reproduzível**: a partir de um servidor Linux novo e deste repositório, um único comando entrega a aplicação no ar.

```
Servidor Linux novo ──► Ansible ──► Python ──► pacotes + firewall ──► Docker Engine
                                   ──► Docker Swarm ──► stack (Traefik + app + Uptime Kuma)
                                   ──► validação HTTP ──► evidências em evidencias/
```

O fluxo funciona de dois jeitos, como o enunciado prevê:

- **Com Terraform (diferencial):** `terraform apply` cria rede, firewall e VM na Oracle Cloud e gera o inventário → Ansible → aplicação no ar (seção 14.9).
- **Sem Terraform:** servidor Linux já disponível → IP no `inventory.ini` → Ansible → aplicação no ar.

### 14.1 Estrutura

```
ansible/
├── ansible.cfg                 # inventário padrão, retries de SSH, saída legível
├── inventory.ini               # servidor(es) de destino — único arquivo a editar
├── site.yml                    # playbook principal
├── group_vars/all.yml          # variáveis: imagem, réplicas, domínio, portas...
└── roles/
    ├── bootstrap/              # 0. acha/instala Python >= 3.8 (só com raw)
    ├── base/                   # 1. pacotes, fuso horário, portas no firewall
    ├── docker/                 # 2. Docker Engine pelo repositório oficial
    ├── swarm/                  # 3. docker swarm init (só se ainda não estiver ativo)
    ├── deploy/                 # 4. gera stack.yml do template e faz docker stack deploy
    │   └── templates/stack.yml.j2
    └── validate/               # 5. testa /health e grava a evidência
        └── templates/evidencia.md.j2
```

Cada role tem uma responsabilidade e uma tag com o mesmo nome, então dá para rodar só uma etapa: `ansible-playbook site.yml --tags deploy`.

### 14.2 Requisitos

**Control node** (máquina que executa o Ansible): Linux, macOS ou **WSL no Windows** (o Ansible não roda nativamente no Windows), com Python 3 e `ansible-core`. Só módulos `ansible.builtin` são usados — nenhuma collection extra precisa ser instalada.

```bash
python3 -m pip install --user ansible-core      # ou: sudo apt install ansible-core
```

**Servidor de destino:** Linux novo com acesso SSH por usuário com sudo. Testado para:

| Família | Distribuições | Observação |
|---|---|---|
| Debian | Ubuntu 22.04/24.04, Debian 12 | apt + repositório oficial da Docker |
| RedHat | Oracle Linux 8/9, Rocky, Alma | dnf + repositório oficial da Docker; no OL8 o bootstrap instala python3.11 |

Arquitetura x86_64 ou ARM64 (ex.: Ampere da Oracle Cloud). Portas de entrada liberadas no provedor (security list / security group): 22, 80 e 3001 — e 443 se usar domínio.

### 14.3 Execução

```bash
git clone https://github.com/Artur-Lima/projeto-devops.git
cd projeto-devops/ansible

# 1. Informar o servidor no inventário (IP, usuário e chave SSH)
nano inventory.ini

# 2. Testar a conexão
ansible all -m ping

# 3. Executar a automação completa
ansible-playbook site.yml | tee ../evidencias/ansible-run.log
```

Ao final, o playbook mostra as URLs e grava `evidencias/deploy-<servidor>.md`.

**Acesso HTTP à aplicação** (modo padrão, sem domínio):

| Recurso | Endereço |
|---|---|
| Aplicação | `http://IP_DO_SERVIDOR/` |
| Health check | `http://IP_DO_SERVIDOR/health` |
| Uptime Kuma | `http://IP_DO_SERVIDOR:3001/` (primeiro acesso cria o usuário admin) |

**Modo HTTPS (opcional):** com um domínio apontando para o IP do servidor, o mesmo playbook emite o certificado Let's Encrypt e redireciona HTTP para HTTPS:

```bash
ansible-playbook site.yml -e app_domain=app.exemplo.com -e acme_email=voce@exemplo.com \
                          -e status_domain=status.exemplo.com
```

**Fixar uma versão específica da imagem** (rollback ou deploy de um commit):

```bash
ansible-playbook site.yml --tags deploy,validate -e app_image=ghcr.io/artur-lima/projeto-devops:<sha-do-commit>
```

### 14.4 Variáveis principais (`group_vars/all.yml`)

| Variável | Padrão | Função |
|---|---|---|
| `app_image` | `ghcr.io/artur-lima/projeto-devops:latest` | Imagem publicada pela pipeline da N1 |
| `app_replicas` | `2` | Réplicas da aplicação no Swarm |
| `traefik_image` | `traefik:v3.6` | Proxy; v3.6+ é exigido pelo Docker Engine 29 |
| `app_domain` / `status_domain` / `acme_email` | vazio | Preenchidos ativam o modo HTTPS |
| `kuma_enabled` / `kuma_port` | `true` / `3001` | Monitoramento |
| `firewall_ports` | 80, 443, 3001 | Portas abertas no firewalld/ufw, se ativos |

### 14.5 Decisões técnicas

- **Idempotência.** Cada tarefa confere o estado antes de agir: o Swarm só é inicializado se não estiver ativo; porta no firewall só é aberta se ainda estiver fechada; o deploy compara a especificação dos serviços (que inclui o digest da imagem) antes e depois, e só reporta `changed` quando algo mudou de fato. **Rodar o playbook duas vezes seguidas termina com `changed=0`** na segunda — essa é a prova de que ele descreve um estado, não uma sequência de comandos.
- **Stack autossuficiente.** No cluster da N1 o Traefik e a rede `traefik_public` já existiam. Num servidor novo não existe nada, então a stack gerada pelo Ansible traz o próprio Traefik e a própria rede overlay. A arquitetura é a mesma da N1: só o Traefik publica portas, a aplicação fica na rede interna com 2 réplicas e rolling update `start-first` com rollback automático.
- **Template em vez de arquivo fixo.** `stack.yml.j2` gera o modo HTTP por IP (para validação em servidor sem domínio) ou o modo HTTPS (produção) a partir das mesmas variáveis.
- **Firewall aberto, não desligado.** O exemplo de referência desliga o firewalld; aqui ele continua ativo e só as portas da stack são liberadas.
- **Python do servidor.** O `ansible-core` atual exige Python ≥ 3.8 no destino. A role `bootstrap` usa apenas `raw` (SSH puro) para localizar ou instalar um Python compatível antes de qualquer módulo — é o que permite usar o mesmo playbook em Ubuntu e em Oracle Linux 8.
- **Docker 29 x Traefik.** O Docker Engine 29 recusa clientes com API antiga, e versões do Traefik anteriores à 3.6.1 deixam de enxergar os serviços. Por isso a imagem do Traefik está fixada em `v3.6`.

### 14.6 Pipeline do Ansible

`.github/workflows/ansible.yml`:

- **Em todo push que altera `ansible/`:** checagem de sintaxe e `ansible-lint` no perfil `production`. Código de infraestrutura passa pelo mesmo controle de qualidade do código da aplicação.
- **Teste em VM limpa (a cada push):** o runner Ubuntu do GitHub tem o Docker removido e vira o "servidor novo"; o playbook roda contra ele duas vezes (a segunda precisa dar `changed=0`) e a aplicação é testada por HTTP. É a prova contínua de que a automação reproduz o ambiente do zero.
- **Execução manual** (Actions → Ansible → Run workflow, informando IP e usuário): roda o playbook a partir do GitHub contra o servidor, roda de novo para provar a idempotência e publica a pasta `evidencias/` como artefato. A chave SSH fica no secret `ANSIBLE_SSH_KEY`.

### 14.7 Evidências

| Evidência | Onde |
|---|---|
| Saída completa do Ansible (VM Ubuntu limpa) | `evidencias/ansible-run.log` |
| Segunda execução (idempotência, `changed=0`) | `evidencias/ansible-run-2.log` |
| Acesso HTTP (`/health` e página inicial) | `evidencias/http-check.log` |
| Estado do Docker, Swarm, stack e resposta do `/health` | `evidencias/deploy-<servidor>.md` (gerado pelo playbook) |
| Lint e execuções pelo GitHub | aba Actions → workflow **Ansible** |

### 14.8 Problemas comuns

| Sintoma | Causa provável | Ação |
|---|---|---|
| `UNREACHABLE` no ping | IP/usuário/chave errados ou porta 22 fechada | `ssh -i chave usuario@IP` manualmente |
| `Missing sudo password` | usuário exige senha no sudo | rodar com `-K` |
| Playbook ok, mas o navegador não abre | porta 80 fechada no provedor | liberar 80/3001 na security list / security group |
| Réplicas não ficam prontas | imagem inacessível ou app quebrando | `docker service ps projeto-devops_app --no-trunc` |
| 404 do Traefik | router não casou | `docker service logs projeto-devops_traefik` |

### 14.9 Provisionamento com Terraform (diferencial)

<p align="center">
  <img src="docs/img/terraforming.png" alt="Carta Terraforming" width="220"><br>
  <em>Ativa o Terraforming: adiciona 1 VM da Oracle Cloud ao seu campo. 🃏</em>
</p>

A pasta `terraform/` cria na **Oracle Cloud (OCI)** toda a infraestrutura de que a aplicação precisa e entrega a VM pronta para o Ansible:

```
terraform apply ──► VCN + internet gateway + rota ──► security list (22, 80, 443, 3001)
                ──► VM Oracle Linux 9 com a sua chave SSH
                ──► ansible/inventory.terraform.ini gerado com o IP da VM
ansible-playbook -i inventory.terraform.ini site.yml ──► Docker ──► Swarm ──► stack ──► HTTP
```

| Arquivo | Responsabilidade |
|---|---|
| `versions.tf` | Versão do Terraform e providers (`oracle/oci`, `hashicorp/local`) |
| `variables.tf` | Credenciais, região, shape, sistema e portas — com valores padrão Always Free |
| `network.tf` | VCN, internet gateway, tabela de rotas, security list e subnet pública |
| `compute.tf` | Imagem mais recente do sistema e a VM (shape Flex ou fixo) |
| `inventory.tf` | Ponte com o Ansible: grava `ansible/inventory.terraform.ini` com IP e usuário |
| `outputs.tf` | IP público, comando SSH, próximo passo e URL da aplicação |
| `terraform.tfvars.example` | Modelo das variáveis (o `terraform.tfvars` real não é versionado) |

**Execução:**

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars   # preencher com os dados da API key da OCI
terraform init
terraform plan
terraform apply

cd ../ansible
ansible-playbook -i inventory.terraform.ini site.yml
```

Para remover tudo que foi criado: `terraform destroy`.

**Decisões:**

- **Always Free por padrão:** `VM.Standard.A1.Flex` (ARM, 1 OCPU / 6 GB). Se a região estiver sem capacidade, `shape = "VM.Standard.E2.1.Micro"` também é gratuito. O Ansible já trata as duas arquiteturas.
- **Oracle Linux 9 por padrão**, como no material da disciplina; `sistema = "Canonical Ubuntu"` também funciona, e o usuário SSH do inventário (`opc` ou `ubuntu`) é escolhido automaticamente.
- **Firewall em duas camadas:** a security list da OCI (Terraform) e o firewalld/ufw do sistema (Ansible) liberam só as portas da stack. `origem_ssh` permite restringir o SSH ao IP de quem administra.
- **Segredos fora do Git:** `terraform.tfvars`, chaves `.pem`, arquivos de estado (`*.tfstate`) e o inventário gerado estão no `.gitignore`.
- **Qualidade contínua:** o workflow `Terraform` roda `terraform fmt -check` e `terraform validate` a cada alteração na pasta.
