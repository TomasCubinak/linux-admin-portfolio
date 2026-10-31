# 02 – Hosting webové aplikace v Dockeru

WordPress + MariaDB za Nginx reverse proxy s HTTPS, spuštěno přes Docker Compose na Debian NASu.

```
klient ──HTTPS:8443──▶ nginx ──▶ wordpress ──▶ mariadb
                       (frontend síť)          (backend síť, internal, bez portů)
```

## Bezpečnost a návrh

- Ven je publikovaný **jen nginx**; databáze nemá žádný port a je v síti `internal: true`.
- **HTTPS** (TLS 1.2/1.3), HTTP se přesměruje na HTTPS, bezpečnostní hlavičky.
- **Hesla v `.env`**, který není v gitu; v repu je jen `.env.example`.
- **Pevné verze image** (`mariadb:11.4`) místo `latest` – aktualizace jsou řízené.
- **Healthcheck** DB + `depends_on: service_healthy` – WordPress startuje až po DB.
- **Volumes** – data přežijí smazání a aktualizaci kontejnerů.

## Spuštění (na NASu)

```bash
cp .env.example .env && nano .env          # vyplnit hesla (openssl rand -base64 24)
mkdir -p certs
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout certs/selfsigned.key -out certs/selfsigned.crt \
  -subj "/CN=192.168.0.78" -addext "subjectAltName=IP:192.168.0.78"
docker compose up -d
docker compose ps
```

Web: `https://192.168.0.78:8443`

## Problémy, na které jsem narazil

- **Port 80 už používá Apache** – nginx je publikovaný na 8080/8443.
- **Docker obchází UFW** – publikované porty Docker zapisuje přímo do iptables/nftables
  před pravidla UFW. Proto port neomezuji firewallem, ale navázáním na konkrétní IP
  (`BIND_IP`) a DB nepublikuji vůbec.
