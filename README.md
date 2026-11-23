# Projeto Final — Nuvem Privada com LXD (Trilha B: API de Tarefas + PostgreSQL)

Infraestrutura de nuvem privada em 3 camadas (`proxy`, `app`, `db`) provisionada via LXD com redes isoladas (`net-prod` e `net-dev`), persistência em volumes dedicados, ACLs de rede, controle de acesso por certificados restritos e TLS.

## Arquitetura e Topologia
- **Projeto LXD:** `final-equipe3`
- **Armazenamento:** Pool `pool-final` com volumes persistentes `vol-db` (prod) e `dev-vol-db` (dev) montados em `/dados`
- **Camadas (Produção — `net-prod` / `10.10.10.0/24`):**
  - `proxy` (`10.10.10.10`): Nginx com terminação TLS (`servico.lab`, portas externas `8081` HTTP e `8444` HTTPS)
  - `app` (`10.10.10.11`): API REST em Python/FastAPI (`uvicorn` na porta `8000`)
  - `db` (`10.10.10.12`): PostgreSQL 16 com dados persistidos em `/dados/pgdata`
- **Camadas (Desenvolvimento — `net-dev` / `10.10.20.0/24`):**
  - `dev-proxy` (`10.10.20.10`, porta externa `8082`), `dev-app` (`10.10.20.11`), `dev-db` (`10.10.20.12`)

## Pré-requisitos
- Host Ubuntu 24.04 com LXD instalado e inicializado (`lxd init`)
- Usuário pertencente ao grupo `lxd`

## Como reproduzir o ambiente do zero
1. Clone este repositório na VM host e ajuste as permissões:
~~~bash
git clone [https://github.com/Dorgark/Facul-Cloud-Computing.git](https://github.com/Dorgark/Facul-Cloud-Computing.git)
cd Facul-Cloud-Computing
chmod +x scripts/*.sh
~~~
2. Edite `scripts/deploy.sh` substituindo `<IP-DA-VM>` pelo IP da VM host e `Troque123` por uma senha segura para o PostgreSQL.
3. Suba o ambiente de produção (`prod`) ou desenvolvimento (`dev`):
~~~bash
ENV=prod ./scripts/deploy.sh
ENV=dev ./scripts/deploy.sh
~~~
4. Verifique o estado dos serviços e recursos:
~~~bash
./scripts/monitor.sh
~~~
5. Para remover um ambiente:
~~~bash
ENV=dev ./scripts/destroy.sh
~~~

## Estrutura do Repositório
- `profiles/`: Perfis declarativos LXD (`perfil-base`, `perfil-proxy`, `perfil-app`, `perfil-db`)
- `conf/`: Código da API (`api.py`), unit `systemd`, frontend (`index.html`), configuração do Nginx e scripts de provisionamento
- `scripts/`: Automação de provisionamento (`deploy.sh`), monitoramento (`monitor.sh`) e limpeza (`destroy.sh`)
- `docs/`: Relatório técnico e evidências de validação das Fases 1 a 7