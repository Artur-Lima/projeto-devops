# Evidências da N2

Execução de ponta a ponta numa **VM Ubuntu 24.04 limpa** (runner do GitHub Actions, com o Docker pré-instalado removido antes do teste), job **Teste em VM limpa** do workflow `Ansible`:
https://github.com/Artur-Lima/projeto-devops/actions/runs/45548030689

| Arquivo | Conteúdo |
|---|---|
| `ansible-run.log` | 1ª execução do `ansible-playbook site.yml` — instala Docker, inicializa o Swarm e sobe a stack (`changed=8 failed=0`) |
| `ansible-run-2.log` | 2ª execução seguida — prova de idempotência (`changed=0 failed=0`) |
| `http-check.log` | Acesso HTTP à aplicação: `/health` com o commit em produção e página inicial `HTTP 200` |
| `deploy-<servidor>.md` | Gerado pelo próprio playbook: versão do Docker, nós do Swarm, serviços e tasks da stack, containers e resposta do `/health` |

Toda execução do workflow publica esses arquivos como artefato `evidencias-vm-limpa` na aba Actions.

Para gerar num servidor próprio:

```bash
cd ansible
ansible-playbook site.yml | tee ../evidencias/ansible-run.log
ansible-playbook site.yml | tee ../evidencias/ansible-run-2.log
```
