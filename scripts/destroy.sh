#!/usr/bin/env bash
set -euo pipefail

ENV="${ENV:-prod}"
lxc project switch final-equipe3 >/dev/null 2>&1 || true
[ "$ENV" = "prod" ] && PREFIXO="" || PREFIXO="dev-"

for i in proxy app db; do
    lxc delete -f "${PREFIXO}$i" 2>/dev/null || true
done

echo "Instancias removidas. Os volumes foram mantidos (use --volumes para apaga-los)."

if [ "${1:-}" = "--volumes" ]; then
    for v in $(lxc storage volume list pool-final -c n --format csv | grep "^${PREFIXO}vol-"); do
        lxc storage volume delete pool-final "$v"
    done
fi
