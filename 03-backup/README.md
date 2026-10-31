# 03 – Zálohy a otestovaná obnova

Denní automatická záloha WordPressu z projektu 02 (databáze, soubory, konfigurace)
pomocí bash skriptu a systemd timeru. Obnova je skriptovaná a **otestovaná**.

## Co se zálohuje

| Soubor | Obsah | Jak |
|---|---|---|
| `db.sql.gz` | databáze | `mariadb-dump --single-transaction` (bez výpadku webu) |
| `wp_files.tar.gz` | pluginy, šablony, obrázky | `tar` z kontejneru |
| `config.tar.gz` | compose, nginx, `.env` | bez nich nejde obnovit na nový server |
| `SHA256SUMS` | kontrolní součty | ověření před obnovou |

Retence 7 dní, zálohy jen pro vlastníka (`umask 077`), zámek proti souběžnému běhu (`flock`).

## Instalace (na NASu)

```bash
sudo install -d -o tomas -g tomas -m 700 /srv/backups/wordpress
sudo install -m 755 backup.sh /usr/local/bin/wp-backup.sh
sudo cp systemd/wp-backup.* /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now wp-backup.timer
```

## Test obnovy (disaster recovery)

1. Vytvořit v WordPressu příspěvek „Test zálohy“, spustit zálohu.
2. Simulovat havárii: `docker compose down -v` (smaže kontejnery **i data**).
3. `./restore.sh /srv/backups/wordpress/<datum>`
4. Ověřit, že web i příspěvek jsou zpět.

**Výsledek:** obnova trvala _XX_ s. (doplnit)

## Pravidlo 3-2-1

3 kopie dat, 2 různá média, 1 mimo lokalitu. Tady: data na NASu, záloha na NASu,
kopie na notebook (`rsync`). Dalším krokem by byla šifrovaná offsite kopie (restic → cloud).

## Problémy, na které jsem narazil

- Komentáře na konci řádku v systemd unitách nejsou povolené (stejně jako v `sshd_config`).
- `docker compose exec` bez `-T` v timeru selže – není terminál.
