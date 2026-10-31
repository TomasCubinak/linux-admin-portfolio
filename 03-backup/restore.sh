#!/usr/bin/env bash
# restore.sh – obnova WordPressu ze zálohy vytvořené backup.sh
# Použití:  ./restore.sh /srv/backups/wordpress/2026-10-31_023000
#
# POZOR: přepíše aktuální databázi i soubory WordPressu.

set -euo pipefail

SRC="${1:?Použití: $0 /srv/backups/wordpress/<datum_cas>}"   # ${1:?zpráva} = bez parametru skonči s nápovědou
APP_DIR="${APP_DIR:-$HOME/app-hosting}"

log() { echo "[$(date '+%F %T')] $*"; }

# 1) Ověřit zálohu DŘÍV, než cokoli smažu
log "Kontroluji integritu zálohy $SRC…"
( cd "$SRC" && sha256sum -c SHA256SUMS )

read -rp "Opravdu přepsat aktuální web zálohou z $(basename "$SRC")? Napiš 'ano': " ANSWER
[[ "$ANSWER" == "ano" ]] || { log "Zrušeno."; exit 1; }

cd "$APP_DIR"
START=$(date +%s)

# 2) Zajistit, že kontejnery běží (např. po "docker compose down -v" nebo na novém serveru)
docker compose up -d

# 3) Počkat, až bude databáze opravdu připravená (healthy), ne jen spuštěná
log "Čekám na databázi…"
until [[ "$(docker inspect -f '{{.State.Health.Status}}' "$(docker compose ps -q db)")" == "healthy" ]]; do
  sleep 2
done

# 4) Obnova databáze – dump obsahuje DROP TABLE + CREATE TABLE, takže stará data nahradí
log "Obnovuji databázi…"
gunzip -c "$SRC/db.sql.gz" \
  | docker compose exec -T db sh -c 'exec mariadb -uroot -p"$MARIADB_ROOT_PASSWORD"'

# 5) Obnova souborů – nejdřív vyprázdnit složku (aby nezůstaly soubory, které v záloze nejsou)
log "Obnovuji soubory WordPressu…"
docker compose exec -T wordpress find /var/www/html -mindepth 1 -delete
docker compose exec -T wordpress tar xzf - -C /var/www/html < "$SRC/wp_files.tar.gz"

log "Obnova dokončena za $(( $(date +%s) - START )) s."   # $(( )) = aritmetika v bashi
