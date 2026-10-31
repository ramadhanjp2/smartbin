# Dokumentasi Instalasi dan Integrasi MQTT SmartBin

## 1. Tujuan

Dokumentasi ini menjelaskan instalasi, konfigurasi, autentikasi, dan integrasi MQTT untuk perangkat gateway SmartBIN dan backend. `esp1` dan `esp2` adalah contoh ID gateway; petakan setiap ID ke kode mesin MySQL melalui `MQTT_DEVICE_MACHINE_MAP`.

MQTT Broker menggunakan Eclipse Mosquitto dalam Docker. Koneksi perangkat eksternal menggunakan WebSocket Secure (WSS) melalui Cloudflare Tunnel.

## 2. Arsitektur

```text
ESP1 gateway (akun esp1) ┐
                        │ WSS / TLS 443
ESP2 gateway (akun esp2) ├── Cloudflare Tunnel → Mosquitto
                        ▼
              MQTT Broker
             127.0.0.1:9001
                        ▲
                        │ WSS / TLS 443
              Backend SmartBIN
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
| Password MQTT | Ambil dari secret manager           | Ambil dari secret manager           |
| Client ID     | `smartbin-esp1`                      | `smartbin-esp2`                      |
| PIC perangkat | \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_ | \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_ |
| Keterangan    | \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_ | \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_ |

### 3.3. Credential backend

| Credential        | Nilai                                |
| ----------------- | ------------------------------------ |
| Username MQTT     | `smartbin_backend`                   |
| Password MQTT     | Ambil dari secret manager            |
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
| Fungsi                    | ESP1 gateway                         | ESP2 gateway                         |
| ------------------------- | ------------------------------------ | ------------------------------------ |
| Status/heartbeat          | `smartbin/esp1/telemetry/status`     | `smartbin/esp2/telemetry/status`     |
| Sensor                    | `smartbin/esp1/telemetry/sensor`     | `smartbin/esp2/telemetry/sensor`     |
| Validasi kartu            | `smartbin/esp1/telemetry/auth`       | `smartbin/esp2/telemetry/auth`       |
| Setoran                   | `smartbin/esp1/telemetry/deposit`    | `smartbin/esp2/telemetry/deposit`    |
| Balasan validasi kartu    | `smartbin/esp1/command/auth`         | `smartbin/esp2/command/auth`         |
| Balasan setoran/poin      | `smartbin/esp1/command/deposit`      | `smartbin/esp2/command/deposit`      |
| Command kontrol           | `smartbin/esp1/command/control`      | `smartbin/esp2/command/control`      |
| Command test              | `smartbin/esp1/command/test`         | `smartbin/esp2/command/test`         |

Backend menggunakan:

- Subscribe: `smartbin/+/telemetry/#`
- Publish: `smartbin/+/command/#`

## 8. Contoh payload

### 8.1. Telemetry status

Publish gateway ke `smartbin/esp1/telemetry/status` setiap 10 detik dan saat status berubah:

```json
{
  "schema_version": 1,
  "device_id": "esp1",
  "timestamp": "2026-10-29T10:00:00Z",
  "state": "IDLE",
  "compartments": {
    "organik_fill_pct": 35,
    "anorganik_fill_pct": 60,
    "residu_fill_pct": 12
  },
  "sekat_cm": {
    "organik": 48,
    "anorganik": 28,
    "residu": 52
  },
  "ai_online": true,
  "uptime_s": 86400
}
```

Nilai `state`: `IDLE`, `SIBUK`, `OFFLINE`, atau `GANGGUAN`; gunakan `PENUH` bila perangkat menerapkan status ringkas itu. Backend menyimpan event ke MongoDB `machine_events` dan menjadikan `machine_latest` sumber status, kapasitas, jarak sensor, serta heartbeat terkini. Metadata master mesin (nama, lokasi, dan kode) tetap di MySQL; endpoint daftar mesin menggabungkan kedua sumber. `device_id` harus sama dengan ID pada topik dan terpetakan ke kode mesin yang terdaftar di MySQL.

`telemetry/status` adalah snapshot kanonis untuk memperbarui kondisi terkini di MongoDB. Topic `telemetry/sensor` pada tabel di atas tetap tersedia untuk diagnostik sensor mentah/kompatibilitas; backend menyimpannya sebagai event MongoDB, tetapi tidak menggunakannya sebagai pengganti snapshot status. Hanya pesan `status` yang memperbarui `machine_latest`; event `auth`, `deposit`, dan `sensor` tetap tercatat di `machine_events` tanpa menimpa snapshot status.

### 8.2. Validasi kartu dan setoran

Gateway menghitung `uid_hash` sebagai HMAC-SHA256 atas UID kartu yang sudah di-trim dan di-uppercase, dengan `CARD_HMAC_SECRET` yang sama dengan backend. UID mentah tidak boleh dikirim lewat MQTT. Provisioning secret perangkat harus dilakukan secara privat.

Permintaan validasi kartu ke `smartbin/esp1/telemetry/auth`:

```json
{
  "request_id": "0a93b8b2-418f-4dc7-9e03-a5b1e6af2d40",
  "uid_hash": "<64 karakter HMAC-SHA256 hex>",
  "timestamp": "2026-10-29T10:00:00Z"
}
```

Backend membalas melalui `smartbin/esp1/command/auth` dengan `request_id` yang sama serta `found`, `name`, dan `balance`.

Setoran dipublikasikan ke `smartbin/esp1/telemetry/deposit`:

```json
{
  "transaction_id": "8f14e45f-ea2b-4c1a-9c3d-71b0f2a65e40",
  "uid_hash": "<64 karakter HMAC-SHA256 hex>",
  "type": "ORGANIK",
  "item_label": "Botol PET",
  "weight_g": 128,
  "confidence": 0.91,
  "timestamp": "2026-10-29T10:00:00Z"
}
```

`type` adalah `ORGANIK`, `ANORGANIK`, atau `RESIDU`. Backend menghitung poin dari berat dan tarif tersimpan, mengabaikan retry dengan `transaction_id` yang sudah diproses, lalu membalas melalui `smartbin/esp1/command/deposit` dengan `transaction_id`, `points`, `balance`, `status`, dan `duplicate`. Setoran `RESIDU` selalu bernilai nol poin.

### 8.3. Command dari backend

Backend dapat publish ke `smartbin/esp1/command/control`:

```json
{
  "command_id": "cmd-esp1-001",
  "command": "reset_gangguan",
  "timestamp": "2026-10-29T10:00:00Z"
}
```

Command yang didukung: `reset_gangguan`, `buka_pintu`, `kalibrasi`, `ping`. Gunakan topik device yang tepat dan `command_id` unik. ACK QoS hanya memastikan broker menerima pesan, bukan bahwa aksi fisik selesai; gateway harus menerbitkan status/ACK aplikasi setelah menjalankan command.

### QoS, timeout, dan LWT

Gunakan QoS 1 untuk `auth`, `deposit`, dan command; gateway mencocokkan balasan melalui ID permintaan dan harus idempoten terhadap duplikat. Status heartbeat diterbitkan tiap 10 detik. Setel Last Will pada topic status berisi `state: OFFLINE`; backend juga mencatat timestamp heartbeat terakhir. Batas tunggu `T_AUTH`/`T_DEPOSIT` dijalankan firmware, bukan broker/backend.

Backend terhubung melalui `MQTT_URL=wss://mqtt-smartbin.ramadhanjp.my.id:443/mqtt` (port 443, validasi sertifikat TLS aktif). Jangan menggunakan `mqtt://...:1883` kecuali broker internal dan listener TCP tersebut memang dikonfigurasi.

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
2. ESP1 publish heartbeat ke `smartbin/esp1/telemetry/status`.
3. ESP2 publish heartbeat ke `smartbin/esp2/telemetry/status`.
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
- Jangan menaruh password credential aktif dalam dokumentasi atau Git; jika credential sebelumnya pernah dipakai, rotasikan.
- Validasi payload dan command pada firmware maupun backend.
- Gunakan QoS 1 untuk transaksi, status, dan command SmartBIN v2. Command aktuator tetap perlu ACK aplikasi karena PUBACK MQTT bukan bukti aksi fisik berhasil.
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
