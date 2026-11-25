# Evidência de deploy — vm-limpa

Gerado automaticamente pelo Ansible (`ansible/roles/validate`).

| Item | Valor |
|---|---|
| Data | 2026-11-25T04:43:11Z |
| Servidor | 127.0.0.1 |
| Sistema | Ubuntu 24.04 (x86_64) |
| Python usado pelo Ansible | /usr/bin/python3 |
| Imagem da aplicação | `ghcr.io/artur-lima/projeto-devops:latest` |
| URL | http://127.0.0.1/ |

## Resposta do /health

Dentro do servidor (`http://127.0.0.1/health`), HTTP 200:

```
{"build":"25/11/2026 04:41 UTC","commit":"637836f","status":"ok"}
```

A partir da máquina que executou o Ansible (`http://127.0.0.1/health`), HTTP 200:

```
{"build":"25/11/2026 04:41 UTC","commit":"637836f","status":"ok"}
```

## Estado do Docker e da stack

### `docker version --format 'Client {{.Client.Version}} | Server {{.Server.Version}}'`

```
Client 29.10.1 | Server 29.10.1
```

### `docker node ls`

```
ID                            HOSTNAME          STATUS    AVAILABILITY   MANAGER STATUS   ENGINE VERSION
y8yh15eoqsjcbum0v3bw7i90w *   ip-10-0-139-249   Ready     Active         Leader           29.10.1
```

### `docker stack ls`

```
NAME             SERVICES
projeto-devops   3
```

### `docker stack services projeto-devops`

```
ID             NAME                         MODE         REPLICAS   IMAGE                                      PORTS
t9i31qgpgyal   projeto-devops_app           replicated   2/2        ghcr.io/artur-lima/projeto-devops:latest   
6v8jsncg84r8   projeto-devops_traefik       replicated   1/1        traefik:v3.6                               
pu0bo0735gz6   projeto-devops_uptime-kuma   replicated   1/1        louislam/uptime-kuma:1                     
```

### `docker stack ps projeto-devops --filter desired-state=running`

```
ID             NAME                           IMAGE                                      NODE              DESIRED STATE   CURRENT STATE            ERROR     PORTS
rnh9a7y99z0o   projeto-devops_app.1           ghcr.io/artur-lima/projeto-devops:latest   ip-10-0-139-249   Running         Running 28 seconds ago             
y792a83bnyux   projeto-devops_app.2           ghcr.io/artur-lima/projeto-devops:latest   ip-10-0-139-249   Running         Running 28 seconds ago             
oqg60v9m4wy0   projeto-devops_traefik.1       traefik:v3.6                               ip-10-0-139-249   Running         Running 33 seconds ago             *:80->80/tcp,*:80->80/tcp
rs41loabxmjm   projeto-devops_uptime-kuma.1   louislam/uptime-kuma:1                     ip-10-0-139-249   Running         Running 28 seconds ago             *:3001->3001/tcp,*:3001->3001/tcp
```

### `docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}'`

```
NAMES                                                    IMAGE                                      STATUS
projeto-devops_uptime-kuma.1.rs41loabxmjmaa0jtafqvne8k   louislam/uptime-kuma:1                     Up 33 seconds (healthy)
projeto-devops_app.2.y792a83bnyux9l6w0gzfx2hce           ghcr.io/artur-lima/projeto-devops:latest   Up 33 seconds (healthy)
projeto-devops_app.1.rnh9a7y99z0ocvq89b5lh6t8n           ghcr.io/artur-lima/projeto-devops:latest   Up 33 seconds (healthy)
projeto-devops_traefik.1.oqg60v9m4wy0fy0fxvs06y408       traefik:v3.6                               Up 33 seconds
```
