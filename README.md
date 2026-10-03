# CioWeb3Apk v3.5

Ubah website jadi aplikasi Android (APK) langsung dari **Termux** — tanpa PC, tanpa Android Studio.
Dev: **Cio-ID**

---

## Daftar isi
1. [Persiapan](#persiapan)
2. [Instalasi step by step](#instalasi-step-by-step)
3. [Build pertama (cara cepat, 3 command)](#build-pertama-cara-cepat)
4. [Build lewat menu (step by step)](#build-lewat-menu-step-by-step)
5. [Icon dari link gambar langsung](#icon-dari-link-gambar-langsung)
6. [Loading screen](#loading-screen)
7. [Fitur aplikasi](#fitur-aplikasi)
8. [Install & bagikan APK](#install--bagikan-apk)
   - [Simpan APK ke CDN sementara](#simpan-apk-ke-cdn-sementara)
9. [Update aplikasi yang sudah dibuat](#update-aplikasi-yang-sudah-dibuat)
10. [Profile & batch build](#profile--batch-build)
11. [Tools otomatis ter-install (tanpa install berulang)](#tools-otomatis-ter-install)
12. [Social profile lookup (API resmi/publik)](#social-profile-lookup)
13. [Website / repo ke ZIP (WebToZip)](#website--repo-ke-zip)
14. [Tampilan banner, tema & animasi](#tampilan-banner-tema--animasi)
15. [Optimizer & pembersihan](#optimizer--pembersihan)
16. [Troubleshooting](#troubleshooting)
17. [Daftar command & opsi](#daftar-command--opsi)
18. [Upload proyek ini ke GitHub](#upload-proyek-ini-ke-github)

---

## Persiapan
- HP Android 7.0+ dengan ruang kosong minimal ±700 MB.
- **Termux** dari **F-Droid** atau GitHub (versi Play Store sudah usang dan sering error).
- (Opsional) aplikasi **Termux:API** dari sumber yang sama — dibutuhkan untuk *Share ke WhatsApp* dan notifikasi.
- Koneksi internet saat instalasi.

## Instalasi step by step

**Langkah 1 — Update Termux dan pasang git**
```bash
pkg update -y && pkg upgrade -y
pkg install git -y
```

**Langkah 2 — Izinkan akses penyimpanan** (supaya APK tersimpan di folder Download)
```bash
termux-setup-storage
```
Tekan **Izinkan** pada dialog yang muncul.

**Langkah 3 — Clone repo**
```bash
git clone https://github.com/axvonix/CioWeb3Apk
cd CioWeb3Apk
```

**Langkah 4 — Pasang semua tools yang dibutuhkan (otomatis)**
```bash
bash cioweb3apk.sh doctor --fix
```
Perintah ini memeriksa Java, aapt2, ecj, dx/d8, apksigner, dll. dan memasang yang kurang.
Selesai jika muncul tulisan **All good - ready to build!** dan tanda `● Ready` di bagian atas menu.

> Alternatif satu langkah: `bash install.sh` (menjalankan `setup`: memasang semua tools sekali, membuat shortcut, mengecek lingkungan).
> Sejak v3.5 langkah ini **boleh dilewati**: setiap command memasang tools yang kurang sendiri saat pertama dipakai (lihat [Tools otomatis ter-install](#tools-otomatis-ter-install)).

**Langkah 5 — (Opsional) buat shortcut** agar bisa dipanggil dari mana saja
```bash
bash cioweb3apk.sh link
```
Setelah itu cukup ketik `cioweb3apk` di Termux.

---

## Build pertama (cara cepat)

Tiga command, selesai:

```bash
cioweb3apk auto https://websiteku.com     # 1. isi otomatis nama, icon, warna dari website
cioweb3apk dry                            # 2. (opsional) lihat rencana build tanpa membangun
cioweb3apk build --share                  # 3. build lalu bagikan ke WhatsApp
```

- `auto` membaca `<title>`, `theme-color` dan icon website, lalu menebak nama package.
- APK jadi di folder **Download** (`~/storage/downloads`).
- Tidak pakai `cioweb3apk`? Ganti dengan `bash cioweb3apk.sh` (misal `bash cioweb3apk.sh auto https://websiteku.com`).

## Build lewat menu (step by step)

Jalankan `cioweb3apk` lalu ikuti urutan ini:

| Langkah | Menu | Yang dilakukan |
|---|---|---|
| 1 | **6) Auto-fill from website** *(atau 2 untuk isi manual)* | Masukkan URL website |
| 2 | **2) Edit config** | Cek/ubah URL, nama aplikasi, package, nama project, icon, warna, loading screen. Tekan **Enter** untuk mempertahankan nilai lama |
| 3 | **7) Icon from direct link** | Tempel link gambar langsung (lihat bagian icon) |
| 4 | **3) App features** | Nyalakan fitur (fullscreen, zoom, kamera, dll.) |
| 5 | **4) Build options** | Optimizer, tema warna, versi aplikasi |
| 6 | **1) Build APK** | Tunggu 9 langkah selesai (progress bar beranimasi) |
| 7 | **5) Share to WhatsApp** | Bagikan APK |

Menu utama lengkap: `1` Build · `2` Edit config · `3` App features · `4` Build options · `5` Share WhatsApp · `6` Auto-fill website · `7` Icon dari link · `8` Social profile lookup · `9` Website→ZIP · `t` More tools · `d` Doctor · `s` Setup · `h` Help · `c` Clean · `0` Keluar.
Kamu juga bisa mengetik command langsung di menu (misalnya `social torvalds` atau `webzip https://situs.com`).

Penjelasan isian **Edit config**:

| Isian | Contoh | Catatan |
|---|---|---|
| Website URL | `https://websiteku.com` | `https://` ditambahkan otomatis |
| App Name | `Toko Ku` | Nama di layar HP |
| Package Name | `com.tokoku.app` | Huruf kecil, minimal 2 bagian, bukan kata kunci Java |
| Project Name | `TokoKu` | Nama file APK |
| Icon | `https://.../logo.png` | File di HP **atau** link gambar langsung |
| ColorPrimaryDark | `#1565C0` | Warna status bar (`#RGB` juga boleh) |
| Loading screen | 0 Tidak ada / 1 Warna / 2 Gambar / 3 Video | File atau link |

## Icon dari link gambar langsung

Icon (dan gambar/video loading screen) bisa diambil dari **link**, tidak perlu simpan file di HP.

**Langkah:**
1. Cari link gambar **langsung** — yang ujungnya `.png`, `.jpg`, atau `.webp`.
   Cara mudah: tahan gambar di browser → **Salin alamat gambar**.
2. Pakai salah satu cara ini:
   ```bash
   cioweb3apk icon test https://situs.com/logo.png   # cek dulu, tidak disimpan
   cioweb3apk icon set  https://situs.com/logo.png   # cek + simpan sebagai icon
   cioweb3apk build --icon-url https://situs.com/logo.png   # langsung saat build
   ```
   atau lewat menu **7) Icon from direct link**.
3. Alat akan menampilkan hasil pengecekan, misalnya `Image OK: png, 512x512px, 24K`.

**Link yang dikonversi otomatis** (boleh tempel link "share" biasa):

| Sumber | Contoh yang boleh ditempel |
|---|---|
| Imgur | `https://imgur.com/aBcDe12` |
| GitHub | `https://github.com/user/repo/blob/main/logo.png` |
| Google Drive | `https://drive.google.com/file/d/ID/view` (file harus *Anyone with the link*) |
| Dropbox | `https://www.dropbox.com/s/abc/logo.png?dl=0` |

**Pengecekan otomatis:** link yang membuka halaman web (bukan gambar), SVG, link 404/403, file terlalu besar (>25 MB), atau koneksi putus akan ditolak dengan pesan yang jelas.
Ukuran terbaik: **PNG 512×512** persegi. Gambar tidak persegi akan diberi ruang transparan.

## Loading screen

Tampil sampai halaman web selesai dimuat (minimal sesuai durasi yang kamu atur, lalu memudar).

```bash
cioweb3apk build --splash none                          # tanpa loading screen
cioweb3apk build --splash color:#0D47A1                 # warna
cioweb3apk build --splash image:https://x.com/bg.png   # gambar (path atau link)
cioweb3apk build --splash video:/sdcard/Download/a.mp4  # video mp4 (path atau link)
```
Video otomatis dikecilkan jika `ffmpeg` terpasang (`pkg install ffmpeg`). Pakai video pendek (<15 MB).

## Fitur aplikasi

Menu **3) App features** (semua bisa ON/OFF):

| Fitur | Fungsi |
|---|---|
| Fullscreen | Sembunyikan status bar |
| Orientation | auto / portrait / landscape |
| Keep screen on | Layar tidak mati |
| File downloads / upload | Unduh file dan pilih file di form |
| Loading min. time / fade | Durasi minimal & efek memudar |
| Top progress bar | Garis kemajuan di atas halaman |
| Pinch zoom | Cubit untuk zoom |
| Lock to site domain | Link ke situs lain dibuka di browser |
| Press back twice | Tekan back 2x untuk keluar |
| Desktop mode / Custom User-Agent | Tampilan versi desktop / UA sendiri |
| Camera / mic / location | Izinkan situs memakai kamera, mikrofon, lokasi (video call, peta) |
| Block screenshots | Cegah screenshot & rekam layar |

Otomatis aktif: link `tel:` `mailto:` `whatsapp:` dibuka di aplikasinya, dan halaman "No connection" dengan tombol **Retry** saat offline.

> *Lock to site domain* dapat mengganggu login lewat situs lain (misalnya "Masuk dengan Google"). Nyalakan hanya jika perlu.

## Install & bagikan APK

- **Install:** menu `t` (*More tools*) → *Install last APK*, atau buka file APK dari folder Download.
  Android akan meminta izin **Instal aplikasi tidak dikenal** untuk Termux/File Manager — izinkan.
- **WhatsApp:** `cioweb3apk share` (butuh `pkg install termux-api` + aplikasi Termux:API).
  Jika WhatsApp menolak file `.apk`, jadikan zip dulu lalu kirim zip-nya.
- **Wi-Fi ke HP lain:** `cioweb3apk serve` menampilkan link dan QR (`pkg install qrencode`). Hanya APK itu yang dibagikan.
- **Cek isi APK:** `cioweb3apk info` (package, versi, SHA-256, validitas tanda tangan).

### Simpan APK ke CDN sementara

Upload APK ke file host publik yang menghapus file otomatis, lalu dapat **link download** yang bisa dikirim ke siapa saja (tanpa mengirim file besar lewat WhatsApp).

```bash
cioweb3apk upload                 # upload APK terakhir
cioweb3apk upload /path/App.apk   # upload file tertentu
cioweb3apk build --upload --ttl 12h   # build lalu langsung upload, kedaluwarsa 12 jam
cioweb3apk links                  # daftar link + sisa waktu aktif
```

| Pengaturan | Pilihan | Menu |
|---|---|---|
| Masa aktif (`--ttl`) | `1h` `12h` `24h` `72h` | Build options → 9 |
| Host (`--cdn`) | `auto` (coba berurutan) `litterbox` `0x0` `tmpfiles` | Build options → a |
| Upload otomatis setelah build | ON / OFF | Build options → b |

- Mode `auto`: jika satu host gagal, otomatis mencoba host berikutnya.
- Setelah berhasil: link tampil, disalin ke clipboard (`termux-api`), muncul QR (`qrencode`), dan bisa langsung dikirim lewat aplikasi apa pun.
- **Penting:** siapa pun yang memegang link bisa mengunduh APK sampai kedaluwarsa. Keystore **tidak** ikut terupload.
- Layanan pihak ketiga bisa berubah aturan/limit sewaktu-waktu. Jika semua host gagal, cek internet lalu coba lagi nanti.

## Update aplikasi yang sudah dibuat

Supaya APK baru **menimpa** yang lama tanpa hapus dulu:
1. Naikkan **version code** (menu *Build options → 7*, atau `--code 2`).
2. Pakai **keystore yang sama** (otomatis, file `cio.keystore` + `.ks_pass`).
3. Package name **jangan diubah**.

**Wajib cadangkan keystore** — jika hilang, aplikasi lama tidak bisa di-update:
```bash
cioweb3apk keystore backup      # tersimpan di Download/cioweb3apk-keystore-backup
```
Simpan file itu secara pribadi (jangan upload ke GitHub).

## Profile & batch build

Simpan banyak proyek dan bangun sekaligus:
```bash
cioweb3apk profile save tokoku          # simpan config saat ini
cioweb3apk profile list
cioweb3apk build tokoku                 # build dari profile
cioweb3apk batch                        # build SEMUA profile
cioweb3apk profile export tokoku        # simpan ke Download sebagai .cioprofile
cioweb3apk profile import <file/link>   # impor profile teman (aman, tidak menjalankan kode)
```

## Tools otomatis ter-install

Tidak perlu `pkg install` berulang-ulang. Setiap command mengecek tools yang dibutuhkannya dan **memasang yang kurang secara otomatis, hanya sekali** (dengan animasi proses):

| Command | Tools yang disiapkan otomatis |
|---|---|
| `build`, `batch` | openjdk-17, ecj, aapt, aapt2, apksigner, dx, zip, unzip, imagemagick, curl + `android.jar` |
| `social` | python |
| `webzip` | wget, zip, curl, python |
| `share` | termux-api |
| `serve` | python |
| `update` | git |
| `upload`, `icon`, `auto` | curl |

- Jika instalasi gagal, script otomatis menjalankan `pkg update` lalu mencoba lagi. Jika masih gagal akan muncul saran `termux-change-repo` (ganti mirror).
- Mau pasang **semua sekaligus** (sekali jalan): `cioweb3apk setup` (menu `s`).
- Mau mematikan fitur ini: Build options → `f`, atau `--no-auto-install`.
- Catatan: untuk *Share ke WhatsApp* kamu tetap perlu memasang aplikasi **Termux:API** (aplikasi Android, bukan paket).

## Social profile lookup

Mencari informasi **profil publik** sebuah username lewat **API resmi / publik** milik platform itu sendiri — tanpa login, tanpa scraping, sekali cari (bukan pemantauan).

```bash
cioweb3apk social torvalds                       # semua platform
cioweb3apk social torvalds github,bluesky        # platform tertentu
cioweb3apk social user@mastodon.social           # Mastodon dengan instance
cioweb3apk social torvalds --save                # simpan laporan ke Download
cioweb3apk social torvalds --json                # keluaran JSON (untuk script)
cioweb3apk social list                           # daftar platform
```

Platform: GitHub, GitLab, Bluesky, Mastodon, Reddit, Hacker News, Stack Overflow, Lichess, Chess.com, DEV, YouTube.
Yang ditampilkan hanya data yang memang dipublikasikan platform: nama, bio, jumlah followers/following/post, tanggal bergabung, link profil.
**Sengaja tidak ada:** email, lokasi, nomor telepon, dan pelacakan aktivitas.

- **YouTube** butuh API key gratis (Google Cloud Console → YouTube Data API v3): `cioweb3apk keys set youtube KUNCI`.
  **GitHub** boleh memakai token (opsional, batas request lebih tinggi): `cioweb3apk keys set github TOKEN`.
  Key disimpan di file `.keys` (hanya bisa dibaca pemilik, tidak ikut ke Git/profile).
- **Instagram, TikTok, X/Twitter, Facebook, Threads, Telegram, Snapchat tidak didukung**: platform itu tidak menyediakan API resmi untuk mencari profil sembarang orang (butuh aplikasi yang disetujui / berbayar), dan tool ini tidak melakukan scraping.
- Pakai secara bertanggung jawab: untuk memeriksa akun kreator/brand/milik sendiri, bukan untuk mengganggu orang lain.
- Reddit membatasi akses tanpa login; jika muncul "blocked / rate-limited", coba lagi nanti.

## Website / repo ke ZIP

Mengubah website atau repository menjadi satu file ZIP di folder Download.

```bash
cioweb3apk webzip https://github.com/pengguna/repo            # repo GitHub (API resmi)
cioweb3apk webzip https://github.com/pengguna/repo/tree/dev   # branch tertentu
cioweb3apk webzip https://gitlab.com/grup/proyek              # proyek GitLab (API resmi)
cioweb3apk webzip https://situsku.com --depth 2 --max-mb 50   # salin situs (mirror sopan)
cioweb3apk webzip https://situsku.com --wayback               # salinan arsip Internet Archive (1 halaman)
cioweb3apk webzip https://situsku.com --upload                # lalu langsung buat link CDN sementara
```

| Mode | Cara kerja |
|---|---|
| GitHub / GitLab | Mengunduh arsip lewat API resmi masing-masing (tanpa mirroring) |
| Situs biasa | Mirror dengan `wget`: **robots.txt dihormati**, jeda 0,5 detik, hanya domain yang sama, kedalaman 1–3, batas ukuran (`--max-mb`, maks 200) |
| `--wayback` | Mengambil salinan terdekat lewat API publik Internet Archive (satu halaman) |

- Mode situs biasa meminta konfirmasi bahwa **kamu pemilik situs atau punya izin**. Tanpa terminal interaktif tambahkan `--yes`.
- Alamat lokal/jaringan privat (`localhost`, `192.168.x.x`, `10.x.x.x`, dll.) ditolak.
- Situs yang butuh login atau yang isinya dibuat JavaScript sepenuhnya tidak bisa disalin lengkap; coba `--wayback`.
- Aset dari domain lain (CDN) tidak ikut tersalin. Hormati hak cipta pemilik situs.
- Setiap ZIP berisi `_ARCHIVE_INFO.txt` (sumber, tanggal, alat).

## Tampilan banner, tema & animasi

**Banner baru (v3.5, style `card`)** — kartu berbingkai dengan judul gradasi per huruf, tagline, dan panel status (Ready/Setup, jumlah build, CDN, developer, tema, optimizer). Mode `auto` memakai `card` di layar ≥ 50 kolom dan `mini` di layar sempit. Style lama (`big`, `medium`, `mini`, `off`) tetap tersedia.
Header di layar lain berupa "tab" berwarna: `[◆ CioWeb3Apk] [v3.5] [● Ready] [cyan]`.

**Animasi proses build** — setiap langkah menampilkan spinner, progress bar gradasi (kotak yang sedang berjalan berkedip), hitungan detik, lalu berubah menjadi ✔ saat selesai; tulisan **BUILD SUCCESS** muncul huruf demi huruf. Animasi yang sama dipakai saat memasang tools, mengunduh, mirror website dan lookup. Otomatis nonaktif jika output dialihkan ke file/pipe, `LIVE` aktif, atau `--no-anim`.

```bash
cioweb3apk banner card       # pratinjau banner (auto|card|big|medium|mini|off)
cioweb3apk theme magenta     # tema: cyan green magenta yellow blue mono
```
Pengaturan: **Build options → c** (style banner), **d** (animasi intro), **e** (animasi build).

## Optimizer & pembersihan

Aktif otomatis (*Build options → 1*): icon 5 ukuran dibuat paralel dan di-cache, gambar diperkecil, PNG dikompres
(`pkg install pngquant` opsional), info debug dibuang, kompresi ZIP maksimal, zipalign, file sementara dihapus.
Setelah build tampil selisih ukuran dibanding build sebelumnya dan langkah paling lambat.
```bash
cioweb3apk clean        # hapus proyek sementara, cache, log (keystore & APK aman)
cioweb3apk log          # lihat langkah & command build terakhir
```

## Troubleshooting

| Gejala | Solusi |
|---|---|
| `○ Setup needed` di menu | `cioweb3apk doctor --fix` |
| Build gagal di langkah *Link manifest* dengan `expected reference but got (raw string)` | Bug versi lama (v3.4 ke bawah) — `cioweb3apk update` / pakai v3.5 lalu build ulang |
| `pkg install` gagal / mirror error | `termux-change-repo` pilih mirror lain, lalu jalankan ulang commandnya |
| Tampilan acak setelah zoom/resize layar Termux | Efek reflow layar; jalankan `clear` atau buka ulang menu |
| Build gagal | Lihat pesan `✘ FAILED` + saran perbaikan; detail: `cioweb3apk log full` atau file `build.log` |
| `android.jar missing` (walau `aapt` sudah terpasang) | `cioweb3apk jar` (unduh otomatis) atau `cioweb3apk jar /path/android.jar` / `cioweb3apk jar <link langsung>` |
| Perintah `cioweb3apk` tidak jalan | Jalankan `bash cioweb3apk.sh link` lagi, lalu `cioweb3apk selftest`. Sementara itu pakai `bash cioweb3apk.sh` |
| Garis/progress bar tampil aneh | Update ke v3.3 (bug karakter sudah diperbaiki) |
| Upload CDN gagal | `cioweb3apk upload` lagi, atau pilih host lain: Build options → a |
| `attribute ... not found` | `pkg upgrade aapt aapt2` |
| Icon ditolak "WEB PAGE" | Itu link halaman, bukan gambar. Salin *alamat gambar* langsung (berakhiran .png/.jpg) |
| Icon ditolak 403/404 | Link privat/salah. Untuk Drive, set *Anyone with the link* |
| APK tidak muncul di Download | Jalankan `termux-setup-storage`, lalu build ulang |
| "App not installed" saat update | Version code harus lebih besar dan keystore sama |
| Share WhatsApp tidak jalan | `pkg install termux-api` + pasang aplikasi Termux:API |
| Build mati saat layar terkunci | Otomatis memakai wake-lock; matikan penghemat baterai untuk Termux |
| Ingin mulai dari nol | `cioweb3apk clean` lalu hapus `config.conf` |

Masih error? Kirim isi `build.log` atau hasil `cioweb3apk log`.

## Daftar command & opsi

```
cioweb3apk                        menu
cioweb3apk build [profile]        build          cioweb3apk dry [profile]   rencana saja
cioweb3apk batch                  build semua profile
cioweb3apk auto URL               isi otomatis dari website
cioweb3apk icon set|test|reset    icon dari link/file
cioweb3apk profile save|load|delete|list|export|import NAME
cioweb3apk doctor [--fix]         cek bug / pasang tools
cioweb3apk share | install | serve | info | log [full] | keystore [backup]
cioweb3apk upload [file] | links       APK -> link CDN sementara
cioweb3apk jar [path|link]        cari / unduh android.jar
cioweb3apk selftest               cek semua fungsi tool
cioweb3apk setup                  pasang semua tools sekali jalan
cioweb3apk social USER [platform] lookup profil publik | social list | keys set youtube|github KEY
cioweb3apk webzip URL             website/repo -> ZIP (--depth --max-mb --wayback --out)
cioweb3apk banner [style]         pratinjau banner (auto|card|big|medium|mini|off)
cioweb3apk list | clean | update | link | cmd | theme NAME | help | version
```

Opsi build:
```
--url --name --pkg --project --icon (--icon-url) --color --version --code --orient
--splash none|color:#HEX|image:PATH/LINK|video:PATH/LINK
--fullscreen --keep-on --zoom --lock-domain --desktop --ua "UA" --no-progress
--web-perms --secure --profile NAME --theme green|magenta|yellow|blue|mono|cyan
--no-opt --live --refresh --dry-run --share --install --yes
--upload --ttl 1h|12h|24h|72h --cdn auto|litterbox|0x0|tmpfiles --banner auto|card|big|medium|mini|off --no-anim --no-auto-install
--only github,bluesky --save --json (social)   --depth --max-mb --wayback --out (webzip)
```
`--yes` hanya menyetujui pemasangan paket; untuk otomatis membagikan/memasang setelah build pakai `--share` / `--install`.
`cioweb3apk cmd` menampilkan command lengkap yang setara dengan config saat ini.

Contoh lengkap:
```bash
cioweb3apk build --url https://tokoku.com --name "Toko Ku" --pkg com.tokoku.app \
  --icon-url https://tokoku.com/logo.png --color "#0D47A1" \
  --splash image:https://tokoku.com/splash.png --fullscreen --web-perms --share
```

## Upload proyek ini ke GitHub

```bash
cd CioWeb3Apk
git init
git add .
git commit -m "CioWeb3Apk v3.5"
git branch -M main
git remote add origin https://github.com/axvonix/CioWeb3Apk.git
git push -u origin main
```
File `.gitignore` sudah mengecualikan keystore, password keystore, config, log, dan hasil build — **jangan hapus** agar kunci tanda tangan tidak bocor.
Pengguna lain tinggal `git clone` lalu ikuti [instalasi](#instalasi-step-by-step). Update tool: `cioweb3apk update`.

---
Lisensi: MIT © Cio-ID
