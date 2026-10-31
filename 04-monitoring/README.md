# 04 – Monitoring: Prometheus + Grafana

Monitoring NASu, notebooku, webu z projektu 02 a záloh z projektu 03.

```
node_exporter (NAS, notebook) ─┐
blackbox exporter (web HTTPS) ─┼─▶ Prometheus ─▶ Grafana
wp_backup.prom (textfile) ─────┘   (alerty)
```

## Co se hlídá (alerts.yml)

| Alert | Podmínka |
|---|---|
| ServerNedostupny | node_exporter neodpovídá 2 min |
| DiskSkoroPlny | < 15 % volného místa |
| MaloPameti | < 10 % volné RAM |
| VysokeVytizeniCPU | > 90 % po 10 min |
| WebNedostupny | HTTPS kontrola webu selhává 1 min |
| CertifikatBrzyExpiruje | < 14 dní do expirace |
| ZalohaNeprobehla | poslední úspěšná záloha starší než 26 h |

## Návrh a bezpečnost

- **node_exporter** běží nativně (balíček Debianu), nainstalovaný Ansiblem z projektu 01.
  UFW pouští port 9100 jen z Docker sítí, ne z LAN.
- **Prometheus** nemá autentizaci → publikovaný jen na `127.0.0.1`, přístup přes SSH tunel.
- **Grafana** s heslem z `.env`, registrace vypnutá, datasource přes provisioning.
- **Monitoring záloh** přes textfile collector: `backup.sh` po úspěchu zapíše metriku
  s časem zálohy (atomicky přes `mv`).
- Pevné verze image, retence dat 15 dní.

## Spuštění

```bash
cp .env.example .env && nano .env
docker compose up -d
```

- Grafana: `http://192.168.0.78:3001` → import dashboardu **1860** (Node Exporter Full)
- Prometheus: `ssh -L 9090:127.0.0.1:9090 tomas@192.168.0.78` → `http://localhost:9090`

## Problémy, na které jsem narazil

- Port 3000 už používá Next.js → Grafana na 3001.
- Prometheus v kontejneru nedosáhl na node_exporter hostitele – provoz z Docker sítě
  na IP hostitele jde přes INPUT a blokoval ho UFW. Řešení: pravidlo pro 172.16.0.0/12.

## Další krok

Alertmanager → notifikace do Telegramu / e-mailu.
