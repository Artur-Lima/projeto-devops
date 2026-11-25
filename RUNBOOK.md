# RUNBOOK — Diagnóstico e Recuperação

Ambiente: Docker Swarm, stack `projeto-devops` com os serviços `projeto-devops_traefik`, `projeto-devops_app` (2 réplicas) e `projeto-devops_uptime-kuma`. Comandos executados no nó manager.

Roteiro de investigação **de fora para dentro**: DNS → rede/porta → proxy → serviço → container → aplicação → recursos.

> **Regra de ouro da N2:** o Ansible descreve o estado correto do servidor. Para quase tudo que for quebrado na infraestrutura (Docker parado, Swarm desfeito, stack removida, serviço com 0 réplicas, imagem trocada, porta fechada no firewall), rodar `ansible-playbook site.yml` de novo restaura o estado desejado. Antes de corrigir, porém, **diagnostique e explique a causa** — é isso que a defesa avalia.

## Triagem rápida

```bash
curl -i http://IP_OU_DOMINIO/health              # 1. Responde? Qual código HTTP?
systemctl is-active docker                        # 2. Docker de pé?
docker info --format '{{.Swarm.LocalNodeState}}'  # 3. Swarm ativo? (esperado: active)
docker stack services projeto-devops              # 4. Réplicas X/Y batem?
docker service ps projeto-devops_app --no-trunc   # 5. Por que uma task falhou? (coluna ERROR)
docker service logs --tail 50 projeto-devops_app  # 6. O que a aplicação diz?
docker service logs --tail 50 projeto-devops_traefik
ss -tulpn | grep -E ':80 |:443 |:3001 '           # 7. Quem está escutando nas portas?
df -h && free -h                                  # 8. Disco e memória
```

## Lendo o código HTTP

| Resposta | Significado | Onde olhar |
|---|---|---|
| Conexão recusada / timeout | nada escutando na porta ou firewall bloqueando | Traefik rodando? firewall? security list do provedor? |
| `404 page not found` (texto puro) | o Traefik respondeu, mas nenhum router casou | labels do serviço, `Host` acessado, serviço `app` existe? |
| `502 Bad Gateway` | router casou, mas não há container saudável atrás | réplicas da app, porta 8000 no label |
| `503`/`504` | backend lento ou sem réplica pronta | `docker service ps`, recursos do servidor |
| `200` | ok — conferir o `commit` do `/health` com o último commit do repositório |

## Cenários

### Serviço com réplicas 0/2 ou escalado para zero

```bash
docker stack services projeto-devops
docker service ps projeto-devops_app --no-trunc   # ERROR mostra o motivo
docker service scale projeto-devops_app=2         # se alguém escalou para 0
```

### Container reiniciando em loop

```bash
docker service ps projeto-devops_app --no-trunc
docker service logs --tail 100 projeto-devops_app
```

Causas comuns: imagem/tag inexistente (`No such image`), erro no código, porta errada no gunicorn. Se a imagem nova está quebrada, o `update_config` com `failure_action: rollback` volta sozinho; manual:

```bash
docker service rollback projeto-devops_app
```

### Container removido na mão (`docker rm -f`)

Nada a fazer: o Swarm percebe que a réplica sumiu e cria outra em segundos (`docker service ps` mostra a task antiga como `Shutdown`/`Failed` e a nova como `Running`). É a diferença entre container avulso e serviço.

### Stack removida (`docker stack rm`)

```bash
docker stack deploy -c /opt/projeto-devops/stack.yml projeto-devops
# ou, a partir do control node:
ansible-playbook site.yml --tags deploy,validate
```

O volume `kuma_data` não é apagado pelo `stack rm`, então o Uptime Kuma volta com a configuração.

### Docker parado

```bash
systemctl status docker
sudo systemctl start docker     # os serviços do Swarm sobem sozinhos em seguida
```

### Swarm desfeito (`docker swarm leave --force`)

Os serviços somem junto. Recriar tudo com o Ansible (inicializa o Swarm e refaz o deploy):

```bash
ansible-playbook site.yml --tags swarm,deploy,validate
```

### Porta bloqueada

```bash
sudo firewall-cmd --list-ports      # Oracle Linux / RHEL
sudo ufw status                     # Ubuntu
ss -tulpn | grep -E ':80 |:3001 '   # se aparece aqui mas não abre de fora → firewall do provedor
```

Firewall do servidor: `ansible-playbook site.yml --tags base`. Firewall do provedor (security list / security group): liberar no painel.

### 404 do Traefik

```bash
docker service logs projeto-devops_traefik | grep -iE 'error|router'
docker service inspect projeto-devops_app --format '{{json .Spec.Labels}}' | tr ',' '\n' | grep traefik
```

No modo HTTPS, confira se o domínio acessado é exatamente o de `app_domain`. Se o log mostrar `client version 1.24 is too old`, a imagem do Traefik é anterior à 3.6.1 e não fala com o Docker 29.

### HTTPS quebrado ou certificado inválido (modo com domínio)

```bash
docker service logs projeto-devops_traefik | grep -i acme
dig +short app.exemplo.com           # aponta para o IP do servidor?
```

O Let's Encrypt valida pelo desafio HTTP-01 na porta 80: porta fechada ou DNS errado = emissão falha. Não reiniciar em loop (limite de tentativas).

### Disco cheio

```bash
df -h
docker system df
docker image prune -af               # imagens antigas de deploys anteriores
journalctl --vacuum-time=3d
```

### Deploy falhou na pipeline

Aba **Actions**:

- `Testes` vermelho → o código quebrou; o deploy nem chegou a rodar (comportamento correto).
- `Build da imagem` vermelho → erro no Dockerfile ou permissão `packages: write`.
- `Deploy no Swarm` vermelho → webhook do Portainer (secret `PORTAINER_WEBHOOK`) ou o `/health` não mostrou o commit novo a tempo.
- Workflow **Ansible** vermelho → lint/sintaxe; rodar `ansible-lint ansible/` localmente.

## Voltar para a versão anterior (rollback)

Toda imagem é publicada também com a tag do SHA do commit:

```bash
docker service update --image ghcr.io/artur-lima/projeto-devops:<sha-anterior> projeto-devops_app
# ou, versionado pelo Ansible:
ansible-playbook site.yml --tags deploy,validate -e app_image=ghcr.io/artur-lima/projeto-devops:<sha-anterior>
```

## Recuperação total do ambiente

Se o servidor for perdido: criar um Linux novo, colocar o IP em `ansible/inventory.ini` e rodar:

```bash
cd ansible && ansible-playbook site.yml
```

Instala Docker, inicializa o Swarm, sobe Traefik + app + Uptime Kuma e valida o `/health`. Com domínio, apontar o registro A para o IP novo; o certificado é reemitido sozinho. O histórico do Uptime Kuma se perde se o volume `kuma_data` não tiver backup.

## Perguntas de defesa

**Ponto único de falha:** o servidor. Ele hospeda proxy, aplicação e monitoramento; se cair, tudo cai junto — inclusive o monitoramento, que não conseguiria reportar a própria queda.

**Como tornar mais resiliente:** monitoramento externo, Swarm com mais nós (o Ansible já está organizado por inventário — bastaria adicionar hosts e uma etapa de `swarm join`), backup dos volumes, snapshot do servidor e balanceador na frente.

**O que acontece ao remover o container:** a imagem e os volumes nomeados permanecem; perde-se só a camada de escrita do container. Num serviço Swarm, uma nova task é criada automaticamente para manter as réplicas.

**Ansible x script shell:** o shell executa comandos; o Ansible descreve o estado desejado e só age quando o estado atual é diferente (idempotência). Rodar duas vezes não duplica nada — a segunda execução termina com `changed=0`.
