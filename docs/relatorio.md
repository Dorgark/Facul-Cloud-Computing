# Relatório Técnico — Projeto Final de Cloud Computing (Equipe 3)

## 1. Visão Geral da Arquitetura
Foi implementada uma infraestrutura de nuvem privada isolada utilizando **LXD** sobre host Ubuntu 24.04, estruturada no projeto dedicado **`final-equipe3`**. A aplicação (Trilha B — API de Tarefas) segue o modelo em 3 camadas desacopladas:
- **Camada de Borda (`proxy`):** Servidor Nginx atuando como proxy reverso, servindo o frontend estático e encaminhando chamadas `/api/` para o backend, com terminação TLS (`CN=servico.lab`) assinada por uma Autoridade Certificadora interna (`CN=CA da Equipe 3`).
- **Camada de Aplicação (`app`):** Serviço REST em Python (`FastAPI` + `Uvicorn`) gerenciado via `systemd` (`api.service`), sem exposição direta de portas externas.
- **Camada de Dados (`db`):** Banco relacional PostgreSQL 16 isolado na sub-rede interna, sem exposição de porta externa (`5432` bloqueada externamente) e com diretório de dados (`PGDATA`) montado em volume persistente dedicado.

## 2. Segmentação de Rede e Segurança
- **Isolamento de Ambientes:** Foram criadas duas bridges gerenciadas distintas: `net-prod` (`10.10.10.0/24`) para produção e `net-dev` (`10.10.20.0/24`) para desenvolvimento/homologação.
- **ACLs de Rede (`acl-prod` e `acl-dev`):** Aplicadas regras explícitas de bloqueio (`drop`) de tráfego `ingress` e `egress` entre as sub-redes `10.10.10.0/24` e `10.10.20.0/24`, impedindo comunicação lateral entre desenvolvimento e produção, mantendo apenas o acesso de saída necessário para atualização de pacotes.
- **Exposição Mínima:** Apenas os proxies possuem dispositivos `proxy` mapeados no host (`8081` HTTP redirecionando para `8444` HTTPS em produção; `8082` HTTP em desenvolvimento).
- **Controle de Acesso LXD:** Criado certificado de cliente restrito (`operador-equipe3`) vinculado exclusivamente ao projeto `final-equipe3`, impedindo visualização ou alteração do projeto `default` e das configurações globais do daemon.

## 3. Persistência, Backup e Recuperação de Desastres
- **Volumes Dedicados:** Criado o storage pool `pool-final` e os volumes customizados `vol-db` (produção) e `dev-vol-db` (desenvolvimento) anexados em `/dados`.
- **Validação de Persistência:** O container `db` foi destruído (`lxc delete -f db`) e recriado a partir dos perfis declarativos (`perfil-base` e `perfil-db`), reanexando o volume `vol-db` e mantendo integralmente os registros cadastrados.
- **Snapshots e Exportação:** Validada a criação de snapshots de volume (`snap-volume`) e instância (`snap-instancia`), simulada perda total de dados via `DELETE` na API e executada a restauração completa via `lxc storage volume restore`, além da exportação de backup off-host (`vol-db.tar.gz`).

## 4. Automação e Operação Multi-Ambiente
- **Perfis Declarativos (`profiles/`):** Padronização de limites de CPU/memória, pacotes iniciais e políticas de reinício por função (`perfil-base`, `perfil-proxy`, `perfil-app`, `perfil-db`).
- **Scripts Idempotentes (`scripts/`):** O script `deploy.sh` parametriza a variável `ENV` (`prod` ou `dev`), provisionando automaticamente rede, volume, containers, banco de dados, API e proxy reverso, acompanhado pelos utilitários `monitor.sh` e `destroy.sh`.

## 5. Registro de Evidências
As evidências de validação de todas as etapas encontram-se catalogadas na pasta `docs/evidencias/` cobrindo:
1. **Fases 1 a 3B (`01` a `10`):** Criação do projeto, perfis, deploy das 3 camadas, integração end-to-end e prova de persistência do volume `vol-db`.
2. **Fase 4 (`11` a `13`):** Teste de portas externas (`8081` aberta / `5432` fechada) e bloqueio de tráfego lateral via ACLs.
3. **Fase 5 (`14` a `16`):** Restrição de certificado do operador e validação HTTPS (`servico.lab:8444`).
4. **Fase 6 (`16_Fase6-2`):** Simulação de desastre e restauração instantânea de snapshot do banco.
5. **Fase 7 (`17` e `18`):** Execução simultânea dos ambientes `PROD` (`10.10.10.x`) e `DEV` (`10.10.20.x` na porta `8082`) com bancos independentes.