#!/usr/bin/env bash
# backup.sh – záloha WordPressu z projektu 02 (databáze + soubory + konfigurace)
#
# Výsledek:  $BACKUP_DIR/2026-10-31_023000/
#              db.sql.gz        – dump databáze
#              wp_files.tar.gz  – soubory WordPressu (pluginy, šablony, obrázky)
#              config.tar.gz    – docker-compose.yml, nginx, .env (obsahuje hesla!)
#              SHA256SUMS       – kontrolní součty (pozná poškozenou zálohu)
#
# Nastavení lze přepsat proměnnými prostředí (např. v systemd service).

# Bezpečný režim bashe:
#  -e  skonči při první chybě (jinak by skript pokračoval a tvářil se úspěšně)
#  -u  chyba při použití nedefinované proměnné (překlep v názvu = chyba, ne prázdný řetězec)
#  -o pipefail  roura (a | b) selže, když selže KTERÝKOLI příkaz, ne jen poslední
set -euo pipefail

APP_DIR="${APP_DIR:-$HOME/app-hosting}"          # ${X:-výchozí} = použij X, jinak výchozí hodnotu
BACKUP_DIR="${BACKUP_DIR:-/srv/backups/wordpress}"
KEEP_DAYS="${KEEP_DAYS:-7}"                      # kolik dní zálohy držet

TS="$(date +%Y-%m-%d_%H%M%S)"                    # časové razítko, řadí se správně i abecedně
DEST="$BACKUP_DIR/$TS"

log() { echo "[$(date '+%F %T')] $*"; }          # výpis s časem; pod systemd jde do journalu

# Při chybě: zalogovat řádek a smazat nedokončenou zálohu (polovičatá záloha je horší než žádná)
trap 'log "CHYBA na řádku $LINENO – záloha se nepovedla"; rm -rf "$DEST"' ERR

# Zámek: kdyby se skript spustil dvakrát současně (timer + ručně), druhý hned skončí
exec 9>/run/lock/wp-backup.lock
flock -n 9 || { log "Záloha už běží, končím."; exit 1; }

umask 077                                        # nové soubory uvidí jen vlastník (záloha obsahuje hesla)
mkdir -p "$DEST"
cd "$APP_DIR"

log "Start zálohy do $DEST"

# 1) DATABÁZE
# docker compose exec -T  = spusť příkaz v běžícím kontejneru; -T vypne terminál (nutné pro přesměrování a cron/systemd)
# Jednoduché uvozovky => $MARIADB_ROOT_PASSWORD se rozbalí UVNITŘ kontejneru, heslo tak není ve skriptu ani v ps
# --single-transaction = konzistentní snímek InnoDB bez zamykání tabulek (web běží dál)
# --databases = do dumpu se zapíše i CREATE DATABASE / USE => obnova je jednodušší
log "Dump databáze…"
docker compose exec -T db sh -c \
  'exec mariadb-dump -uroot -p"$MARIADB_ROOT_PASSWORD" --single-transaction --routines --triggers --databases "$MARIADB_DATABASE"' \
  | gzip > "$DEST/db.sql.gz"

# 2) SOUBORY WORDPRESSU
# tar czf - = zabal a komprimuj na standardní výstup ("-"), ten přesměruji do souboru na hostiteli
# -C /var/www/html . = zabal OBSAH této složky (relativní cesty => obnova kamkoliv)
log "Archiv souborů WordPressu…"
docker compose exec -T wordpress tar czf - -C /var/www/html . > "$DEST/wp_files.tar.gz"

# 3) KONFIGURACE (bez ní by obnova na nový server nešla – .env má hesla k DB)
log "Archiv konfigurace…"
tar czf "$DEST/config.tar.gz" docker-compose.yml nginx .env

# 4) KONTROLA
# gzip -t = otestuje, že archiv jde rozbalit; sha256sum = otisky pro pozdější ověření
log "Kontrola integrity…"
gzip -t "$DEST"/*.gz
( cd "$DEST" && sha256sum ./*.gz > SHA256SUMS )

# 5) RETENCE – smazat zálohy starší než KEEP_DAYS dní
# -mindepth 1 -maxdepth 1 = jen přímé podsložky, nikdy BACKUP_DIR samotný
log "Mažu zálohy starší než $KEEP_DAYS dní…"
find "$BACKUP_DIR" -mindepth 1 -maxdepth 1 -type d -mtime +"$KEEP_DAYS" -print -exec rm -rf {} +

# Značka úspěchu – monitoring (krok 4) podle jejího stáří pozná, že zálohy přestaly běžet
touch "$BACKUP_DIR/last_success"

log "Hotovo: $(du -sh "$DEST" | cut -f1) v $DEST"
