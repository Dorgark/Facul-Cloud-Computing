#!/usr/bin/env bash
# Uso: ENV=prod ./scripts/deploy.sh ou ENV=dev ./scripts/deploy.sh
set -euo pipefail

ENV="${ENV:-prod}"
PROJETO="final-equipe<N>"       # <-- TROCAR <N> PELO NÚMERO DA EQUIPE
IP_VM="<IP-DA-VM>"              # <-- TROCAR PELO IP DA VM (ex: 192.168.1.50)
SENHA_DB="Troque123"            # <-- TROCAR PELA SENHA USADA PELO GRUPO
POOL="pool-final"
IMAGEM="ubuntu:24.04"

if [ "$ENV" = "prod" ]; then
    REDE="net-prod"; SUBNET="10.10.10"; PORTA_HTTP=8081; PORTA_HTTPS=8444; PREFIXO=""
else
    REDE="net-dev"; SUBNET="10.10.20"; PORTA_HTTP=8082; PORTA_HTTPS=8445; PREFIXO="dev-"
fi

rede() {
    lxc network show "$REDE" >/dev/null 2>&1 || \
    lxc network create "$REDE" ipv4.address="$SUBNET.1/24" ipv4.nat=true ipv6.address=none
}

storage() {
    lxc storage show "$POOL" >/dev/null 2>&1 || lxc storage create "$POOL" dir
    lxc storage volume show "$POOL" "${PREFIXO}vol-db" >/dev/null 2>&1 || \
    lxc storage volume create "$POOL" "${PREFIXO}vol-db"
    # Na Trilha B não há volumes extras para a aplicação
}

perfis() {
    for p in perfil-base perfil-proxy perfil-app perfil-db; do
        lxc profile show "$p" >/dev/null 2>&1 || lxc profile create "$p"
        lxc profile edit "$p" < "profiles/$p.yaml"
    done
}

criar_instancia() { # uso: criar_instancia nome ip perfil-papel
    local nome="${PREFIXO}$1" ip="$2" papel="$3"
    lxc delete -f "$nome" 2>/dev/null || true
    lxc init "$IMAGEM" "$nome" -p perfil-base -p "$papel"
    lxc config device override "$nome" eth0 network="$REDE" ipv4.address="$ip"
}

iniciar() { # uso: iniciar nome
    lxc start "${PREFIXO}$1"
    lxc exec "${PREFIXO}$1" -- cloud-init status --wait >/dev/null
}

main() {
    lxc project show "$PROJETO" >/dev/null 2>&1 || \
    lxc project create "$PROJETO" -c features.images=false -c features.profiles=false
    lxc project switch "$PROJETO"

    rede; storage; perfis

    # 1. BANCO DE DADOS (PostgreSQL)
    criar_instancia db "$SUBNET.12" perfil-db
    lxc config device add "${PREFIXO}db" dados disk pool="$POOL" source="${PREFIXO}vol-db" path=/dados
    iniciar db
    lxc file push conf/config-postgres.sh "${PREFIXO}db/root/config-postgres.sh"
    lxc exec "${PREFIXO}db" -- bash /root/config-postgres.sh "$SUBNET.11" tarefas apiuser "$SENHA_DB"

    # 2. APLICAÇÃO (FastAPI)
    criar_instancia app "$SUBNET.11" perfil-app
    iniciar app
    for f in api.py api.service instala-api.sh; do
        lxc file push "conf/$f" "${PREFIXO}app/root/$f"
    done
    # Ajusta o IP do banco e a senha no api.service caso esteja rodando em DEV
    lxc exec "${PREFIXO}app" -- sed -i "s/DB_HOST=.*/DB_HOST=$SUBNET.12/" /root/api.service
    lxc exec "${PREFIXO}app" -- sed -i "s/DB_PASS=.*/DB_PASS=$SENHA_DB/" /root/api.service
    lxc exec "${PREFIXO}app" -- bash /root/instala-api.sh

    # 3. PROXY REVERSO E FRONTEND ESTÁTICO (Nginx + TLS)
    criar_instancia proxy "$SUBNET.10" perfil-proxy
    iniciar proxy
    lxc file push conf/index.html "${PREFIXO}proxy/var/www/html/index.html"
    lxc file push conf/nginx-servico.conf "${PREFIXO}proxy/etc/nginx/sites-available/servico"
    # Ajusta o IP da API no nginx-servico.conf para funcionar tanto em PROD (.11) quanto em DEV (.11)
    lxc exec "${PREFIXO}proxy" -- sed -i "s/10\.10\.10\.11/$SUBNET.11/g" /etc/nginx/sites-available/servico

    # Envia certificado e chave TLS (se já tiverem sido gerados na Fase 5)
    if [ -f "conf/tls/servico.crt" ] && [ -f "conf/tls/servico.key" ]; then
        lxc file push conf/tls/servico.crt "${PREFIXO}proxy/etc/ssl/certs/servico.crt"
        lxc file push conf/tls/servico.key "${PREFIXO}proxy/etc/ssl/private/servico.key" --mode 0600
    fi

    lxc exec "${PREFIXO}proxy" -- bash -c "ln -sf /etc/nginx/sites-available/servico /etc/nginx/sites-enabled/servico && rm -f /etc/nginx/sites-enabled/default && nginx -t && systemctl reload nginx"

    lxc config device add "${PREFIXO}proxy" porta-http proxy listen=tcp:0.0.0.0:$PORTA_HTTP connect=tcp:127.0.0.1:80
    lxc config device add "${PREFIXO}proxy" porta-https proxy listen=tcp:0.0.0.0:$PORTA_HTTPS connect=tcp:127.0.0.1:443

    echo "Ambiente $ENV no ar!"
    echo "HTTP : http://$IP_VM:$PORTA_HTTP"
    echo "HTTPS: https://$IP_VM:$PORTA_HTTPS"
}

main "$@"