#!/bin/sh
# Mantém só a pasta de backup datada mais recente em graphify-out/ (formato YYYY-MM-DD),
# apagando as anteriores. Rodar depois de commits/atualizações robustas do projeto.

cd "$(dirname "$0")/.." || exit 1

FOLDERS=$(find graphify-out -maxdepth 1 -type d -regextype posix-extended -regex '.*/[0-9]{4}-[0-9]{2}-[0-9]{2}$' | sort)
COUNT=$(echo "$FOLDERS" | grep -c . || true)

if [ "$COUNT" -le 1 ]; then
    echo "Nada para limpar ($COUNT pasta(s) de backup encontrada(s))."
    exit 0
fi

KEEP=$(echo "$FOLDERS" | tail -n 1)
echo "Mantendo: $KEEP"

echo "$FOLDERS" | grep -v "^${KEEP}$" | while read -r dir; do
    [ -n "$dir" ] || continue
    echo "Removendo: $dir"
    rm -rf "$dir"
done
