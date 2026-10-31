# Alur SmartBIN v2 — Spesifikasi Lengkap (celah ditambal & dioptimalkan)

Oct 31, 2026 · @Ramadhan

## Ringkasan perubahan

Sepuluh celah ditambal dengan tiga prinsip: **gagal dengan aman** (setiap langkah fisik diverifikasi sensor), **wajib online** (tanpa SD card, mesin menolak transaksi saat server tidak terjangkau), dan **backend yang berwenang** (poin dihitung di server, bukan di ESP32).

| # | Celah | Cara ditambal |
| --- | --- | --- |
| 1 | Mesin wajib online tapi tidak dicek | Status OFFLINE: LED kuning berkedip, LCD "Mesin offline", slot KTP ditolak. Dicek saat boot, lalu heartbeat tiap 10 detik |
| 2 | Cek akun bisa menggantung | Semua permintaan MQTT bawa `request_id` + batas waktu. Habis waktu → nada error, LCD "Server sibuk", kembali idle |
| 3 | Poin dihitung ESP32 | ESP32 kirim jenis + berat, backend balas poin final. ESP32 hanya menampilkan |
| 4 | Tidak ada timeout "masukkan sampah" | Timer 30 detik → pintu tutup, LCD "Waktu habis", sesi ditutup |
| 5 | Tidak dicek sampah benar masuk | Setelah pintu tutup, berat harus ≥ `W_MIN` (5 g). Jika tidak → "Tidak ada sampah", buka pintu lagi |
| 6 | Cek tong penuh terlambat | Semua sekat dicek **sebelum** pintu dibuka. Sekat penuh → sesi ditolak, alert ke admin |
| 7 | Tidak dicek sampah sudah jatuh | Setelah platform miring, berat harus kembali ≤ `W_ZERO`. Jika tidak → goyang 2×, lalu status GANGGUAN |
| 8 | Urutan putar tong | Putar tong → verifikasi posisi → baru platform dimiringkan |
| 9 | ESP32 mengunggah gambar | Laptop mengunggah lewat HTTPS dengan `X-Machine-Api-Key` dan `Idempotency-Key` |
| 10 | Aturan KTP dicabut kabur | Sesi dikunci oleh `uid_hash` di memori, bukan oleh kartu. Transaksi berjalan tetap selesai, lalu langsung idle |

Tiga perubahan desain lain yang ikut masuk:

- **Deteksi logam pakai sensor induktif**, bukan kapasitif. Sensor kapasitif bereaksi pada hampir semua benda, jadi semua sampah akan dianggap logam.
- **Satu `transaction_id` (UUID) per sampah**, dibuat ESP32-A saat sampah terdeteksi. Dipakai bersama oleh MQTT, unggahan gambar, dan riwayat aplikasi.
- **Klasifikasi dan rotasi tong berjalan bersamaan** (lihat bagian Optimasi), memangkas waktu transaksi sekitar 1,5 detik.

## Status mesin dan indikator

Mesin punya empat status, dan LED selalu mencerminkan status itu, bukan ada atau tidaknya kartu.

| Status | LED | Arti | Slot KTP |
| --- | --- | --- | --- |
| IDLE | Hijau menyala | Siap dipakai | Diterima |
| SIBUK | Merah menyala | Sedang melayani satu pengguna | Diabaikan |
| OFFLINE | Kuning berkedip 1 Hz | WiFi atau MQTT putus | Ditolak + nada error |
| GANGGUAN | Merah berkedip 2 Hz | Sampah nyangkut, servo gagal, atau sekat penuh | Ditolak + nada error |

Kalau hanya ada LED merah dan hijau, pakai merah berkedip 1 Hz untuk OFFLINE dan 4 Hz untuk GANGGUAN. Status GANGGUAN hanya hilang lewat tombol reset di mesin atau perintah admin dari aplikasi.

### Pola buzzer

Pakai buzzer pasif agar nadanya bisa dibedakan. Semua pola selesai di bawah 1 detik supaya tidak memperlambat transaksi.

| Kejadian | Pola |
| --- | --- |
| Akun ditemukan | 2 bip naik (1000 Hz, 1500 Hz), masing-masing 100 ms |
| Akun tidak ada | 3 bip turun (600 Hz), masing-masing 150 ms |
| Dapat poin | 1 bip panjang 1500 Hz, 300 ms |
| Residu, tanpa poin | 1 bip rendah 400 Hz, 400 ms |
| Error atau timeout | 2 bip 300 Hz, masing-masing 200 ms |
| Peringatan ambil KTP | 1 bip pendek 800 Hz tiap 3 detik, berhenti setelah kartu diambil |

### Teks LCD 16×2

LCD hanya memuat **16 karakter per baris**. Kalimat seperti "sampah terdeteksi residu, anda tidak mendapatkan point" tidak akan muat dan terpotong. Semua teks di bawah sudah dihitung agar pas, tanpa perlu animasi geser yang memperlambat tampilan.

| Keadaan | Baris 1 | Baris 2 |
| --- | --- | --- |
| Idle | `Masukkan KTP` | `anda` |
| Mengecek akun | `Mengecek akun` | `mohon tunggu...` |
| Akun tidak ada | `KTP tidak` | `terdaftar` |
| Siap menerima | `Masukkan sampah` | `Sisa waktu: 25s` |
| Sedang memproses | `Memproses...` | `mohon tunggu` |
| Tidak ada sampah | `Sampah tidak` | `terdeteksi` |
| Dapat poin | `Organik +12 poin` | `Total: 48 poin` |
| Residu | `Residu, tanpa` | `poin` |
| Ambil kartu | `Transaksi selesai` → dipotong jadi `Selesai.` | `Ambil KTP anda` |
| Waktu habis | `Waktu habis` | `Ambil KTP anda` |
| Sekat penuh | `Tong penuh` | `Hubungi admin` |
| Offline | `Mesin offline` | `Coba lagi nanti` |
| Gangguan | `Mesin gangguan` | `Hubungi admin` |

Nama jenis dipendekkan agar muat: `Organik`, `Anorgnk`, `Residu`. Dengan format `Anorgnk +120 poin` masih tersisa ruang untuk poin tiga digit.

## Alur lengkap

Satu sesi divalidasi sekali di awal, lalu bisa menerima sampah berulang kali selama KTP tetap di slot. Semua logika sesi ada di ESP32-A; ESP32-B hanya jembatan kartu dan MQTT.

&#91;embedded content: state machine ESP32-A · 6 status utama, 2 keadaan khusus\]

Garis tebal adalah perulangan sesi: setelah satu sampah selesai, mesin kembali ke pengecekan sebelum pintu dibuka, bukan ke validasi akun.

### Langkah demi langkah

1. **Boot.** Homing servo (pintu tertutup, platform datar, tong ke sekat Residu), tare load cell, cek PN532 dan laptop AI. Gateway ESP32-B tersambung ke broker melalui WSS/TLS 443 dan memublikasikan heartbeat di `smartbin/{deviceId}/telemetry/status`.
2. **Denyut kesehatan tiap 10 detik.** WiFi atau MQTT putus lebih dari 10 detik → status OFFLINE. Tiap sekat diukur HC-SR04; sekat penuh ditandai dan dilaporkan ke admin.
3. **IDLE.** LED hijau, LCD "Masukkan KTP", pintu tertutup.
4. **KTP masuk.** Mikroswitch slot memicu PN532 membaca UID. ESP32-B menghitung HMAC lalu mengirim `CARD_IN` ke ESP32-A. Aplikasi Android menautkan kartu dengan membaca UID NFC-A yang diekspos oleh kartu, bukan membaca data pribadi e-KTP; ponsel dan firmware harus memakai urutan byte UID yang sama.
5. **Validasi akun.** Publikasikan ke `smartbin/{deviceId}/telemetry/auth` dengan `request_id` dan `uid_hash`; backend membalas melalui `smartbin/{deviceId}/command/auth` dengan ID yang sama. Tunggu paling lama `T_AUTH`.
   - Tidak terdaftar → 3 bip, LCD "KTP tidak terdaftar", kembali IDLE.
   - Tidak ada balasan → 2 bip error, LCD "Server sibuk", kembali IDLE.
   - Valid → 2 bip, simpan `uid_hash` di memori sebagai kunci sesi, LED merah, status SIBUK.
6. **Pengecekan sebelum pintu dibuka.** Semua sekat di bawah ambang penuh, laptop AI membalas `PING`, dan status bukan GANGGUAN. Gagal → LCD menjelaskan, kirim alert, akhiri sesi.
7. **Buka pintu.** Tare load cell lebih dulu, lalu buka pintu, LCD "Masukkan sampah" dengan hitung mundur, mulai timer `T_SAMPAH`.
8. **Deteksi sampah.** Berat harus melewati `W_MIN` dan stabil tiga pembacaan berturut-turut. Timer habis → tutup pintu, LCD "Waktu habis", akhiri sesi.
9. **Tutup pintu dan verifikasi.** Limit switch harus menyatakan tertutup, kalau tidak → GANGGUAN.
10. **Cek ulang berat.** Kalau sekarang di bawah `W_MIN` (sampah ditarik keluar lagi), LCD "Sampah tidak terdeteksi" lalu kembali ke langkah 7.
11. **Buat `transaction_id`** berupa UUID v4 di ESP32-A. Satu id ini dipakai bersama oleh MQTT, unggahan foto, dan riwayat aplikasi.
12. **Baca sensor induktif** untuk menentukan logam atau bukan.
13. **Minta klasifikasi** ke laptop: `CLASSIFY <transaction_id>`. Laptop mengambil 5 frame, melakukan voting, membalas JSON, lalu mengunggah foto ke backend di latar belakang.
14. **Tentukan tujuan.** Logam → Residu. AI tidak menjawab, confidence di bawah `T_CONF`, atau hasil bertentangan dengan sensor → Residu. Selain itu ikuti kelas dari AI.
15. **Putar tong** ke sekat tujuan, lalu verifikasi posisinya. Gagal → GANGGUAN.
16. **Miringkan platform**, tahan `T_TILT`, kembalikan ke datar.
17. **Verifikasi sampah jatuh.** Berat harus kembali di bawah `W_ZERO`. Belum jatuh → goyangkan platform dua kali; masih gagal → GANGGUAN.
18. **Kirim setoran.** Publikasikan ke `smartbin/{deviceId}/telemetry/deposit` dengan `transaction_id`, `uid_hash`, `type`, `item_label`, `weight_g`, `confidence`, dan `timestamp`. Backend menghitung poin dan membalas melalui `smartbin/{deviceId}/command/deposit` dengan `transaction_id`, `points`, `balance`, `status`, dan `duplicate`. Retry maksimal tiga kali harus menggunakan ID dan payload yang sama. Jika tidak ada ACK, jangan tampilkan poin sebagai sudah masuk; tandai “Poin tertunda” dan ingat bahwa antrean RAM hilang saat gateway mati.
19. **Tampilkan hasil.** Buzzer nada poin atau residu, LCD menampilkan jenis, poin, dan total sesi selama `T_TAMPIL`.
20. **Cek KTP.** Masih di slot → kembali ke langkah 6 tanpa validasi ulang. Sudah dicabut → akhiri sesi.
21. **Akhiri sesi.** LCD "Ambil KTP anda" dengan bip tiap 3 detik sampai kartu diambil. Hapus `uid_hash` dari memori, LED hijau, status IDLE.

## Parameter dan ambang

Semua angka di bawah adalah **nilai awal untuk mulai merakit**, bukan hasil ukur. Kolom terakhir menjelaskan cara menetapkan nilai sebenarnya. Simpan semuanya sebagai konstanta di satu berkas `config.h` agar mudah diubah.

| Konstanta | Nilai awal | Dipakai di | Cara menetapkan |
| --- | --- | --- | --- |
| `T_AUTH` | 5 detik | Langkah 5 | Ukur waktu balasan MQTT 20 kali, ambil nilai terburuk lalu kalikan 2 |
| `T_SAMPAH` | 30 detik | Langkah 7 | Uji dengan 10 orang; cukup untuk mengambil sampah dari tas |
| `T_AI` | 3 detik | Langkah 13 | Waktu inferensi 5 frame di laptop + 1 detik cadangan |
| `T_DEPOSIT` | 5 detik | Langkah 18 | Sama seperti `T_AUTH` |
| `T_TILT` | 1,5 detik | Langkah 16 | Waktu sampah paling lambat meluncur saat uji |
| `T_TAMPIL` | 3 detik | Langkah 19 | Cukup untuk membaca dua baris LCD |
| `T_PUTAR` | 2 detik | Langkah 15 | Waktu putar sekat terjauh + 0,5 detik |
| `W_MIN` | 5 gram | Langkah 8, 10 | Berat sampah teringan yang diterima, dikurangi 2 gram |
| `W_ZERO` | 3 gram | Langkah 17 | Simpangan pembacaan load cell saat kosong, dikalikan 3 |
| `W_MAX` | 2000 gram | Langkah 14 | Kapasitas load cell dikurangi margin; di atas ini tolak sebagai Residu |
| `T_CONF` | 0,60 | Langkah 14 | Dari tabel efek T\_CONF di alat uji web; sudah diukur pada 31 sampel |
| `FULL_CM` | 8 cm | Langkah 2, 6 | Jarak HC-SR04 ke permukaan sampah saat sekat dianggap penuh |
| `N_FRAME` | 5 frame | Langkah 13 | Turunkan ke 3 jika laptop lambat |
| `MIN_AGREE` | 0,6 | Langkah 14 | Porsi frame yang harus sepakat |
| `T_HEARTBEAT` | 10 detik | Langkah 2 | Interval publikasi status mesin |

### Sudut servo

Servo standar hanya berputar 180°, jadi tiga sekat harus muat di rentang itu. Kalibrasi tiap nilai dengan sensor posisi, jangan mengandalkan sudut teoretis.

| Servo | Posisi | Sudut awal |
| --- | --- | --- |
| Pintu | Tertutup / terbuka | 0° / 90° |
| Platform | Datar / miring | 0° / 55° |
| Tong | Organik / Anorganik / Residu | 20° / 85° / 150° |

Tong berhenti di Residu saat idle, supaya sampah yang jatuh karena gangguan tidak masuk ke sekat berpoin.

## Protokol

Empat jalur komunikasi, masing-masing dengan satu tugas. Kunci agar semuanya nyambung adalah `transaction_id`: dibuat ESP32-A, dipakai ulang di MQTT, unggahan foto, dan riwayat aplikasi.

### Topik MQTT (WSS/TLS port 443)

ID gateway menggunakan pola pada [`mqtt-smartbin.md`](./mqtt-smartbin.md). Backend menghubungkan setiap `deviceId` ke kode mesin MySQL melalui `MQTT_DEVICE_MACHINE_MAP`; konfigurasi contoh `esp1=bin-01,esp2=bin-02`.

| Topik | Arah | Isi |
| --- | --- | --- |
| `smartbin/{deviceId}/telemetry/auth` | Gateway → backend | `request_id`, `uid_hash`, `timestamp` |
| `smartbin/{deviceId}/command/auth` | Backend → gateway | `request_id`, `found`, `name`, `balance` |
| `smartbin/{deviceId}/telemetry/deposit` | Gateway → backend | `transaction_id`, `uid_hash`, `type`, `item_label`, `weight_g`, `confidence`, `timestamp` |
| `smartbin/{deviceId}/command/deposit` | Backend → gateway | `transaction_id`, `points`, `balance`, `status`, `duplicate` |
| `smartbin/{deviceId}/telemetry/status` | Gateway → backend | `state`, `compartments`, `sekat_cm`, `ai_online`, `uptime_s`, `timestamp` |
| `smartbin/{deviceId}/command/control` | Backend → gateway | `command_id`, `command`, `timestamp` |

Gunakan QoS 1 untuk transaksi, status, dan command. Gateway berlangganan `command/auth`, `command/deposit`, dan `command/control`. Balasan dicocokkan dengan `request_id` atau `transaction_id`. Backend mengabaikan duplikat setoran berdasarkan `transaction_id` dan mengembalikan hasil transaksi semula. LWT pada topic status harus membawa `state: OFFLINE`. PUBACK MQTT bukan bukti command fisik sudah selesai.

```json
{
  "transaction_id": "8f14e45f-ea2b-4c1a-9c3d-71b0f2a65e40",
  "uid_hash": "a3f1...9c",
  "type": "ORGANIK",
  "item_label": "Botol PET",
  "weight_g": 128,
  "confidence": 0.91,
  "timestamp": "2026-10-31T09:14:22+07:00"
}
```

`uid_hash` adalah HMAC-SHA256 hex atas UID yang di-trim dan di-uppercase menggunakan `CARD_HMAC_SECRET` yang sama dengan backend. UID mentah tidak boleh dikirim lewat MQTT. `type` hanya `ORGANIK`, `ANORGANIK`, atau `RESIDU`; setoran residu mendapat nol poin. Status mesin yang diterima: `IDLE`, `SIBUK`, `OFFLINE`, `GANGGUAN`, serta `PENUH` bila ada sekat penuh.

Pada aplikasi Android, hasil pemindaian NFC dinormalisasi sebagai byte UID berurutan dalam hex huruf besar tanpa pemisah, lalu dikirim melalui HTTPS ke endpoint tautkan kartu. Firmware PN532 wajib mengubah byte UID ke representasi teks yang sama sebelum menghitung HMAC. Pemindaian UID standar bukan pembacaan NIK/data chip atau autentikasi kriptografis; uji kartu e-KTP dan model ponsel sesungguhnya karena sebagian chip/perangkat tidak mengekspos UID dengan cara yang sama.

### Serial laptop ↔ ESP32-A (USB, 115200)

Satu baris perintah, satu baris balasan JSON. Sudah berjalan di `ai_service.py`.

| Perintah | Balasan |
| --- | --- |
| `PING` | `{"ev":"pong","cam":true,"conf":0.6}` |
| `CLASSIFY <transaction_id>` | `{"ev":"result","kelas":"organik","confidence":0.93,"reason":"ok"}` |
| `CONF 0.70` | `{"ev":"conf","value":0.7}` |

Nilai `kelas` adalah keputusan akhir AI: `organik`, `anorganik`, atau `residu`. Kalau `reason` bukan `ok`, kelasnya otomatis `residu`.

### UART ESP32-A ↔ ESP32-B (115200)

Keduanya 3,3 V, jadi cukup tiga kabel: TX, RX, dan GND bersama.

| Pesan | Arah | Fungsi |
| --- | --- | --- |
| `CARD_IN <uid_hash>` | B → A | Kartu masuk slot |
| `CARD_OUT` | B → A | Kartu dicabut |
| `MQTT_PUB <topik> <json>` | A → B | Minta B mempublikasikan |
| `MQTT_MSG <topik> <json>` | B → A | Pesan masuk dari broker |
| `NET <online\|offline>` | B → A | Status koneksi, dikirim saat berubah |

### Unggah foto (laptop → backend, HTTPS)

ESP32 tidak sanggup mengunggah gambar, jadi laptop yang melakukannya langsung setelah klasifikasi, di thread terpisah agar tidak menahan balasan serial.

```
POST /api/v1/captures
X-Machine-Api-Key: <MACHINE_API_KEY>
Idempotency-Key: <transaction_id>
multipart/form-data: transaction_id, bin_id, class, confidence, photo
```

Backend menyimpan JPEG/PNG/WebP maksimal 5 MiB di `CAPTURE_STORAGE_DIR` (default pengembangan `./data/captures`; Docker memakai volume persisten `/var/lib/smartbin/captures`). Nama berkas diturunkan dari UUID v4. File yang sama dapat diunggah ulang secara idempoten. Foto boleh tiba sebelum setoran: berkas yatim akan tersedia pada riwayat setelah `transaction_id` terkait masuk. API memberi `photoUrl` dan melayani foto lewat endpoint JWT `GET /api/v1/captures/{transaction_id}`; hanya pemilik setoran dan admin yang dapat membacanya. Ini penyimpanan lokal persisten, bukan CDN; backup volume diperlukan dan retensi foto perlu ditetapkan sebelum produksi. Laptop mencoba unggah ulang tiga kali lalu menyimpan antrean lokal untuk dicoba kembali.

## Penanganan error

Aturannya: kegagalan **jaringan** membatalkan sesi tetapi mesin tetap sehat, sedangkan kegagalan **mekanik** menghentikan mesin sampai ada orang yang memeriksa. Gangguan tidak pernah hilang sendiri, karena sampah yang nyangkut tidak akan lepas dengan menunggu.

| Kegagalan | Dideteksi dari | Tindakan | Cara pulih |
| --- | --- | --- | --- |
| WiFi atau MQTT putus | Tidak ada denyut > 10 detik atau LWT | Status OFFLINE, LED kuning berkedip, tolak KTP | Otomatis saat koneksi kembali |
| Server tidak membalas validasi | `T_AUTH` habis | 2 bip error, LCD "Server sibuk", akhiri sesi | Pengguna mencoba lagi |
| Server tidak membalas setoran | `T_DEPOSIT` habis, 3 kali coba | LCD "Poin tertunda", sesi tetap lanjut, simpan di memori | Kirim ulang saat koneksi kembali; hilang jika mesin mati |
| Laptop AI mati | `PING` tidak dijawab | Tolak sesi baru di langkah 6; sampah yang sedang diproses → Residu | Otomatis saat laptop hidup |
| Kamera tidak memberi gambar | `cam:false` pada balasan `PING` | Sama seperti laptop mati | Periksa DroidCam |
| Pintu gagal menutup | Limit switch tidak aktif setelah 2 detik | Coba 2 kali, lalu GANGGUAN | Reset admin |
| Tong meleset dari sekat | Sensor posisi tidak cocok dalam `T_PUTAR` | Coba 2 kali, lalu GANGGUAN | Reset admin |
| Sampah tidak jatuh | Berat tetap di atas `W_ZERO` | Goyang platform 2 kali, lalu GANGGUAN | Buka mesin, ambil sampah, reset |
| Berat di atas `W_MAX` | Pembacaan load cell | Tujuan Residu, tanpa poin, catat alasan | Otomatis |
| Load cell tidak stabil | 10 pembacaan tidak konvergen | Tunggu 2 detik, baca ulang; gagal → GANGGUAN | Periksa dudukan dan kabel |
| Sekat tujuan penuh | HC-SR04 < `FULL_CM` | Tolak sesi, LCD "Tong penuh", alert admin | Kosongkan tong |
| PN532 tidak membaca | 3 kali gagal baca saat mikroswitch aktif | LCD "Kartu tidak terbaca", kembali IDLE | Pengguna memasang ulang kartu |

### Yang terjadi pada sampah saat error

Ini bagian yang sering terlupakan. Kalau gangguan terjadi **setelah** sampah masuk tetapi **sebelum** dibuang, sampah ada di platform dan tidak tercatat di mana pun.

- Tujuan sudah ditentukan tetapi tong gagal berputar → sampah tetap di platform, status GANGGUAN, dan `deposit` tidak dikirim. Pengguna tidak mendapat poin.
- Setelah reset admin, mesin menjalankan homing dan memiringkan platform ke sekat Residu untuk mengosongkannya sebelum menerima pengguna berikutnya.
- Catat kejadian ini ke topik `status` agar admin tahu ada sampah yang perlu diperiksa.

### Reset gangguan

Dua cara: tombol fisik di dalam mesin (ditahan 3 detik), atau perintah `reset_gangguan` dari aplikasi admin. Keduanya memicu urutan yang sama: homing semua servo, tare ulang load cell, kosongkan platform ke Residu, lalu kembali ke IDLE.

## Optimasi

Setelah pengguna memasukkan sampah, mesin butuh sekitar **7 detik** kalau semua langkah dijalankan berurutan. Dengan tiga langkah dijalankan bersamaan, angkanya turun menjadi sekitar **4,5 detik**. Angka ini perkiraan, dan baru bisa dipastikan setelah mekaniknya jadi.

| Tahap | Berurutan | Setelah dioptimalkan |
| --- | --- | --- |
| Tutup pintu + verifikasi | 1,0 dtk | 1,0 dtk |
| Baca berat (stabil) | 1,0 dtk | bersamaan dengan AI |
| Baca sensor induktif | 0,1 dtk | bersamaan dengan AI |
| Klasifikasi AI (5 frame) | 1,2 dtk | 1,2 dtk |
| Putar tong | 1,5 dtk | bersamaan dengan kirim MQTT |
| Miringkan + verifikasi jatuh | 2,0 dtk | 2,0 dtk |
| Kirim setoran, tunggu poin | 0,5 dtk | bersamaan dengan putar tong |
| **Total** | **\~7,3 dtk** | **\~4,5 dtk** |

### Tiga langkah yang dijalankan bersamaan

1. **Berat dan sensor induktif dibaca sambil menunggu AI.** Begitu perintah `CLASSIFY` dikirim, ESP32-A tidak diam menunggu, tetapi membaca load cell sampai stabil dan memeriksa sensor induktif. Saat balasan AI tiba, semua data sudah siap.
2. **Setoran dikirim sambil tong berputar.** Tujuan sudah diketahui sebelum tong bergerak, jadi `deposit/req` dipublikasikan lebih dulu, lalu servo diperintahkan berputar. Balasan poin biasanya sudah tiba saat tong selesai berputar.
3. **Foto diunggah di latar belakang.** Laptop membalas serial dulu, baru mengunggah foto di thread terpisah. ESP32-A tidak pernah menunggu unggahan.

Satu hal yang **tidak** boleh dijalankan bersamaan: memiringkan platform sebelum posisi tong diverifikasi. Kalau tong meleset, sampah jatuh ke sekat yang salah atau ke dalam mesin.

### Optimasi lain

- **Tare saat pintu dibuka, bukan sebelum menimbang.** Tare butuh waktu dan harus dalam keadaan diam. Dilakukan tepat sebelum pintu terbuka, waktunya tersembunyi di balik gerakan servo.
- **Tong tidak kembali ke posisi awal** setelah membuang. Biarkan di sekat terakhir; rata-rata jarak putar berikutnya jadi lebih pendek.
- **Validasi akun hanya sekali per sesi.** Sampah kedua dan seterusnya langsung ke langkah 6, memangkas sekitar 1 detik per sampah.
- **Laptop menjaga model tetap hangat.** Model dimuat sekali saat service menyala, bukan tiap klasifikasi.
- **Turunkan `N_FRAME` ke 3** kalau laptop lambat. Dari pengujian sebelumnya, perbedaan akurasinya kecil untuk benda yang diam.
- **Hindari `delay()` di ESP32-A.** Pakai pencatat waktu non-blocking (`millis()`), supaya pembacaan kartu dan denyut MQTT tetap jalan selama servo bergerak.

## Yang perlu diuji dan diputuskan

Empat hal di bawah bisa membatalkan sebagian desain ini, jadi uji dulu sebelum merakit penuh.

- [ ] **Torsi servo pemutar tong.** Timbang tong berisi sampah penuh, lalu uji apakah servo mampu memutarnya di atas bearing. Kalau tidak kuat, ganti ke stepper NEMA17 dengan gearbox, dan seluruh bagian "putar tong" perlu disesuaikan.
- [ ] **HC-SR04 di dalam sekat.** Sensor ini punya zona buta sekitar 2 cm dan sudut pancar lebar, jadi di ruang sempit pantulannya bisa mengenai dinding sekat. Uji dengan sekat kosong, setengah, dan penuh. Kalau meleset, ganti VL53L0X (perlu pengaturan alamat I2C berbeda untuk tiap sensor).
- [ ] **Load cell dengan botol kosong.** Timbang botol PET 600 ml kosong 20 kali. Kalau simpangannya lebih dari 3 gram, perbaiki dudukannya dulu sebelum menyetel `W_MIN`.
- [ ] **Sensor induktif menembus platform.** Pasang di bawah platform akrilik 3 mm, uji dengan kaleng aluminium dan tutup botol besi. Aluminium terdeteksi dari jarak lebih pendek daripada besi.

Empat keputusan yang belum diambil:

- [ ] **Poin tertunda saat server tidak membalas.** Sekarang poin disimpan di memori dan hilang kalau mesin mati. Alternatifnya menolak transaksi sejak awal, atau memasang kembali SD card khusus untuk kasus ini.
- [ ] **Siapa yang menandai sekat penuh.** Mesin menolak sesi saat satu sekat penuh, atau tetap menerima dan hanya menolak sampah yang menuju sekat itu?
- [ ] **Berapa lama foto disimpan di CDN.** Berpengaruh pada biaya penyimpanan dan kebijakan privasi di PRD.
- [ ] **Nilai poin per kg** untuk organik dan anorganik, serta pembulatannya.

### Dampak ke dokumen lain

Flowchart `flowchart_smartbin_standar.drawio` dan activity diagram `activity_diagram_smartbin_edge_transport_cloud.drawio` masih memakai alur lama (tiga tong terpisah, antrean SD card, poin dihitung di mesin). Keduanya perlu diperbarui agar cocok dengan spesifikasi ini sebelum dipakai di laporan.

PRD SmartBIN juga perlu dua penyesuaian kecil: mode offline di aplikasi tidak lagi relevan untuk mesin, dan riwayat setoran sekarang menampilkan foto sampah.
