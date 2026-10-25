# PRD – SmartBIN (Aplikasi Mobile Flutter)

Oct 24, 2026 · @Ramadhan

## Ringkasan Produk

SmartBIN adalah aplikasi mobile Flutter tempat mahasiswa melihat poin dan riwayat setoran sampah dari mesin SmartBIN, menautkan KTM ke akunnya, dan (mulai Rilis 2) menukar poin dengan reward.

Mesin SmartBIN memilah sampah organik dan anorganik, menghitung poin dari berat, lalu mengirim rekaman ke cloud lewat MQTT. Mesin hanya punya LCD dan KTM sebagai penanda akun, jadi aplikasi ini adalah satu-satunya antarmuka pengguna.

| Item | Isi |
| --- | --- |
| Nama produk | SmartBIN |
| Platform | Android (wajib); iOS (opsional, Rilis 2) |
| Framework | Flutter (Dart) |
| Pengguna utama | Mahasiswa pemegang KTM RFID 13,56 MHz |
| Pengguna sekunder | Admin / pengelola mesin |
| Posisi dalam sistem | Lapisan Presentation di Cloud; terhubung ke backend lewat HTTPS/REST, tidak langsung ke mesin maupun broker MQTT |
| Versi dokumen | 1.0 (draf awal untuk tim) |

Nilai utama untuk pengguna:

- Bukti bahwa setiap setoran tercatat: jenis, berat, poin, waktu, dan mesin.
- Penautan KTM ke akun yang cepat, tanpa input manual yang rawan salah.
- Kejelasan status: poin yang masih menunggu sinkronisasi atau belum bertaut tidak terlihat "hilang".

## Latar Belakang dan Masalah

Mesin SmartBIN tidak bisa menampilkan saldo atau riwayat di LCD-nya, sehingga tanpa aplikasi pengguna tidak punya bukti bahwa setorannya tercatat.

Masalah yang harus diselesaikan aplikasi:

1. **Tidak ada bukti setoran.** LCD hanya menampilkan ringkasan sesi yang sedang berjalan; saldo dan riwayat tidak tersedia di mesin.
2. **KTM hanya berupa UID.** Mesin mengenali kartu, bukan orangnya. Kartu harus ditautkan ke akun agar poin masuk ke saldo yang benar.
3. **Data bisa terlambat.** Mesin tetap bekerja saat offline dan mengirim rekaman belakangan. Pengguna perlu tahu bahwa poin "menunggu sinkronisasi", bukan hilang.
4. **Poin tanpa penggunaan.** Poin baru bermakna jika pengguna bisa melihat nilainya dan menukarnya dengan reward.
5. **Pengelola tidak tahu kondisi mesin.** Tong penuh, gangguan, dan laptop AI yang offline harus sampai ke admin tanpa harus mengecek mesin langsung.

Batasan dari sisi mesin yang memengaruhi desain aplikasi:

- Sampah yang ditolak (masuk tong Residu) tidak diberi poin dan tidak dikirim ke cloud, jadi tidak muncul di riwayat.
- Poin dihitung di mesin dari nilai poin yang di-cache, dan backend menyimpan hasilnya. Aplikasi tidak menghitung poin sendiri.
- Data tiba lewat MQTT secara asinkron; aplikasi tidak real-time dan memakai push serta pull-to-refresh.
- Waktu setoran berasal dari RTC mesin (modul DS3231), bukan jam ponsel.

## Tujuan dan Metrik Keberhasilan

Aplikasi berhasil jika 30 mahasiswa uji bisa memulai dari nol, melihat setoran mereka muncul tepat satu kali dan cepat, dan tetap memakainya selama empat minggu pilot.

| Tujuan | Metrik | Target | Cara ukur |
| --- | --- | --- | --- |
| Onboarding mudah | Waktu dari buka aplikasi sampai KTM tertaut dan saldo terlihat | Median ≤ 3 menit; ≥ 90% selesai tanpa bantuan | Uji kegunaan dengan 10 mahasiswa |
| Data akurat | Setoran di mesin vs setoran di aplikasi | 100% muncul tepat 1×; 0 duplikat; 0 hilang, termasuk saat mesin offline | Uji 100 setoran, 30 di antaranya saat WiFi dimatikan |
| Data cepat | Selisih waktu mesin online sampai setoran tampil | p95 ≤ 15 detik | Log timestamp mesin, backend, aplikasi |
| Aplikasi stabil | Crash-free sessions | ≥ 99% | Crash reporting selama pilot |
| Pengguna kembali | Pengguna aktif mingguan | ≥ 70% dari 30 pengguna uji, 4 minggu | Analytics aplikasi |

Bukan tujuan produk ini: mengontrol mesin dari jarak jauh (kecuali reset status oleh admin di Rilis 2), pembayaran uang, atau klasifikasi sampah di dalam aplikasi.

## Pengguna dan Persona

Ada dua pengguna: mahasiswa yang menyetor sampah (pengguna utama) dan admin yang menjaga mesin tetap berjalan.

|  | Rina – Mahasiswa pengguna | Dimas – Admin / pengelola mesin |
| --- | --- | --- |
| Profil | 19 tahun, semester 3, ponsel Android kelas menengah, ke kampus tiap hari | Mahasiswa pengelola atau petugas kebersihan yang bertanggung jawab atas mesin |
| Tujuan | Mengumpulkan poin, memastikan setoran tercatat, menukar poin | Tahu kapan tong penuh atau mesin bermasalah, mengatur nilai poin |
| Frustrasi | Tidak tahu apakah setoran masuk; takut poin hilang saat WiFi mesin mati; KTM hilang | Harus mengecek mesin langsung; tidak ada peringatan dini |
| Kebutuhan utama | Saldo dan riwayat yang jelas, status "menunggu sinkronisasi", tautan KTM yang mudah | Notifikasi tong penuh / gangguan, ringkasan status semua mesin |
| Perangkat | Android 8.0+ (iOS opsional) | Android 8.0+ |

Hak akses per peran:

| Peran | Dapat mengakses |
| --- | --- |
| Tamu (belum login) | Layar login, registrasi, onboarding, panduan memilah sampah |
| Pengguna | Data akun, KTM, saldo, riwayat, mesin, reward milik sendiri |
| Admin | Semua yang dimiliki pengguna, ditambah status semua mesin, nilai poin, dan reset status mesin (Rilis 2) |

## Ruang Lingkup dan Rilis

Rilis 1 (MVP) cukup untuk demo akhir semester: pengguna bisa mendaftar, menautkan KTM, dan melihat saldo serta riwayat. Reward, modul admin, dan iOS menyusul di Rilis 2.

| Area | Rilis 1 (MVP) | Rilis 2 | Di luar cakupan |
| --- | --- | --- | --- |
| Akun | Registrasi, login, logout, ubah password | Reset password via email, verifikasi email kampus | Login sosial (Google, Apple) |
| KTM | Tautkan via NFC ponsel Android; status; lepas tautan; satu KTM satu akun | Tautkan via mode pairing di mesin (juga untuk iOS) | Menulis data ke KTM |
| Poin dan riwayat | Saldo, poin tertahan, ringkasan kontribusi, daftar dan detail setoran, cache offline | Filter lanjutan, ekspor riwayat | Menghitung poin di aplikasi |
| Notifikasi | Push saat setoran tercatat dan KTM tertaut; daftar notifikasi | Pengaturan notifikasi per jenis | Notifikasi SMS atau WhatsApp |
| Mesin | Daftar mesin dan status dasar (Siap / Penuh / Gangguan / Offline) | Detail tong, arah ke lokasi mesin | Kontrol mesin jarak jauh (selain reset admin) |
| Reward | – | Katalog, penukaran, voucher, riwayat penukaran; leaderboard (opsional) | Pembayaran uang, integrasi e-wallet |
| Admin | – | Status semua mesin, ubah nilai poin, reset status GANGGUAN | Dashboard web terpisah |
| Platform | Android 8.0 (API 26) ke atas | iOS 14 ke atas (jika perangkat uji dan akun developer tersedia) | Tablet, web, desktop |

## User Journey dan Alur Utama

Pengguna baru mencapai saldo dalam empat langkah: buka aplikasi, daftar, tautkan KTM, lihat Beranda. Menunda penautan KTM tidak membuat poin hilang.

&#91;embedded content: alur pengguna baru dan setoran · 9 langkah, 1 keputusan\]

Baris atas dan tengah adalah alur pengguna baru; KTM yang belum tertaut tidak memblokir akses ke aplikasi. Baris bawah adalah alur setiap setoran: dari mesin ke push, lalu ke detail setoran.

Alur penting lainnya:

1. **Menyetor di mesin.** Tempel KTM, masukkan sampah, LCD menampilkan poin sesi, lalu push "+poin tercatat" tiba di ponsel.
2. **Mesin sedang offline.** Mesin menyimpan setoran dan mengirimnya saat online. Saldo di aplikasi baru berubah setelah itu; sebelumnya pengguna melihat saldo lama dengan keterangan waktu pembaruan.
3. **KTM hilang.** Profil, Lepas KTM (dengan password), lalu tautkan KTM baru; saldo tetap.
4. **Menukar reward (Rilis 2).** Katalog reward, pilih, konfirmasi, lalu voucher berupa kode dan QR.

## Kebutuhan Fungsional

Ada 44 kebutuhan dalam 9 modul: 28 untuk Rilis 1 (R1) dan 16 untuk Rilis 2 (R2). Prioritas memakai Must (wajib untuk demo), Should (sangat dianjurkan), dan Could (jika waktu tersisa).

### Akun (AUTH)

| ID | Kebutuhan | Prioritas | Rilis | Kriteria penerimaan |
| --- | --- | --- | --- | --- |
| FR-AUTH-01 | Pengguna mendaftar dengan NIM, nama, email kampus, dan password | Must | R1 | NIM unik; password ≥ 8 karakter berisi huruf dan angka; pesan error spesifik per kolom; setelah sukses langsung ke layar Tautkan KTM |
| FR-AUTH-02 | Pengguna login dengan NIM atau email dan password | Must | R1 | Login ≤ 2 detik di 4G; token tersimpan di secure storage; 5 kali gagal berturut-turut mengunci login 5 menit (diterapkan backend) |
| FR-AUTH-03 | Sesi bertahan setelah aplikasi ditutup | Must | R1 | Access token diperbarui otomatis lewat refresh token; jika refresh gagal, kembali ke login tanpa crash |
| FR-AUTH-04 | Pengguna logout | Must | R1 | Token dihapus dari perangkat dan dicabut di server; cache data pengguna dibersihkan |
| FR-AUTH-05 | Pengguna mengubah password | Should | R1 | Wajib memasukkan password lama; sesi di perangkat lain dicabut |
| FR-AUTH-06 | Reset password lewat email | Should | R2 | Tautan reset berlaku 30 menit dan hanya sekali pakai |
| FR-AUTH-07 | Verifikasi email kampus | Could | R2 | Akun belum terverifikasi tetap bisa melihat data, tetapi tidak bisa menukar reward |

### Penautan KTM (CARD)

| ID | Kebutuhan | Prioritas | Rilis | Kriteria penerimaan |
| --- | --- | --- | --- | --- |
| FR-CARD-01 | Tautkan KTM dengan menempelkan kartu ke ponsel (NFC, Android) | Must | R1 | UID dibaca dan dikirim sekali lewat HTTPS, tidak disimpan di ponsel; sukses ≤ 10 detik setelah tap; jika NFC mati, tampil tombol menuju pengaturan NFC |
| FR-CARD-02 | Poin tertahan otomatis masuk saldo setelah KTM tertaut | Must | R1 | Layar sukses menampilkan "+X poin dari Y setoran dimasukkan"; saldo di beranda ikut berubah tanpa muat ulang manual |
| FR-CARD-03 | Satu KTM hanya untuk satu akun, satu akun hanya satu KTM | Must | R1 | Percobaan duplikat ditolak dengan pesan "KTM sudah tertaut ke akun lain" |
| FR-CARD-04 | Lihat status KTM | Must | R1 | Tampil "Tertaut" beserta tanggal, atau "Belum tertaut" dengan tombol Tautkan |
| FR-CARD-05 | Lepas tautan KTM (kartu hilang atau diganti) | Should | R1 | Wajib password; setoran dengan KTM lama tidak lagi masuk ke akun ini; saldo tidak berubah |
| FR-CARD-06 | Tautkan lewat mode pairing di mesin (untuk iOS dan ponsel tanpa NFC) | Should | R2 | Token pairing berlaku 2 menit; KTM yang di-tap di mesin pada rentang itu tertaut ke akun |

### Beranda (HOME)

| ID | Kebutuhan | Prioritas | Rilis | Kriteria penerimaan |
| --- | --- | --- | --- | --- |
| FR-HOME-01 | Tampilkan saldo poin dan poin tertahan | Must | R1 | Angka sama dengan respons API; poin tertahan hanya tampil bila > 0, disertai penjelasan singkat |
| FR-HOME-02 | Tampilkan ringkasan bulan ini: total berat organik dan anorganik (kg), jumlah setoran | Must | R1 | Berat dalam kg, 2 desimal; konsisten dengan riwayat |
| FR-HOME-03 | Tampilkan 3 setoran terakhir | Must | R1 | Ketuk membuka detail setoran |
| FR-HOME-04 | Pull-to-refresh dan keterangan "diperbarui HH:mm" | Must | R1 | Refresh ≤ 2 detik di 4G; bila gagal, tampil data cache berlabel "data lama" |
| FR-HOME-05 | Banner ajakan menautkan KTM bila belum tertaut | Must | R1 | Banner hilang setelah KTM tertaut |

### Riwayat setoran (HIST)

| ID | Kebutuhan | Prioritas | Rilis | Kriteria penerimaan |
| --- | --- | --- | --- | --- |
| FR-HIST-01 | Daftar setoran terbaru dulu: jenis, berat, poin, waktu, nama mesin | Must | R1 | Pagination cursor 20 item per halaman; sampah ditolak (Residu) tidak tampil |
| FR-HIST-02 | Filter jenis (Semua, Organik, Anorganik) dan rentang tanggal | Should | R1 | Filter diterapkan di server; chip filter aktif terlihat |
| FR-HIST-03 | Detail setoran | Should | R1 | Menampilkan ID transaksi, mesin, waktu mesin, berat, nilai poin per kg, dan rumus poin |
| FR-HIST-04 | Cache 50 riwayat terakhir untuk dilihat offline | Should | R1 | Tanpa internet, daftar tetap tampil dengan banner "Mode offline" |
| FR-HIST-05 | Penanda setoran "menunggu tautan KTM" untuk poin tertahan | Must | R1 | Item tertahan berlabel jelas dan berubah normal setelah KTM tertaut |

### Notifikasi (NOTIF)

| ID | Kebutuhan | Prioritas | Rilis | Kriteria penerimaan |
| --- | --- | --- | --- | --- |
| FR-NOTIF-01 | Push saat setoran tercatat | Should | R1 | Isi memuat jenis, berat, poin; tiba ≤ 15 detik setelah backend menyimpan setoran |
| FR-NOTIF-02 | Push saat KTM berhasil ditautkan atau dilepas | Should | R1 | Satu notifikasi per kejadian |
| FR-NOTIF-03 | Daftar notifikasi dalam aplikasi dan tandai dibaca | Should | R1 | Badge jumlah belum dibaca pada ikon notifikasi |
| FR-NOTIF-04 | Pengaturan notifikasi per jenis | Could | R2 | Preferensi tersimpan di server |
| FR-NOTIF-05 | Push untuk admin: tong penuh, gangguan, laptop AI offline | Should | R2 | Hanya peran admin; satu notifikasi per kejadian, tanpa spam |

### Mesin (MACH)

| ID | Kebutuhan | Prioritas | Rilis | Kriteria penerimaan |
| --- | --- | --- | --- | --- |
| FR-MACH-01 | Daftar mesin: nama, lokasi, status | Should | R1 | Status: Siap, Penuh, Gangguan, Offline; Offline bila heartbeat terakhir lebih lama dari 3 kali interval |
| FR-MACH-02 | Detail mesin: status tiap tong dan waktu terakhir terlihat | Could | R2 | Tong tampil Tersedia atau Penuh |
| FR-MACH-03 | Tombol "Petunjuk arah" membuka aplikasi peta | Could | R2 | Koordinat mesin dikirim ke aplikasi peta bawaan |

### Reward (RWD)

| ID | Kebutuhan | Prioritas | Rilis | Kriteria penerimaan |
| --- | --- | --- | --- | --- |
| FR-RWD-01 | Katalog reward: nama, gambar, harga poin, stok | Should | R2 | Stok 0 tampil "Habis" dan tidak bisa ditukar |
| FR-RWD-02 | Tukar reward | Should | R2 | Ada konfirmasi; saldo dikurangi atomik di server; permintaan memakai Idempotency-Key sehingga ketukan ganda tidak memotong dua kali; hanya bisa saat online |
| FR-RWD-03 | Voucher hasil penukaran (kode dan QR) serta riwayat penukaran | Should | R2 | Status: Menunggu diambil, Selesai, Kedaluwarsa |
| FR-RWD-04 | Leaderboard mingguan | Could | R2 | Nama tampil sebagai inisial atau nama samaran; pengguna bisa memilih keluar |

### Profil dan informasi (PROF)

| ID | Kebutuhan | Prioritas | Rilis | Kriteria penerimaan |
| --- | --- | --- | --- | --- |
| FR-PROF-01 | Lihat dan ubah nama | Must | R1 | Perubahan tersimpan di server dan tampil di beranda |
| FR-PROF-02 | Halaman "Nilai poin": poin per kg organik dan anorganik saat ini | Should | R1 | Nilai diambil dari API, tidak ditulis tetap di aplikasi |
| FR-PROF-03 | Panduan memilah sampah (contoh organik, anorganik, residu) | Should | R1 | Konten statis, tersedia offline |
| FR-PROF-04 | Tema terang, gelap, atau ikut sistem | Could | R1 | Pilihan tersimpan di perangkat |
| FR-PROF-05 | Hapus akun dan data pribadi | Should | R2 | Wajib password; riwayat setoran dianonimkan, bukan dihapus, agar statistik tetap utuh |

### Admin (ADM)

| ID | Kebutuhan | Prioritas | Rilis | Kriteria penerimaan |
| --- | --- | --- | --- | --- |
| FR-ADM-01 | Dashboard status semua mesin | Should | R2 | Menampilkan status, waktu terakhir terlihat, dan alert aktif |
| FR-ADM-02 | Ubah nilai poin per jenis | Should | R2 | Dipublikasikan sebagai pesan config (retained); ada konfirmasi dan catatan siapa yang mengubah |
| FR-ADM-03 | Reset status GANGGUAN pada mesin | Could | R2 | Memerlukan perintah ke mesin (lihat Dependensi pada bagian Integrasi) |
| FR-ADM-04 | Lihat transaksi semua pengguna | Could | R2 | Dengan filter mesin dan tanggal |

## Spesifikasi Layar

Aplikasi memiliki 16 layar: 11 untuk Rilis 1 dan 5 untuk Rilis 2. Navigasi utama berupa bottom navigation dengan 4 tab di Rilis 1 (Beranda, Riwayat, Mesin, Profil); tab Reward ditambahkan di Rilis 2.

| ID | Layar | Isi utama | Aksi pengguna | State khusus | Rilis |
| --- | --- | --- | --- | --- | --- |
| S01 | Onboarding | 3 slide: apa itu SmartBIN, cara menyetor (tempel KTM, masukkan sampah), cara poin dihitung | Lewati, Lanjut, Mulai | Tampil sekali saat pertama dibuka | R1 |
| S02 | Login | Kolom NIM atau email dan password; tautan Daftar dan Lupa password | Masuk | Loading di tombol; kredensial salah; akun terkunci dengan hitung mundur | R1 |
| S03 | Registrasi | NIM, nama, email kampus, password, persetujuan kebijakan privasi | Daftar | Error per kolom; NIM sudah dipakai | R1 |
| S04 | Tautkan KTM | Instruksi bergambar, animasi menempelkan KTM ke belakang ponsel, status pembacaan | Mulai pindai, Lewati sementara, Buka pengaturan NFC | NFC tidak ada atau mati; kartu tidak terbaca; KTM sudah tertaut ke akun lain; sukses dengan ringkasan poin tertahan | R1 |
| S05 | Beranda | Sapaan, kartu saldo (dan poin tertahan), ringkasan bulan ini, 3 setoran terakhir, banner tautkan KTM | Pull-to-refresh, ketuk setoran, Tautkan KTM | Skeleton saat memuat; kosong ("Belum ada setoran. Setor sampah di mesin SmartBIN terdekat"); offline (data lama) | R1 |
| S06 | Riwayat | Daftar setoran dikelompokkan per hari, chip filter jenis dan tanggal | Filter, scroll, ketuk item | Kosong; error dengan Coba lagi; cache offline; label "menunggu tautan KTM" | R1 |
| S07 | Detail setoran | ID transaksi, jenis, berat, waktu mesin, nama mesin, rumus poin, status | Salin ID transaksi | Setoran tertahan menampilkan tombol Tautkan KTM | R1 |
| S08 | Daftar mesin | Kartu per mesin: nama, lokasi, badge status | Pull-to-refresh | Kosong; Offline | R1 |
| S09 | Detail mesin | Status tiap tong, waktu terakhir terlihat | Petunjuk arah (buka peta) | – | R2 |
| S10 | Notifikasi | Daftar notifikasi dengan penanda belum dibaca | Tandai dibaca, ketuk (deep link) | Kosong | R1 |
| S11 | Profil | Nama, NIM, email, status KTM; menu ubah nama, ubah password, tema, logout | Ubah, Lepas KTM, Logout | Dialog konfirmasi untuk Lepas KTM dan Logout | R1 |
| S12 | Nilai poin dan panduan | Poin per kg organik dan anorganik; contoh sampah organik, anorganik, dan residu | – | Gagal memuat nilai: pakai nilai terakhir yang tersimpan | R1 |
| S13 | Katalog reward | Grid reward: gambar, nama, harga poin, stok | Ketuk reward | Stok habis; saldo kurang | R2 |
| S14 | Detail dan tukar reward | Deskripsi, syarat, harga poin, saldo setelah penukaran | Tukar (dengan konfirmasi) | Offline: tombol Tukar nonaktif; gagal: saldo tidak berubah | R2 |
| S15 | Voucher dan riwayat penukaran | Kode dan QR voucher, status, tanggal kedaluwarsa | Tampilkan QR | Kosong; kedaluwarsa | R2 |
| S16 | Admin | Dashboard status mesin, pengaturan nilai poin, reset status mesin | Ubah nilai poin, Reset | Hanya tampil untuk peran admin | R2 |

Aturan umum semua layar:

- **Loading** memakai skeleton, bukan spinner layar penuh.
- **Error** menampilkan pesan singkat dan tombol Coba lagi; tidak ada pesan teknis mentah.
- **Offline** menampilkan banner di bagian atas dan data cache dengan label "data lama".
- **Sesi habis** mengembalikan pengguna ke Login dengan pesan penjelasan.
- **Push** membuka layar yang relevan (setoran baru membuka S07).
- **Format:** bahasa Indonesia; berat dalam kg dengan koma desimal; poin bilangan bulat dengan pemisah ribuan titik; waktu dalam WIB (UTC+7).

## Kebutuhan Non-Fungsional

Aplikasi harus terasa cepat di ponsel Android kelas menengah, tetap berguna saat offline untuk data yang sudah dimuat, dan tidak pernah menampilkan poin yang salah.

| ID | Kategori | Kebutuhan | Cara uji |
| --- | --- | --- | --- |
| NFR-01 | Performa | Cold start ≤ 3 detik di perangkat menengah (RAM 4 GB); berpindah tab ≤ 300 ms | Profiling di 3 perangkat uji |
| NFR-02 | Performa | Beranda dan Riwayat (20 item) tampil ≤ 2 detik di 4G | Pengukuran manual 20 kali |
| NFR-03 | Kesegaran data | Setoran tampil di aplikasi ≤ 15 detik (p95) setelah mesin online | Log timestamp end-to-end |
| NFR-04 | Keakuratan | Aplikasi tidak menghitung poin sendiri; semua angka berasal dari API dan tidak dibulatkan ulang di klien | Review kode dan uji data |
| NFR-05 | Offline | Saldo dan 50 riwayat terakhir tetap bisa dilihat tanpa internet; semua aksi tulis (tautkan, tukar, ubah) butuh online dan memberi pesan jelas | Uji mode pesawat |
| NFR-06 | Keandalan | Crash-free sessions ≥ 99%; error jaringan tidak pernah menutup aplikasi | Crash reporting, uji jaringan buruk |
| NFR-07 | Keamanan | Seluruh komunikasi lewat TLS 1.2+; token di secure storage; tidak ada rahasia (API key broker, secret HMAC) di dalam aplikasi | Review dan uji keamanan dasar |
| NFR-08 | Privasi | UID KTM tidak disimpan di ponsel maupun di log; data pribadi minimal (NIM, nama, email) | Review kode dan log |
| NFR-09 | Aksesibilitas | Mendukung ukuran font sistem hingga 130%; kontras teks minimal WCAG AA; semua tombol ber-label untuk pembaca layar | Uji manual dengan TalkBack |
| NFR-10 | Kompatibilitas | Android 8.0 (API 26) hingga versi terbaru; lebar layar 360–430 dp; orientasi potret | Matriks 3 perangkat |
| NFR-11 | Lokalisasi | Bahasa Indonesia; zona waktu WIB; struktur teks siap dialihbahasakan (arb) | Review |
| NFR-12 | Ukuran | APK rilis ≤ 40 MB | Pengecekan build |
| NFR-13 | Observabilitas | Crash reporting aktif; event analytics untuk alur utama (daftar, tautkan KTM, buka riwayat, tukar reward) | Verifikasi di dasbor |
| NFR-14 | Pemeliharaan | Analisis statis bersih (`flutter analyze`); cakupan unit test ≥ 60% pada lapisan domain dan data | CI |

## Integrasi Backend

Aplikasi hanya berbicara dengan backend lewat REST JSON atas HTTPS. Data dari mesin sampai ke aplikasi lewat database, tidak pernah langsung dari mesin atau broker MQTT.

### Endpoint REST (dasar: `/api/v1`)

| Metode | Path | Fungsi | Akses | Rilis |
| --- | --- | --- | --- | --- |
| POST | `/auth/register` | Registrasi akun | Publik | R1 |
| POST | `/auth/login` | Login, mengembalikan access dan refresh token | Publik | R1 |
| POST | `/auth/refresh` | Memperbarui access token | Refresh token | R1 |
| POST | `/auth/logout` | Mencabut token | Pengguna | R1 |
| GET | `/me` | Profil dan status KTM | Pengguna | R1 |
| PATCH | `/me` | Ubah nama atau password | Pengguna | R1 |
| DELETE | `/me` | Hapus akun | Pengguna | R2 |
| POST | `/cards/link` | Tautkan KTM dari UID hasil baca NFC; backend menghitung HMAC | Pengguna | R1 |
| POST | `/cards/pairing` | Mulai pairing lewat mesin; mengembalikan token dan waktu kedaluwarsa | Pengguna | R2 |
| DELETE | `/cards/me` | Lepas tautan KTM | Pengguna | R1 |
| GET | `/points/summary` | Saldo, poin tertahan, ringkasan bulan ini | Pengguna | R1 |
| GET | `/deposits` | Riwayat setoran (parameter: cursor, limit, type, from, to) | Pengguna | R1 |
| GET | `/deposits/{id}` | Detail setoran | Pengguna | R1 |
| GET | `/rates` | Nilai poin per kg saat ini | Pengguna | R1 |
| GET | `/machines` | Daftar mesin dan status | Pengguna | R1 |
| GET | `/machines/{id}` | Detail mesin dan status tong | Pengguna | R2 |
| GET, POST | `/notifications`, `/notifications/{id}/read` | Daftar dan tandai dibaca | Pengguna | R1 |
| POST | `/devices` | Mendaftarkan token FCM perangkat | Pengguna | R1 |
| GET, POST | `/rewards`, `/rewards/{id}/redeem`, `/redemptions` | Katalog, tukar (header Idempotency-Key), riwayat penukaran | Pengguna | R2 |
| PUT, POST | `/admin/rates`, `/admin/machines/{id}/reset` | Ubah nilai poin, reset status mesin | Admin | R2 |

Aturan umum API: tanggal ISO 8601 UTC (aplikasi mengonversi ke WIB); galat berbentuk `{"code", "message"}` dengan status HTTP yang sesuai; pagination cursor; batas laju menghasilkan 429 dengan header Retry-After.

### Model data yang dipakai aplikasi

| Entitas | Field kunci | Catatan |
| --- | --- | --- |
| User | id, nim, nama, email, role | role: user atau admin |
| Card | user\_id, uid\_hash, linked\_at | UID mentah tidak disimpan; uid\_hash = HMAC(UID) dengan secret yang sama seperti di ESP32-B |
| Deposit | transaction\_id, machine\_id, uid\_hash, user\_id (kosong bila belum tertaut), type (ORGANIK atau ANORGANIK), weight\_g, points, device\_time, received\_at, status (HELD atau CREDITED) | transaction\_id dari mesin bersifat unik, dipakai untuk menolak duplikat |
| PointLedger | id, user\_id, delta, reason (DEPOSIT, REDEEM, ADJUST), ref\_id, created\_at | Saldo = jumlah seluruh delta; jejak audit |
| Machine | id, name, location, status, status tiap tong (OK atau FULL), last\_seen | Status berasal dari topik `bin/{id}/status` dan MQTT last will |
| Reward, Redemption | id, nama, harga poin, stok; user\_id, reward\_id, kode voucher, status, kedaluwarsa | R2 |
| Notification, DeviceToken | user\_id, jenis, isi, dibaca; user\_id, token FCM, platform | Untuk push |

### Aturan sinkronisasi

- Satu setoran punya satu `transaction_id`; backend menolak duplikat, jadi aplikasi tidak pernah melihat setoran ganda.
- Setoran dari KTM yang belum tertaut disimpan berstatus HELD. Saat KTM tertaut, backend mengubahnya menjadi CREDITED dan menulis ledger dalam satu transaksi database.
- Sampah Residu tidak dikirim mesin, jadi tidak ada di API dan tidak tampil di riwayat.
- Aplikasi menampilkan `device_time` (jam RTC mesin) sebagai waktu setoran. Selisih besar dengan `received_at` menandakan mesin sempat offline; ini hanya ditampilkan di detail.
- Push (FCM) memicu refresh data. Aplikasi juga memuat ulang saat kembali ke foreground dan lewat pull-to-refresh. WebSocket atau SSE hanya dipertimbangkan di Rilis 2.

### Dependensi pada sisi mesin dan backend

| Dependensi | Dibutuhkan oleh | Pemilik | Keterangan |
| --- | --- | --- | --- |
| OpenAPI spec dan server mock | Seluruh pengembangan aplikasi | Backend | Dibagikan paling lambat minggu 2 agar Flutter bisa jalan paralel |
| Backend menghitung HMAC dari UID mentah | FR-CARD-01 | Backend | Memakai secret yang sama dengan ESP32-B; UID tidak disimpan |
| Heartbeat status tiap 60 detik dan MQTT last will pada `bin/{id}/status` | FR-MACH-01, FR-NOTIF-05 | ESP32-B dan backend | Tanpa ini status Offline tidak bisa ditentukan |
| Status tiap tong (OK atau FULL) di payload status | FR-MACH-02 | ESP32-A ke ESP32-B | Level tong dikirim ESP32-A lewat UART |
| Perintah pairing `bin/{id}/cmd` berisi token dan masa berlaku | FR-CARD-06 | Mesin dan backend | Mesin melaporkan uid\_hash bersama token pairing |
| Perintah reset status GANGGUAN `bin/{id}/cmd` | FR-ADM-03 | Mesin dan backend | Perlu autentikasi perintah di sisi mesin |
| Layanan push (FCM) dari backend | FR-NOTIF-\* | Backend | Aplikasi mendaftarkan token lewat `/devices` |

## Arsitektur dan Teknologi Aplikasi

Aplikasi memakai arsitektur berlapis (Presentation, State, Domain, Data) sehingga layar tidak pernah memanggil API langsung, dan server mock bisa menggantikan backend tanpa mengubah layar.

&#91;embedded content: arsitektur aplikasi dan backend · 4 lapisan aplikasi, 4 komponen cloud\]

Aplikasi hanya memanggil REST API (panah tebal). Data mesin tiba di aplikasi lewat database, dan push (FCM) hanya memberi tahu bahwa ada data baru.

### Teknologi yang direkomendasikan

| Kebutuhan | Pilihan | Alasan |
| --- | --- | --- |
| Framework | Flutter (Dart), versi stabil terbaru saat proyek dimulai | Satu basis kode untuk Android dan iOS; kunci versi di `pubspec.lock` |
| State management | Riverpod | Mudah dites dan tidak bergantung pada widget tree |
| Navigasi | go\_router | Deep link dari push ke layar tertentu |
| HTTP | dio dengan interceptor token | Refresh token otomatis, logging, retry |
| Model dan serialisasi | freezed dan json\_serializable | Model immutable dan parsing yang aman |
| Penyimpanan aman | flutter\_secure\_storage | Token di Keystore atau Keychain |
| Cache lokal | drift (SQLite) atau Hive | Saldo dan 50 riwayat terakhir untuk mode offline |
| NFC | flutter\_nfc\_kit | Membaca UID KTM di Android |
| Push | firebase\_messaging dan flutter\_local\_notifications | Push FCM, juga saat aplikasi sedang dibuka |
| Konektivitas | connectivity\_plus | Banner offline |
| Lokalisasi | intl dan berkas arb | Format tanggal dan angka bahasa Indonesia |
| Crash dan analytics | Firebase Crashlytics dan Analytics | Mengukur metrik keberhasilan |
| Pengujian | flutter\_test, mocktail, integration\_test | Sesuai rencana pengujian |

Paket di atas adalah rekomendasi. Tim boleh menggantinya selama lapisan Data tetap dibungkus repository. Periksa status pemeliharaan tiap paket (pembaruan terakhir, kompatibilitas dengan versi Flutter yang dipakai) sebelum memutuskan.

### Struktur proyek dan konfigurasi

- **Struktur feature-first:** `lib/features/` berisi auth, card, home, history, machines, notifications, profile, rewards; tiap fitur punya presentation, state, domain, data. `lib/core/` berisi network, storage, theme, router, l10n.
- **Aturan dependensi:** layar ke state ke domain ke data. Lapisan domain tidak mengimpor Flutter maupun paket jaringan.
- **Flavor:** `mock` (server mock atau data palsu), `dev`, dan `prod`, masing-masing dengan base URL sendiri.
- **CI:** `flutter analyze` dan `flutter test` pada setiap pull request; build APK rilis dari branch utama.

## Keamanan dan Privasi

Taruhan keamanan aplikasi ini rendah (poin dan reward kampus), tetapi data identitas mahasiswa tetap harus dilindungi, dan KTM yang dikloning tidak boleh mudah dipakai mencuri poin.

**Autentikasi dan sesi**

- Access token berumur pendek (15 menit) dan refresh token 30 hari dengan rotasi; keduanya disimpan di secure storage (Keystore Android, Keychain iOS).
- Backend membatasi percobaan login (5 gagal, kunci 5 menit) dan membatasi laju semua endpoint.
- Ubah password mencabut sesi di perangkat lain. Logout mencabut token di server.
- Peran admin diperiksa di server pada setiap endpoint `/admin/*`; menyembunyikan menu di aplikasi saja tidak cukup.

**Penautan KTM**

- UID mentah dibaca lewat NFC hanya untuk dikirim sekali ke `/cards/link` lewat HTTPS. UID tidak disimpan di ponsel, tidak masuk log, dan tidak disimpan di server; backend hanya menyimpan `uid_hash`.
- Token pairing (R2) sekali pakai dan berlaku 2 menit.
- UID kartu MIFARE dapat dikloning. Mitigasinya: batas poin harian dan jeda antar-item di mesin, notifikasi push pada setiap setoran agar pemilik cepat sadar, dan fitur lepas tautan jika kartu hilang. Risiko ini dicantumkan di laporan sebagai batasan.
- Aplikasi menampilkan peringatan singkat: jangan meminjamkan KTM untuk menyetor sampah.

**Privasi data**

- Data pribadi yang dikumpulkan hanya NIM, nama, email kampus, dan riwayat setoran. Aplikasi tidak meminta lokasi, kontak, atau kamera.
- Saat registrasi pengguna menyetujui kebijakan privasi yang menjelaskan data apa yang disimpan dan untuk apa. Rujukan hukum: UU No. 27 Tahun 2022 tentang Pelindungan Data Pribadi.
- Hapus akun menganonimkan riwayat setoran (user\_id dilepas) dan menghapus data pribadi.
- Token FCM dihapus saat logout.

**Keamanan aplikasi**

- Semua komunikasi lewat TLS 1.2 atau lebih baru; certificate pinning dipertimbangkan sebagai tambahan di Rilis 2.
- Tidak ada rahasia di dalam aplikasi: tidak ada kredensial broker MQTT dan tidak ada secret HMAC.
- Build rilis memakai obfuscation (`--obfuscate --split-debug-info`) dan mematikan log debug.
- Validasi input dilakukan di klien untuk pengalaman pengguna dan di server sebagai kontrol sebenarnya.

## Rencana Rilis, Pengujian, dan Risiko

Rilis 1 ditargetkan siap dipakai 30 mahasiswa uji mulai minggu 11 dari 14 minggu semester. Pengerjaan Flutter berjalan paralel dengan mesin dan backend memakai server mock, sehingga aplikasi tidak menunggu integrasi.

### Tahapan

1. **Minggu 1–2:** finalisasi PRD, kontrak API (OpenAPI), desain UI di Figma, server mock.
2. **Minggu 3–6:** fondasi aplikasi (tema, navigasi, autentikasi); layar Beranda dan Riwayat dengan data mock.
3. **Minggu 7–10:** integrasi API nyata, penautan KTM lewat NFC, push notification, cache offline.
4. **Minggu 11–14:** pilot dengan 30 mahasiswa (4 minggu) sambil memperbaiki bug, melengkapi status mesin dan panduan; minggu 14 untuk demo dan dokumentasi. Rilis 2 (reward, admin) hanya dikerjakan bila Rilis 1 sudah stabil.

Pilot bergantung pada mesin yang stabil di minggu 10. Jika mesin terlambat, pilot dipersingkat menjadi 2 minggu dan target keterlibatan dihitung untuk 2 minggu.

### Pengujian

| Jenis | Cakupan | Alat |
| --- | --- | --- |
| Unit test | Parsing JSON, repository, use case, format poin, berat, dan waktu | flutter\_test, mocktail |
| Widget test | Beranda, Riwayat, Tautkan KTM pada semua state (loading, kosong, error, offline) | flutter\_test |
| Integration test | Alur daftar, tautkan KTM (NFC dimock), lihat riwayat | integration\_test |
| Uji end-to-end dengan mesin | 100 setoran, 30 di antaranya saat WiFi mesin mati; KTM belum tertaut lalu tertaut | Manual dengan log |
| Uji perangkat | 3 perangkat Android: RAM rendah, menengah, tinggi; Android 8, 11, dan versi terbaru | Manual |
| Uji pengguna | Uji kegunaan 10 mahasiswa; pilot 30 mahasiswa | Skenario tugas dan formulir umpan balik |

Skenario kritis yang wajib lulus sebelum pilot:

- Setoran saat WiFi mesin mati muncul tepat satu kali setelah mesin tersambung kembali.
- Setoran sebelum KTM ditautkan menjadi poin tertahan, lalu masuk saldo saat KTM tertaut.
- Token yang kedaluwarsa saat aplikasi di latar belakang tidak memaksa pengguna login ulang tanpa sebab.
- Dalam mode pesawat, Beranda dan Riwayat tetap tampil dengan label "data lama".
- Ketukan ganda pada Tukar reward tidak memotong poin dua kali (Rilis 2).

### Risiko

| Risiko | Dampak | Kemungkinan | Mitigasi |
| --- | --- | --- | --- |
| NFC ponsel tidak bisa membaca KTM (tipe kartu atau ponsel tertentu); dukungan iOS belum pasti | Pengguna tidak bisa menautkan KTM | Sedang | Cek tipe KTM dan kestabilan UID sebelum desain final; uji di 3 ponsel; siapkan pairing lewat mesin (R2); jangan mengasumsikan iOS |
| Backend atau mesin belum siap saat integrasi | Pengembangan Flutter terblokir | Sedang | Server mock dari OpenAPI; flavor `mock` di aplikasi |
| Setoran terlambat tampil karena mesin lama offline | Pengguna mengira poin hilang | Tinggi | Penjelasan "data dikirim saat mesin online"; tampilkan waktu mesin; push saat tercatat |
| KTM dikloning atau dipinjam | Poin dicuri | Rendah sampai sedang | Push tiap setoran; lepas tautan; batas harian di mesin |
| Jam RTC mesin salah | Waktu setoran keliru | Rendah | Tampilkan waktu mesin dan waktu diterima; backend menandai selisih besar |
| Cakupan terlalu besar untuk satu semester | Rilis 1 tidak selesai | Sedang | Disiplin prioritas Must; Rilis 2 tidak boleh menahan demo |
| Push tidak sampai (hemat baterai, izin ditolak) | Pengguna tidak tahu setoran tercatat | Sedang | Pull-to-refresh selalu tersedia; minta izin notifikasi dengan konteks yang jelas |

### Asumsi

- KTM berfrekuensi 13,56 MHz dengan UID tetap (dikonfirmasi lewat pengecekan di awal proyek).
- Satu akun hanya satu KTM, dan satu KTM hanya satu akun.
- Backend menyediakan REST dan layanan push; aplikasi tidak memakai MQTT.
- Poin dihitung di mesin dan disimpan backend sebagai bilangan bulat.
- Pilot memakai sekitar 30 mahasiswa dan 1–2 mesin.

### Pertanyaan terbuka

- Reward apa yang ditawarkan, siapa yang mengelola stok, dan bagaimana voucher diambil?
- Apakah admin memakai aplikasi ini, atau cukup web sederhana?
- Berapa nilai poin per kg organik dan anorganik, dan bagaimana aturan pembulatannya?
- Apakah batas poin harian dan jeda antar-item perlu ditampilkan ke pengguna?
- Apakah iOS dibutuhkan, atau Android saja sudah cukup?
- Berapa lama riwayat anonim disimpan setelah akun dihapus?
- Siapa yang memegang secret HMAC dan bagaimana rotasinya?
