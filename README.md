# Projeto Final — Nuvem Privada com LXD (Trilha B: API de Tarefas + PostgreSQL)

Infraestrutura de nuvem privada em 3 camadas (`proxy`, `app`, `db`) provisionada via LXD com redes isoladas (`net-prod` e `net-dev`), persistência em volumes dedicados, controle de acesso por certificados e TLS.

## Pré-requisitos
- Host Ubuntu com LXD instalado e inicializado (`lxd init`)
- Acesso ao terminal com usuário pertencente ao grupo `lxd`

## Como reproduzir o ambiente do zero
1. Clone este repositório na VM host e entre na pasta raiz:
   ```bash
   git clone <URL-DO-REPOSITORIO>
   cd Facul-Cloud-Computing
   chmod +x scripts/*.sh