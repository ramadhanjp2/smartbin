# Dokumentasi Instalasi dan Integrasi MQTT SmartBin

## 1. Tujuan

Dokumentasi ini menjelaskan instalasi, konfigurasi, autentikasi, dan integrasi MQTT untuk dua perangkat SmartBin, yaitu ESP1 dan ESP2, dengan backend aplikasi.

MQTT Broker menggunakan Eclipse Mosquitto dalam Docker. Koneksi perangkat eksternal menggunakan WebSocket Secure (WSS) melalui Cloudflare Tunnel.

## 2. Arsitektur

```text
ESP1 (akun esp1) ───────┐
                        │ WSS / TLS 443
ESP2 (akun esp2) ───────┤
                        ▼
             Cloudflare Tunnel
                        │
                        ▼
               Mosquitto Broker
                127.0.0.1:9001
                        │
                        ▼
              Backend SmartBin
            (akun smartbin_backend)
```

## 3. Informasi server dan credential

Isi kolom credential berikut secara manual. Simpan password di password manager atau secret manager, bukan di dokumentasi yang dibagikan secara publik.

### 3.1. Informasi broker

| Parameter           | Nilai                                           |
| ------------------- | ----------------------------------------------- |
| MQTT Broker         | Eclipse Mosquitto 2.x                           |
| Versi terpasang     | 2.1.2                                           |
| Domain              | `mqtt-smartbin.ramadhanjp.my.id`                |
| Port eksternal      | `443`                                           |
| Transport           | WSS                                             |
| WebSocket Path      | `/mqtt`                                         |
| MQTT Version        | MQTT 3.1.1 atau MQTT 5.0 sesuai dukungan client |
| Direktori instalasi | `/opt/mqtt`                                     |
| Container           | `mqtt-broker`                                   |
| Listener internal   | `127.0.0.1:9001`                                |

### 3.2. Tabel credential perangkat

| Credential    | ESP1                                 | ESP2                                 |
| ------------- | ------------------------------------ | ------------------------------------ |
| Device ID     | `esp1`                               | `esp2`                               |
| Username MQTT | `esp1`                               | `esp2`                               |
| Password MQTT | P\@ssw0rdesp1                        | P\@ssw0rdesp2                        |
| Client ID     | `smartbin-esp1`                      | `smartbin-esp2`                      |
| PIC perangkat | \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_ | \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_ |
| Keterangan    | \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_ | \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_ |

### 3.3. Credential backend

| Credential        | Nilai                                |
| ----------------- | ------------------------------------ |
| Username MQTT     | `smartbin_backend`                   |
| Password MQTT     | P\@ssw0rd                            |
| Client ID backend | `smartbin_backend`                   |
| Keterangan        | \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_ |

## 4. Instalasi Mosquitto menggunakan Docker

### 4.1. Persiapan direktori

```bash
mkdir -p /opt/mqtt/mosquitto/config
mkdir -p /opt/mqtt/mosquitto/data
cd /opt/mqtt
```

Struktur direktori:

```text
/opt/mqtt/
├── compose.yaml
└── mosquitto/
    ├── config/
    │   ├── mosquitto.conf
    │   ├── passwd
    │   └── acl
    └── data/
```

### 4.2. Konfigurasi Mosquitto

Buat file `/opt/mqtt/mosquitto/config/mosquitto.conf`:

```bash
cat > /opt/mqtt/mosquitto/config/mosquitto.conf <<'EOF'
listener 9001 0.0.0.0
protocol websockets

allow_anonymous false
password_file /mosquitto/config/passwd
acl_file /mosquitto/config/acl

persistence true
persistence_location /mosquitto/data/
autosave_interval 300

max_connections 500
max_packet_size 1048576
max_queued_messages 1000
max_inflight_messages 20

log_dest stdout
log_type all
connection_messages true
log_timestamp true
EOF
```

### 4.3. Membuat akun ESP1, ESP2, dan backend

Buat akun ESP1:

```bash
docker run --rm -it \
  -v /opt/mqtt/mosquitto/config:/mosquitto/config \
  eclipse-mosquitto:2 \
  mosquitto_passwd -c /mosquitto/config/passwd esp1
```

Buat akun ESP2:

```bash
docker run --rm -it \
  -v /opt/mqtt/mosquitto/config:/mosquitto/config \
  eclipse-mosquitto:2 \
  mosquitto_passwd /mosquitto/config/passwd esp2
```

Buat akun backend:

```bash
docker run --rm -it \
  -v /opt/mqtt/mosquitto/config:/mosquitto/config \
  eclipse-mosquitto:2 \
  mosquitto_passwd /mosquitto/config/passwd smartbin_backend
```

Masukkan password berbeda untuk masing-masing akun saat diminta.

**Penting:** gunakan `-c` hanya saat membuat file password baru. Jangan gunakan `-c` ketika menambahkan akun kedua atau ketiga karena file akan dibuat ulang.

Atur permission:

```bash
chown root:1883 /opt/mqtt/mosquitto/config/passwd
chmod 640 /opt/mqtt/mosquitto/config/passwd
```

### 4.4. Konfigurasi ACL

ACL membatasi setiap perangkat agar hanya dapat mengakses topiknya sendiri.

```bash
cat > /opt/mqtt/mosquitto/config/acl <<'EOF'
user esp1
topic write smartbin/esp1/telemetry/#
topic read smartbin/esp1/command/#

user esp2
topic write smartbin/esp2/telemetry/#
topic read smartbin/esp2/command/#

user smartbin_backend
topic read smartbin/+/telemetry/#
topic write smartbin/+/command/#
EOF
```

Atur permission file:

```bash
chown root:1883 /opt/mqtt/mosquitto/config/acl
chmod 640 /opt/mqtt/mosquitto/config/acl

chown root:1883 /opt/mqtt/mosquitto/config/mosquitto.conf
chmod 640 /opt/mqtt/mosquitto/config/mosquitto.conf

chown 1883:1883 /opt/mqtt/mosquitto/data
chmod 750 /opt/mqtt/mosquitto/data
```

### 4.5. Docker Compose

Buat `/opt/mqtt/compose.yaml`:

```yaml
services:
  mqtt-broker:
    image: eclipse-mosquitto:2
    container_name: mqtt-broker
    restart: unless-stopped
    ports:
      - "127.0.0.1:9001:9001"
    volumes:
      - ./mosquitto/config/mosquitto.conf:/mosquitto/config/mosquitto.conf:ro
      - ./mosquitto/config/passwd:/mosquitto/config/passwd:ro
      - ./mosquitto/config/acl:/mosquitto/config/acl:ro
      - ./mosquitto/data:/mosquitto/data
    read_only: true
    tmpfs:
      - /tmp
    security_opt:
      - no-new-privileges:true
    cap_drop:
      - ALL
```

Jalankan validasi konfigurasi:

```bash
docker run --rm \
  -v /opt/mqtt/mosquitto/config:/mosquitto/config:ro \
  eclipse-mosquitto:2 \
  mosquitto --test-config -c /mosquitto/config/mosquitto.conf
```

Jika valid, jalankan broker:

```bash
cd /opt/mqtt
docker compose up -d
docker compose ps
docker logs --tail 100 mqtt-broker
```

Pastikan port broker hanya terikat ke loopback:

```bash
ss -lntp | grep ':9001'
```

## 5. Konfigurasi Cloudflare Tunnel

Buat public hostname berikut pada tunnel yang digunakan server:

| Parameter    | Nilai                            |
| ------------ | -------------------------------- |
| Hostname     | `mqtt-smartbin.ramadhanjp.my.id` |
| Service Type | HTTP                             |
| Service URL  | `http://127.0.0.1:9001`          |

Endpoint yang digunakan ESP1 dan ESP2:

```text
wss://mqtt-smartbin.ramadhanjp.my.id/mqtt
```

Periksa service tunnel:

```bash
systemctl status cloudflared
journalctl -u cloudflared -n 100 --no-pager
```

Jangan membuka port `9001` secara langsung ke internet.

## 6. Konfigurasi koneksi ESP1 dan ESP2

| Parameter    | ESP1                              | ESP2                              |
| ------------ | --------------------------------- | --------------------------------- |
| Host         | `mqtt-smartbin.ramadhanjp.my.id`  | `mqtt-smartbin.ramadhanjp.my.id`  |
| Port         | `443`                             | `443`                             |
| TLS          | Aktif                             | Aktif                             |
| Transport    | WSS                               | WSS                               |
| Path         | `/mqtt`                           | `/mqtt`                           |
| MQTT Version | 3.1.1 atau sesuai dukungan client | 3.1.1 atau sesuai dukungan client |
| Username     | `esp1`                            | `esp2`                            |
| Password     | Isi dari tabel credential         | Isi dari tabel credential         |
| Client ID    | `smartbin-esp1`                   | `smartbin-esp2`                   |

Pastikan library MQTT pada firmware ESP mendukung WebSocket Secure. Jika hanya mendukung MQTT TCP/TLS biasa, endpoint WSS tidak dapat langsung digunakan tanpa library atau arsitektur koneksi yang sesuai.

## 7. Standar topik MQTT

| Fungsi          | ESP1                              | ESP2                              |
| --------------- | --------------------------------- | --------------------------------- |
| Status          | `smartbin/esp1/telemetry/status`  | `smartbin/esp2/telemetry/status`  |
| Sensor          | `smartbin/esp1/telemetry/sensor`  | `smartbin/esp2/telemetry/sensor`  |
| Deposit         | `smartbin/esp1/telemetry/deposit` | `smartbin/esp2/telemetry/deposit` |
| Command kontrol | `smartbin/esp1/command/control`   | `smartbin/esp2/command/control`   |
| Command test    | `smartbin/esp1/command/test`      | `smartbin/esp2/command/test`      |

Backend menggunakan:

- Subscribe: `smartbin/+/telemetry/#`
- Publish: `smartbin/+/command/#`

## 8. Contoh payload

### 8.1. Telemetry status

Publish ESP1 ke `smartbin/esp1/telemetry/status`:

```json
{
  "schema_version": 1,
  "device_id": "esp1",
  "timestamp": "2026-10-29T10:00:00Z",
  "status": "online"
}
```

ESP2 menggunakan format yang sama dengan `device_id` bernilai `esp2` dan topik `smartbin/esp2/telemetry/status`.

### 8.2. Command dari backend

Backend dapat publish ke `smartbin/esp1/command/control`:

```json
{
  "command_id": "cmd-esp1-001",
  "command": "ping",
  "timestamp": "2026-10-29T10:00:00Z"
}
```

Untuk ESP2, gunakan topik `smartbin/esp2/command/control` dan `command_id` yang unik.

## 9. Pengujian menggunakan MQTTX

Buat dua koneksi di MQTTX:

**Koneksi ESP1**

- Host: `mqtt-smartbin.ramadhanjp.my.id`
- Port: `443`
- Transport: WebSocket Secure
- Path: `/mqtt`
- Username: `esp1`
- Password: sesuai tabel credential
- Client ID: `smartbin-esp1`

**Koneksi ESP2**

- Gunakan parameter yang sama, dengan username `esp2` dan Client ID `smartbin-esp2`.

**Koneksi backend**

- Username: `smartbin_backend`
- Password: sesuai tabel credential
- Client ID: tentukan secara unik

Uji alur berikut:

1. Backend subscribe ke `smartbin/+/telemetry/#`.
2. ESP1 publish ke `smartbin/esp1/telemetry/status`.
3. ESP2 publish ke `smartbin/esp2/telemetry/status`.
4. Pastikan kedua pesan diterima backend.
5. Backend publish command ke masing-masing perangkat.
6. Pastikan perangkat yang dituju menerima command.

Periksa log broker:

```bash
docker logs -f mqtt-broker
```

## 10. Pengujian keamanan ACL

Pastikan pengujian berikut berhasil sesuai aturan:

| Pengujian                                   | Hasil yang diharapkan |
| ------------------------------------------- | --------------------- |
| ESP1 publish ke telemetry ESP1              | Diizinkan             |
| ESP2 publish ke telemetry ESP2              | Diizinkan             |
| ESP1 publish ke telemetry ESP2              | Ditolak               |
| ESP2 publish ke telemetry ESP1              | Ditolak               |
| ESP1 subscribe command ESP1                 | Diizinkan             |
| ESP2 subscribe command ESP2                 | Diizinkan             |
| ESP1 subscribe command ESP2                 | Ditolak               |
| ESP2 subscribe command ESP1                 | Ditolak               |
| Backend subscribe semua telemetry perangkat | Diizinkan             |
| Backend publish command ke ESP1 dan ESP2    | Diizinkan             |

Jangan hanya mengandalkan status koneksi. Verifikasi izin publish dan subscribe aktual serta log broker.

## 11. Keamanan dan operasional

- Gunakan password yang berbeda untuk setiap perangkat.
- Jangan menyimpan password dalam repository publik.
- Simpan credential dalam password manager atau secret manager.
- Gunakan TLS dan validasi sertifikat pada client.
- Validasi payload dan command pada firmware maupun backend.
- Gunakan QoS 0 untuk telemetry rutin yang tidak kritis.
- Pertimbangkan QoS 1 dan acknowledgement aplikasi untuk command penting.
- Hindari retained message untuk command aktuator yang berisiko.
- Buat backup konfigurasi sebelum perubahan ACL atau credential.

## 12. Pemeliharaan

Periksa status broker:

```bash
cd /opt/mqtt
docker compose ps
docker logs --tail 100 mqtt-broker
```

Validasi lalu restart setelah perubahan konfigurasi:

```bash
docker run --rm \
  -v /opt/mqtt/mosquitto/config:/mosquitto/config:ro \
  eclipse-mosquitto:2 \
  mosquitto --test-config -c /mosquitto/config/mosquitto.conf

docker compose restart mqtt-broker
```

Backup konfigurasi:

```bash
tar -czf "/opt/mqtt-backup-$(date +%F-%H%M%S).tar.gz" \
  -C /opt/mqtt mosquitto/config compose.yaml
```

Lakukan backup data persistence secara terencana agar file broker konsisten.

## 13. Checklist penerimaan

- [ ] Broker berjalan dan konfigurasi valid.
- [ ] Akun ESP1 berhasil autentikasi.
- [ ] Akun ESP2 berhasil autentikasi.
- [ ] Akun backend berhasil autentikasi.
- [ ] ESP1 dan ESP2 menggunakan credential berbeda.
- [ ] Telemetry kedua perangkat diterima backend.
- [ ] Command backend diterima perangkat yang tepat.
- [ ] ACL menolak akses silang antarperangkat.
- [ ] Port broker tidak terbuka langsung ke internet.
- [ ] Password disimpan secara aman.
- [ ] Backup konfigurasi dan prosedur pemulihan tersedia.
