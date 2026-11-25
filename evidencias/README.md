# Evidências da N2

| Arquivo | Conteúdo |
|---|---|
| `ansible-run.log` | Saída da primeira execução do `ansible-playbook site.yml` num servidor novo |
| `ansible-run-2.log` | Segunda execução seguida — prova de idempotência (`changed=0`) |
| `deploy-<servidor>.md` | Gerado pelo próprio playbook: versões, nós do Swarm, serviços da stack e resposta do `/health` |

Para gerar:

```bash
cd ansible
ansible-playbook site.yml | tee ../evidencias/ansible-run.log
ansible-playbook site.yml | tee ../evidencias/ansible-run-2.log
```
