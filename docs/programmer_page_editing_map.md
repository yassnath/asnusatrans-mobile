# Programmer Page Editing Map

Update: 2026-06-04

Dokumen ini adalah peta cepat untuk programmer saat ingin mengubah tampilan, fitur, logic, print, atau database. Nomor line adalah anchor kondisi repo saat dokumen dibuat; setelah ada edit besar, line bisa bergeser. Kalau line bergeser, cari nama symbol/fungsi yang disebutkan.

## Cara Pakai Cepat

| Kebutuhan | Mulai dari file/line |
| --- | --- |
| Ganti nama menu/page | `lib/features/dashboard/presentation/dashboard_page.dart:455` |
| Tambah/hapus menu admin/pengurus/customer | `lib/features/dashboard/presentation/dashboard_page.dart:528` |
| Ganti page yang dibuka menu | `lib/features/dashboard/presentation/dashboard_page.dart:1398` |
| Ubah tombol/icon notifikasi di header | `lib/features/dashboard/presentation/dashboard_page.dart:1006`, `lib/features/dashboard/presentation/dashboard_page.dart:1316` |
| Ubah kartu/list invoice utama | `lib/features/dashboard/presentation/dashboard_invoice_list_widgets.dart:58` |
| Ubah popup preview income/expense | `lib/features/dashboard/presentation/dashboard_invoice_list_preview_support.dart:5`, `lib/features/dashboard/presentation/dashboard_invoice_list_preview_support.dart:2423` |
| Ubah popup edit income/expense | `lib/features/dashboard/presentation/dashboard_invoice_list_edit_support.dart:4`, `lib/features/dashboard/presentation/dashboard_invoice_list_edit_support.dart:1526` |
| Ubah print invoice/PDF | `lib/features/dashboard/presentation/dashboard_invoice_printing.dart:372` |
| Ubah popup cetak invoice | `lib/features/dashboard/presentation/dashboard_invoice_list_print_selector.dart:4` |
| Ubah print laporan | `lib/features/dashboard/presentation/dashboard_invoice_list_report_summary.dart:4` |
| Ubah harga/kg otomatis | `lib/features/dashboard/utils/income_pricing_rule_logic.dart:99`, `lib/features/dashboard/utils/gabungan_pricing_rule_logic.dart:1` |
| Ubah auto expense sangu/gabungan | `lib/features/dashboard/data/dashboard_repository.dart:1205`, `lib/features/dashboard/utils/sangu_rule_logic.dart:1` |
| Ubah deteksi armada manual/Gabungan | `lib/features/dashboard/utils/manual_armada_logic.dart:1` |
| Ubah parsing/normalisasi plat armada | `lib/features/dashboard/utils/armada_identifier_logic.dart:1` |
| Ubah status armada Ready/Full/Inactive | `lib/features/dashboard/utils/fleet_status_logic.dart:1` |
| Ubah parsing/subtotal detail invoice | `lib/features/dashboard/utils/invoice_detail_amount_logic.dart:1` |
| Ubah status pembayaran Paid/Partial/Unpaid | `lib/features/dashboard/utils/payment_status_logic.dart:1` |
| Ubah data CRUD Supabase | `lib/features/dashboard/data/dashboard_repository_crud.dart:35` |
| Ubah quality gate CI | `.github/workflows/flutter-quality.yml:1` |

## App, Theme, Core

| Bagian | File/line | Untuk mengubah |
| --- | --- | --- |
| App root `MaterialApp` | `lib/app.dart:10` | Theme, route awal, wrapper `AuthGate` |
| Startup error screen | `lib/app.dart:50` | Tampilan saat konfigurasi gagal |
| Config Supabase/API/render service | `lib/core/config/app_config.dart:6` | URL, anon key, render service, config runtime |
| Theme global | `lib/core/theme/app_theme.dart:5` | `ThemeData`, input decoration, scaffold, font |
| Warna/token UI | `lib/core/theme/app_colors.dart:3` | Semua warna aplikasi, status, entity CV/PT/Pribadi |
| Style tombol | `lib/core/theme/cvant_button_styles.dart:5` | Filled/outlined button style global |
| Toggle dark/light | `lib/core/theme/theme_controller.dart:4` | Persistensi dan toggle theme |
| Bahasa ID/EN | `lib/core/i18n/language_controller.dart:22` | Toggle bahasa dan label bahasa |
| Format tanggal/rupiah/invoice | `lib/core/utils/formatters.dart` | Format angka, tanggal, nomor invoice |
| Popup umum | `lib/core/widgets/cvant_popup.dart:61`, `lib/core/widgets/cvant_popup.dart:118`, `lib/core/widgets/cvant_popup.dart:171` | Alert, confirm, ukuran popup, tombol popup |
| Dropdown reusable | `lib/core/widgets/cvant_dropdown_field.dart:5` | Bentuk dropdown di seluruh app |
| Logo/image fallback | `lib/core/widgets/cvant_logo.dart:6`, `lib/core/widgets/cvant_logo.dart:105` | Asset logo dan fallback |
| Animasi transisi page | `lib/core/widgets/page_fade_in.dart:3` | Fade-in page |
| Security URL/error | `lib/core/security/app_security.dart:8`, `lib/core/security/app_security.dart:115` | Validasi URL, error widget release |
| Quality gate CI | `.github/workflows/flutter-quality.yml:1` | `pubspec.lock` sync, repo hygiene, format penuh, analyze, test |

## Auth Pages

| Page/fitur | File/line | Untuk mengubah |
| --- | --- | --- |
| Gate login/dashboard | `lib/features/auth/presentation/auth_gate.dart:17` | Menentukan user masuk ke login, signup, atau dashboard |
| Restore session | `lib/features/auth/presentation/auth_gate.dart:59` | Auto-login awal aplikasi |
| Callback login berhasil | `lib/features/auth/presentation/auth_gate.dart:77` | Bind session/push setelah login |
| Logout | `lib/features/auth/presentation/auth_gate.dart:96` | Clear session dan kembali login |
| Build gate | `lib/features/auth/presentation/auth_gate.dart:121` | Switch splash, login, signup, dashboard |
| Splash screen | `lib/features/auth/presentation/auth_gate.dart:162`, `lib/features/auth/presentation/auth_gate.dart:229` | Tampilan loading awal |
| Shell auth background | `lib/features/auth/presentation/auth_shell.dart:6`, `lib/features/auth/presentation/auth_shell.dart:19` | Layout login/signup, background glow |
| Login page | `lib/features/auth/presentation/sign_in_page.dart:16`, `lib/features/auth/presentation/sign_in_page.dart:306` | Tampilan form login |
| Submit login | `lib/features/auth/presentation/sign_in_page.dart:140` | Validasi dan auth sign-in |
| Error login | `lib/features/auth/presentation/sign_in_page.dart:220` | Pesan error user-facing |
| Login biometrik | `lib/features/auth/presentation/sign_in_page.dart:238` | Fingerprint/biometric flow |
| WhatsApp bantuan | `lib/features/auth/presentation/sign_in_page.dart:290` | Link bantuan login |
| Field login reusable | `lib/features/auth/presentation/sign_in_page.dart:451` | Style input login |
| Signup page | `lib/features/auth/presentation/sign_up_page.dart:12`, `lib/features/auth/presentation/sign_up_page.dart:180` | Tampilan daftar customer |
| Date picker tanggal lahir | `lib/features/auth/presentation/sign_up_page.dart:57` | Pilihan birth date |
| Submit signup | `lib/features/auth/presentation/sign_up_page.dart:70` | Validasi dan register |
| Field signup | `lib/features/auth/presentation/sign_up_page.dart:313` | Style input signup |
| Select signup | `lib/features/auth/presentation/sign_up_page.dart:368` | Style dropdown signup |
| Auth repository | `lib/features/auth/data/auth_repository.dart:6` | Restore/sign-in/register/sign-out |
| Username login lookup | `lib/features/auth/data/auth_repository.dart:162`, `lib/features/auth/data/auth_repository.dart:226` | Mapping username ke email |
| Biometric service | `lib/features/auth/data/biometric_login_service.dart:37` | Persistensi dan autentikasi biometrik |
| Auth session model | `lib/features/auth/models/auth_session.dart:1` | Role/session user |
| Signup payload model | `lib/features/auth/models/sign_up_payload.dart:1` | Field register customer |

## Dashboard Shell dan Navigasi

| Bagian | File/line | Untuk mengubah |
| --- | --- | --- |
| Daftar part file dashboard | `lib/features/dashboard/presentation/dashboard_page.dart:49` | Semua file page yang digabung ke dashboard |
| Label menu ID/EN | `lib/features/dashboard/presentation/dashboard_page.dart:455` | Nama menu/page, termasuk `Add Income` dan `Add Expense` |
| Menu admin | `lib/features/dashboard/presentation/dashboard_page.dart:528` | Urutan menu admin |
| Menu pengurus | `lib/features/dashboard/presentation/dashboard_page.dart:543` | Urutan menu pengurus |
| Menu customer | `lib/features/dashboard/presentation/dashboard_page.dart:551` | Urutan menu customer |
| Staff notification data | `lib/features/dashboard/presentation/dashboard_page.dart:596`, `lib/features/dashboard/presentation/dashboard_page.dart:639` | Bentuk notifikasi staff/admin |
| Mark staff read | `lib/features/dashboard/presentation/dashboard_page.dart:673` | Hilangkan badge/tandai dibaca |
| Target notifikasi | `lib/features/dashboard/presentation/dashboard_page.dart:714`, `lib/features/dashboard/presentation/dashboard_page.dart:780` | Klik notifikasi membuka page mana |
| Push intent handler | `lib/features/dashboard/presentation/dashboard_page.dart:827` | Navigasi dari push notification |
| Select menu admin | `lib/features/dashboard/presentation/dashboard_page.dart:854` | Logic pindah menu |
| Reload dashboard | `lib/features/dashboard/presentation/dashboard_page.dart:861` | Refresh semua future/notifier |
| Prompt push Android | `lib/features/dashboard/presentation/dashboard_page.dart:881` | Popup izin notif/autostart/battery |
| Live refresh dashboard | `lib/features/dashboard/presentation/dashboard_page.dart:956`, `lib/features/dashboard/presentation/dashboard_page.dart:968` | Auto-refresh armada/activity |
| Refresh staff alerts | `lib/features/dashboard/presentation/dashboard_page.dart:979` | Fetch badge/notifikasi staff |
| Dialog notifikasi staff | `lib/features/dashboard/presentation/dashboard_page.dart:1006` | Popup list notifikasi sebelah theme toggle |
| Scaffold/appbar/drawer | `lib/features/dashboard/presentation/dashboard_page.dart:1255` | Layout utama semua role |
| Tombol notifikasi header | `lib/features/dashboard/presentation/dashboard_page.dart:1316` | Icon bell dan badge |
| Body admin switch | `lib/features/dashboard/presentation/dashboard_page.dart:1398` | Menu admin index -> page |
| Body pengurus switch | `lib/features/dashboard/presentation/dashboard_page.dart:1488` | Menu pengurus index -> page |
| Body customer switch | `lib/features/dashboard/presentation/dashboard_page.dart:1542` | Menu customer index -> page |
| Admin dashboard home | `lib/features/dashboard/presentation/dashboard_page.dart:1572` | Susunan kartu dashboard admin |
| Customer dashboard home | `lib/features/dashboard/presentation/dashboard_page.dart:1670` | Susunan kartu dashboard customer |
| Auto-loop metric strip | `lib/features/dashboard/presentation/dashboard_page.dart:1738` | Slider metric kecil |
| Footer | `lib/features/dashboard/presentation/dashboard_page.dart:1829` | `Solvix Studio © 2026` |
| Background dashboard | `lib/features/dashboard/presentation/dashboard_page.dart:1849` | Glow/gradient background |
| Drawer/sidebar | `lib/features/dashboard/presentation/dashboard_page.dart:1914` | Icon menu, label, badge drawer |
| Loading/error/placeholder/card/pill | `lib/features/dashboard/presentation/dashboard_page.dart:2102`, `lib/features/dashboard/presentation/dashboard_page.dart:2116`, `lib/features/dashboard/presentation/dashboard_page.dart:2145`, `lib/features/dashboard/presentation/dashboard_page.dart:2178`, `lib/features/dashboard/presentation/dashboard_page.dart:2194` | State UI umum |

## Dashboard Widgets

| Komponen | File/line | Untuk mengubah |
| --- | --- | --- |
| Metric card | `lib/features/dashboard/presentation/widgets/metric_card.dart:5`, `lib/features/dashboard/presentation/widgets/metric_card.dart:24` | Kartu Total Income/Expense/dll |
| Chart income vs expense | `lib/features/dashboard/presentation/widgets/income_expense_chart_card.dart:8`, `lib/features/dashboard/presentation/widgets/income_expense_chart_card.dart:19` | Grafik, legend, skala |
| Chart spots/maxY | `lib/features/dashboard/presentation/widgets/income_expense_chart_card.dart:229`, `lib/features/dashboard/presentation/widgets/income_expense_chart_card.dart:236` | Data chart |
| Armada overview donut | `lib/features/dashboard/presentation/widgets/armada_overview_card.dart:10`, `lib/features/dashboard/presentation/widgets/armada_overview_card.dart:29` | Ringkasan armada |
| Warna donut armada | `lib/features/dashboard/presentation/widgets/armada_overview_card.dart:291`, `lib/features/dashboard/presentation/widgets/armada_overview_card.dart:295` | Palette chart armada |
| Customer latest/biggest | `lib/features/dashboard/presentation/widgets/latest_customers_card.dart:9`, `lib/features/dashboard/presentation/widgets/latest_customers_card.dart:37` | Card customer terbaru/transaksi terbesar |
| Tab latest/biggest | `lib/features/dashboard/presentation/widgets/latest_customers_card.dart:187` | Tombol tab card |
| Recent transactions | `lib/features/dashboard/presentation/widgets/recent_transactions_card.dart:9`, `lib/features/dashboard/presentation/widgets/recent_transactions_card.dart:28` | List transaksi terbaru |
| Recent activity | `lib/features/dashboard/presentation/widgets/recent_activity_card.dart:7`, `lib/features/dashboard/presentation/widgets/recent_activity_card.dart:18` | Aktivitas terbaru |
| Customer orders card | `lib/features/dashboard/presentation/widgets/customer_orders_card.dart:9`, `lib/features/dashboard/presentation/widgets/customer_orders_card.dart:20` | Order terbaru customer |
| Label status order | `lib/features/dashboard/presentation/widgets/customer_orders_card.dart:130` | Translate status order |
| Status badge | `lib/features/dashboard/presentation/widgets/status_badge.dart:5`, `lib/features/dashboard/presentation/widgets/status_badge.dart:11` | Badge Paid/Unpaid/Ready/etc |

## Invoice List Page

| Bagian | File/line | Untuk mengubah |
| --- | --- | --- |
| Widget root invoice list | `lib/features/dashboard/presentation/dashboard_invoice_list_view.dart:3` | Konstruktor/repository/session page |
| State invoice list | `lib/features/dashboard/presentation/dashboard_invoice_list_view.dart:22` | Semua state, filter, background sync |
| Default lokasi muat/driver/plate | `lib/features/dashboard/presentation/dashboard_invoice_list_view.dart:20`, `lib/features/dashboard/utils/armada_identifier_logic.dart:1` | Opsi form edit/list terkait driver-armada dan normalize plat |
| Column fetch invoice/expense | `lib/features/dashboard/presentation/dashboard_invoice_list_view.dart:69` | Kolom Supabase yang diambil page list |
| Expand multi-rincian jadi card detail | `lib/features/dashboard/presentation/dashboard_invoice_list_view.dart:535` | Kalau invoice punya banyak rincian, dipecah di list |
| Load data list | `lib/features/dashboard/presentation/dashboard_invoice_list_view.dart:633` | Fetch invoices, expenses, fixed invoice cache |
| Maintenance background | `lib/features/dashboard/presentation/dashboard_invoice_list_view.dart:694`, `lib/features/dashboard/presentation/dashboard_invoice_list_view.dart:707` | Sync tanggal, pricing, auto expense, nomor invoice |
| Refresh manual | `lib/features/dashboard/presentation/dashboard_invoice_list_view.dart:839` | Pull-to-refresh dan refresh setelah aksi |
| Delete invoice | `lib/features/dashboard/presentation/dashboard_invoice_list_view.dart:886` | Hapus income |
| Delete expense | `lib/features/dashboard/presentation/dashboard_invoice_list_view.dart:905` | Hapus expense |
| Confirm delete | `lib/features/dashboard/presentation/dashboard_invoice_list_view.dart:924` | Popup konfirmasi hapus |
| Send invoice | `lib/features/dashboard/presentation/dashboard_invoice_list_view.dart:949` | Kirim invoice ke notifikasi customer/email |
| Fixed invoice cache/local remote | `lib/features/dashboard/presentation/dashboard_invoice_list_fixed_invoice_cache.dart:4`, `lib/features/dashboard/presentation/dashboard_invoice_list_fixed_invoice_cache.dart:222` | Cache invoice yang sudah dicetak/fix |
| Fixed invoice payment/detail | `lib/features/dashboard/presentation/dashboard_invoice_support.dart:262`, `lib/features/dashboard/utils/invoice_detail_amount_logic.dart:1`, `lib/features/dashboard/utils/armada_identifier_logic.dart:1`, `lib/features/dashboard/utils/payment_status_logic.dart:1` | Parsing nominal, subtotal detail, plat, status bayar fixed invoice |
| Request edit pengurus | `lib/features/dashboard/presentation/dashboard_invoice_list_view.dart:1056` | Pengurus minta izin edit income |
| Build row gabungan income/expense | `lib/features/dashboard/presentation/dashboard_invoice_list_view.dart:4160` | Mapping data mentah ke row display |
| Build list UI | `lib/features/dashboard/presentation/dashboard_invoice_list_view.dart:4645` | Pull-to-refresh/list/card |
| Build page invoice list | `lib/features/dashboard/presentation/dashboard_invoice_list_view.dart:4762` | Filter tampil, search, tombol Cetak Laporan/Invoice |
| Tombol Cetak Laporan | `lib/features/dashboard/presentation/dashboard_invoice_list_view.dart:4882` | Buka popup print laporan |
| Tombol Cetak Invoice | `lib/features/dashboard/presentation/dashboard_invoice_list_view.dart:4892` | Buka popup print invoice |
| Card total display | `lib/features/dashboard/presentation/dashboard_invoice_list_widgets.dart:5` | Nilai total yang tampil di card |
| Card invoice/expense | `lib/features/dashboard/presentation/dashboard_invoice_list_widgets.dart:58`, `lib/features/dashboard/presentation/dashboard_invoice_list_widgets.dart:99` | Layout setiap card list |

## Invoice Preview dan Print dari Card

| Bagian | File/line | Untuk mengubah |
| --- | --- | --- |
| Preview income dialog | `lib/features/dashboard/presentation/dashboard_invoice_list_preview_support.dart:5` | Popup "Preview Income" |
| Judul preview income | `lib/features/dashboard/presentation/dashboard_invoice_list_preview_support.dart:53` | Title popup |
| Rincian preview income | `lib/features/dashboard/presentation/dashboard_invoice_list_preview_support.dart:75` | Blok detail invoice |
| Muatan di preview | `lib/features/dashboard/presentation/dashboard_invoice_list_preview_support.dart:127` | Label muatan, termasuk Tolakan |
| Harga / Kg di preview | `lib/features/dashboard/presentation/dashboard_invoice_list_preview_support.dart:134` | Label harga/kg |
| Entity label CV/PT/Pribadi | `lib/features/dashboard/presentation/dashboard_invoice_list_preview_support.dart:185`, `lib/features/dashboard/presentation/dashboard_invoice_list_preview_support.dart:213` | Penentuan tipe invoice |
| Nomor print invoice | `lib/features/dashboard/presentation/dashboard_invoice_list_preview_support.dart:259` | Format nomor print |
| Print invoice wrapper | `lib/features/dashboard/presentation/dashboard_invoice_list_preview_support.dart:356` | Memanggil renderer dashboard invoice |
| Legacy print invoice detail | `lib/features/dashboard/presentation/dashboard_invoice_list_preview_support.dart:486`, `lib/features/dashboard/presentation/dashboard_invoice_list_preview_support.dart:625` | Fallback lama bila tidak memakai delegate baru |
| Bold Tolakan di table PDF | `lib/features/dashboard/presentation/dashboard_invoice_list_preview_support.dart:1473` | Cell muatan Tolakan bold |
| Column width preview print | `lib/features/dashboard/presentation/dashboard_invoice_list_preview_support.dart:1979` | Lebar tabel income PDF |
| Preview expense dialog | `lib/features/dashboard/presentation/dashboard_invoice_list_preview_support.dart:2423` | Popup "Preview Expense" |
| Print expense PDF | `lib/features/dashboard/presentation/dashboard_invoice_list_preview_support.dart:2046` | Layout PDF expense |
| Cell PDF umum | `lib/features/dashboard/presentation/dashboard_invoice_list_preview_support.dart:2371` | Font/bold/alignment cell PDF |

## Edit Income dan Edit Expense

| Bagian | File/line | Untuk mengubah |
| --- | --- | --- |
| Extension edit support | `lib/features/dashboard/presentation/dashboard_invoice_list_edit_support.dart:3` | Semua helper edit income/expense |
| Popup edit income | `lib/features/dashboard/presentation/dashboard_invoice_list_edit_support.dart:4` | Buka dialog edit income |
| Resolve rule harga | `lib/features/dashboard/presentation/dashboard_invoice_list_edit_support.dart:43` | Auto harga saat edit |
| Resolve subtotal flat | `lib/features/dashboard/presentation/dashboard_invoice_list_edit_support.dart:82` | Subtotal manual/flat |
| Dialog edit income | `lib/features/dashboard/presentation/dashboard_invoice_list_edit_support.dart:242`, `lib/features/dashboard/presentation/dashboard_invoice_list_edit_support.dart:267` | AlertDialog edit income |
| Field tanggal selesai | `lib/features/dashboard/presentation/dashboard_invoice_list_edit_support.dart:781` | Tanggal selesai edit income |
| Field tonase | `lib/features/dashboard/presentation/dashboard_invoice_list_edit_support.dart:835` | Tonase boleh kosong/manual |
| Field Harga / Kg | `lib/features/dashboard/presentation/dashboard_invoice_list_edit_support.dart:856` | Label harga/kg edit income |
| Field subtotal manual | `lib/features/dashboard/presentation/dashboard_invoice_list_edit_support.dart:883` | Input subtotal manual edit income |
| Field status income | `lib/features/dashboard/presentation/dashboard_invoice_list_edit_support.dart:979` | Ubah Paid/Unpaid/etc |
| Field diterima oleh | `lib/features/dashboard/presentation/dashboard_invoice_list_edit_support.dart:996` | Diterima oleh admin/owner |
| Tombol batal edit income | `lib/features/dashboard/presentation/dashboard_invoice_list_edit_support.dart:1032` | Tombol bawah popup |
| Save detail income | `lib/features/dashboard/presentation/dashboard_invoice_list_edit_support.dart:1262` sampai `lib/features/dashboard/presentation/dashboard_invoice_list_edit_support.dart:1350` | Payload rincian update |
| Tombol simpan edit income | `lib/features/dashboard/presentation/dashboard_invoice_list_edit_support.dart:1501` | Submit update invoice |
| Popup edit expense | `lib/features/dashboard/presentation/dashboard_invoice_list_edit_support.dart:1526` | Buka dialog edit expense |
| Dialog edit expense | `lib/features/dashboard/presentation/dashboard_invoice_list_edit_support.dart:1562`, `lib/features/dashboard/presentation/dashboard_invoice_list_edit_support.dart:1573` | AlertDialog edit expense |
| Field status expense | `lib/features/dashboard/presentation/dashboard_invoice_list_edit_support.dart:1678` | Status expense manual |
| Tombol batal edit expense | `lib/features/dashboard/presentation/dashboard_invoice_list_edit_support.dart:1731` | Tombol bawah popup |
| Tombol simpan edit expense | `lib/features/dashboard/presentation/dashboard_invoice_list_edit_support.dart:1868` | Submit update expense |

## Popup Cetak Invoice

| Bagian | File/line | Untuk mengubah |
| --- | --- | --- |
| Open selector print invoice | `lib/features/dashboard/presentation/dashboard_invoice_list_print_selector.dart:4` | Popup filter dan pilih invoice |
| Build nomor otomatis group | `lib/features/dashboard/presentation/dashboard_invoice_list_print_selector.dart:134` | Generate nomor invoice untuk grup |
| Editor nomor/KOP | `lib/features/dashboard/presentation/dashboard_invoice_list_print_selector.dart:232` | Popup edit nomor, tanggal KOP, lokasi KOP |
| Filter row invoice | `lib/features/dashboard/presentation/dashboard_invoice_list_print_selector.dart:496` | Filter bulan, tahun, CV/PT/Pribadi, search |
| Width popup selector | `lib/features/dashboard/presentation/dashboard_invoice_list_print_selector.dart:526` | Lebar popup Cetak Invoice |
| Build selected groups | `lib/features/dashboard/presentation/dashboard_invoice_list_print_selector.dart:792` | Menggabungkan invoice yang dipilih |
| Save fixed batch setelah print | `lib/features/dashboard/presentation/dashboard_invoice_list_print_selector.dart:872` | Simpan metadata fix invoice |
| Print queue | `lib/features/dashboard/presentation/dashboard_invoice_list_print_selector.dart:807` sampai `lib/features/dashboard/presentation/dashboard_invoice_list_print_selector.dart:929` | Jalankan PDF print per group |
| Support grouping | `lib/features/dashboard/presentation/dashboard_invoice_list_print_group_support.dart:163` | Group invoice by customer/entity |
| Sort Tolakan pair | `lib/features/dashboard/presentation/dashboard_invoice_list_print_group_support.dart:33`, `lib/features/dashboard/presentation/dashboard_invoice_list_print_group_support.dart:59` | Urutan Tolakan dengan pasangan invoice |
| Expand print details | `lib/features/dashboard/presentation/dashboard_invoice_list_print_group_support.dart:148` | Detail yang masuk PDF |
| Generate nomor print | `lib/features/dashboard/presentation/dashboard_invoice_list_print_group_support.dart:266` | Nomor invoice per group |
| Editor single invoice | `lib/features/dashboard/presentation/dashboard_invoice_list_print_group_support.dart:504` | Print dari preview 1 invoice |
| Resolve latest invoice | `lib/features/dashboard/presentation/dashboard_invoice_list_print_group_support.dart:708` | Fetch ulang sebelum print |
| Print single from preview | `lib/features/dashboard/presentation/dashboard_invoice_list_print_group_support.dart:735` | Alur print dari popup preview |

## Print Invoice/PDF Renderer

| Bagian | File/line | Untuk mengubah |
| --- | --- | --- |
| Render result model | `lib/features/dashboard/presentation/dashboard_invoice_printing.dart:3` | Info hasil render tabel |
| Host/delegate print | `lib/features/dashboard/presentation/dashboard_invoice_printing.dart:205`, `lib/features/dashboard/presentation/dashboard_invoice_printing.dart:222` | Kontrak print dari page |
| Column width invoice | `lib/features/dashboard/presentation/dashboard_invoice_printing.dart:270` | Lebar tabel invoice |
| Main print function | `lib/features/dashboard/presentation/dashboard_invoice_printing.dart:372` | Layout final PDF invoice |
| Batas setengah lembar | `lib/features/dashboard/utils/invoice_print_layout_logic.dart:1`, `lib/features/dashboard/presentation/dashboard_invoice_printing.dart:400` | `CV/PT` 18 baris, personal 21 baris |
| Pilihan portrait/half sheet | `lib/features/dashboard/utils/invoice_print_layout_logic.dart:19`, `lib/features/dashboard/presentation/dashboard_invoice_printing.dart:403` | Kalau baris lebih dari limit masuk portrait |
| Jumlah row half sheet | `lib/features/dashboard/utils/invoice_print_layout_logic.dart:10`, `lib/features/dashboard/presentation/dashboard_invoice_printing.dart:508` | Row kosong/padding saat compact |
| Printable rows | `lib/features/dashboard/presentation/dashboard_invoice_printing.dart:512` | Row yang dikirim ke tabel |
| Render image Excel/cloud/portable | `lib/features/dashboard/presentation/dashboard_invoice_printing.dart:553` | Orkestrasi render tabel |
| Build invoice content | `lib/features/dashboard/presentation/dashboard_invoice_printing.dart:650` | KOP, tabel, summary, footer |
| Table header | `lib/features/dashboard/presentation/dashboard_invoice_printing.dart:1074` | Header tabel invoice |
| Table body | `lib/features/dashboard/presentation/dashboard_invoice_printing.dart:1186` | Body row PDF |
| Compact image branch | `lib/features/dashboard/presentation/dashboard_invoice_printing.dart:1870` | Pakai image Excel kalau compact |
| Portrait branch | `lib/features/dashboard/presentation/dashboard_invoice_printing.dart:1876` | Split sheet portrait |
| Margin PDF | `lib/features/dashboard/presentation/dashboard_invoice_printing.dart:1897` | Margin compact/portrait |
| Preview dialog print | `lib/features/dashboard/presentation/dashboard_invoice_printing.dart:1964`, `lib/features/dashboard/presentation/dashboard_invoice_printing.dart:2866` | Popup preview PDF |
| Local Excel render | `lib/features/dashboard/presentation/dashboard_invoice_printing.dart:2292` | Render via Excel/local |
| Cloud render service | `lib/features/dashboard/presentation/dashboard_invoice_printing.dart:2379` | Render via service |
| Portable fallback | `lib/features/dashboard/presentation/dashboard_invoice_printing.dart:2470` | Render tabel tanpa Excel/service |
| Assets KOP | `assets/images/kopsurat.jpeg`, `assets/images/kopsuratpt.png` | Header CV/PT invoice |
| Template tabel | `assets/templates/invoice_table_template.xlsx` | Template Excel invoice compact |
| Cloud service Python | `services/invoice_render_service/app.py` | Service render invoice table |

## Popup Cetak Laporan

| Bagian | File/line | Untuk mengubah |
| --- | --- | --- |
| Open report summary | `lib/features/dashboard/presentation/dashboard_invoice_list_report_summary.dart:4` | Popup Cetak Laporan |
| Fetch fixed invoice/report source | `lib/features/dashboard/presentation/dashboard_invoice_list_report_summary.dart:4` sampai `lib/features/dashboard/presentation/dashboard_invoice_list_report_summary.dart:300` | Data income/expense untuk laporan |
| Deteksi expense auto sangu | `lib/features/dashboard/presentation/dashboard_invoice_list_report_summary.dart:310` | Klasifikasi sangu |
| Deteksi expense gabungan | `lib/features/dashboard/presentation/dashboard_invoice_list_report_summary.dart:314` | Klasifikasi gabungan |
| Deteksi income gabungan | `lib/features/dashboard/presentation/dashboard_invoice_list_report_summary.dart:355` | Armada manual/gabungan |
| Harga gabungan laporan | `lib/features/dashboard/presentation/dashboard_invoice_list_report_summary.dart:504` | Fallback harga/kg gabungan di laporan |
| Laba gabungan laporan | `lib/features/dashboard/presentation/dashboard_invoice_list_report_summary.dart:620` | Perhitungan laba gabungan |
| Build rows laporan | `lib/features/dashboard/presentation/dashboard_invoice_list_report_summary.dart:1189` | Row final tabel laporan |
| Add income detail row | `lib/features/dashboard/presentation/dashboard_invoice_list_report_summary.dart:1328` | Detail income per invoice |
| Add expense row | `lib/features/dashboard/presentation/dashboard_invoice_list_report_summary.dart:1667` | Expense masuk laporan |
| Print report PDF | `lib/features/dashboard/presentation/dashboard_invoice_list_report_summary.dart:1701` | Build PDF laporan |
| Header laporan | `lib/features/dashboard/presentation/dashboard_invoice_list_report_summary.dart:1905` | Header PDF laporan |
| Summary box laporan | `lib/features/dashboard/presentation/dashboard_invoice_list_report_summary.dart:1987` | Total income/expense/laba |
| Preview rows popup | `lib/features/dashboard/presentation/dashboard_invoice_list_report_summary.dart:2249` | Table preview sebelum print |
| All rows final | `lib/features/dashboard/presentation/dashboard_invoice_list_report_summary.dart:2980` | Rows final sebelum print |
| Print action | `lib/features/dashboard/presentation/dashboard_invoice_list_report_summary.dart:3018` | Trigger print PDF |
| Report grouping utils | `lib/features/dashboard/utils/report_grouping_logic.dart:17` | Sort/group invoice report |

## Add Income Page

| Bagian | File/line | Untuk mengubah |
| --- | --- | --- |
| Widget root | `lib/features/dashboard/presentation/dashboard_create_income_view.dart:3` | Page Add Income |
| State | `lib/features/dashboard/presentation/dashboard_create_income_view.dart:22` | Controller/form state |
| Manual armada/driver constants | `lib/features/dashboard/presentation/dashboard_create_income_view.dart:24` | Opsi input manual |
| New detail row key | `lib/features/dashboard/presentation/dashboard_create_income_view.dart:118` | Key detail supaya field tidak kacau |
| Save income | `lib/features/dashboard/presentation/dashboard_create_income_view.dart:331` | Validasi dan payload create invoice |
| Detail payload | `lib/features/dashboard/presentation/dashboard_create_income_view.dart:459` | Rincian yang masuk database |
| Manual subtotal payload | `lib/features/dashboard/presentation/dashboard_create_income_view.dart:481`, `lib/features/dashboard/presentation/dashboard_create_income_view.dart:499` | Simpan subtotal manual |
| Build page | `lib/features/dashboard/presentation/dashboard_create_income_view.dart:685` | Layout Add Income |
| Customer/entity mode | `lib/features/dashboard/presentation/dashboard_create_income_view.dart:843` | CV/PT/Pribadi dan customer input |
| Lokasi muat manual | `lib/features/dashboard/presentation/dashboard_create_income_view.dart:902` sampai `lib/features/dashboard/presentation/dashboard_create_income_view.dart:982` | Field lokasi muat/manual |
| Armada dropdown/manual | `lib/features/dashboard/presentation/dashboard_create_income_view.dart:1057` sampai `lib/features/dashboard/presentation/dashboard_create_income_view.dart:1154` | Armada, gabungan/manual |
| Driver dropdown/manual | `lib/features/dashboard/presentation/dashboard_create_income_view.dart:1165` sampai `lib/features/dashboard/presentation/dashboard_create_income_view.dart:1244` | Nama supir |
| Tanggal muat/selesai | `lib/features/dashboard/presentation/dashboard_create_income_view.dart:1253`, `lib/features/dashboard/presentation/dashboard_create_income_view.dart:1271` | Date picker detail |
| Field Harga / Kg | `lib/features/dashboard/presentation/dashboard_create_income_view.dart:1391`, `lib/features/dashboard/presentation/dashboard_create_income_view.dart:1436` | Label harga/kg |
| Field subtotal manual | `lib/features/dashboard/presentation/dashboard_create_income_view.dart:1454`, `lib/features/dashboard/presentation/dashboard_create_income_view.dart:1463` | Input subtotal manual |
| Tampilan subtotal | `lib/features/dashboard/presentation/dashboard_create_income_view.dart:1482` | Text subtotal live |
| Tambah/hapus detail | `lib/features/dashboard/presentation/dashboard_create_income_view.dart:1488`, `lib/features/dashboard/presentation/dashboard_create_income_view.dart:1503` | Rincian dinamis |
| Subtotal invoice | `lib/features/dashboard/presentation/dashboard_create_income_view.dart:1509` | Total semua rincian |
| Due date | `lib/features/dashboard/presentation/dashboard_create_income_view.dart:1545` | Date picker jatuh tempo |
| Tombol simpan | `lib/features/dashboard/presentation/dashboard_create_income_view.dart:1591` | Submit create income |
| Resolve flat subtotal | `lib/features/dashboard/presentation/dashboard_create_income_support.dart:128` | Auto subtotal dari rule |
| Apply harga rule ke row | `lib/features/dashboard/presentation/dashboard_create_income_support.dart:152` | Isi harga/subtotal otomatis |
| Manual armada detection | `lib/features/dashboard/presentation/dashboard_create_income_support.dart:263` | Deteksi Gabungan/manual |
| Pick date support | `lib/features/dashboard/presentation/dashboard_create_income_support.dart:431`, `lib/features/dashboard/presentation/dashboard_create_income_support.dart:444` | Date picker detail/due |
| New detail default | `lib/features/dashboard/presentation/dashboard_create_income_support.dart:457` | Default field detail |
| Detail subtotal logic | `lib/features/dashboard/utils/invoice_detail_amount_logic.dart:1`, `lib/features/dashboard/presentation/dashboard_create_income_support.dart:482` | Parsing angka, tonase x harga/manual subtotal |
| Duplicate checker | `lib/features/dashboard/presentation/dashboard_create_income_support.dart:671`, `lib/features/dashboard/presentation/dashboard_create_income_support.dart:780` | Cegah data dobel |
| Add/remove detail support | `lib/features/dashboard/presentation/dashboard_create_income_support.dart:964`, `lib/features/dashboard/presentation/dashboard_create_income_support.dart:968` | Rincian dinamis |

## Add Expense Page

| Bagian | File/line | Untuk mengubah |
| --- | --- | --- |
| Widget root | `lib/features/dashboard/presentation/dashboard_create_expense_view.dart:3` | Page Add Expense |
| State | `lib/features/dashboard/presentation/dashboard_create_expense_view.dart:19` | Controller/form state |
| Next expense number | `lib/features/dashboard/presentation/dashboard_create_expense_view.dart:57` | Generate nomor expense |
| New detail | `lib/features/dashboard/presentation/dashboard_create_expense_view.dart:68` | Default rincian expense |
| Add/remove detail | `lib/features/dashboard/presentation/dashboard_create_expense_view.dart:75`, `lib/features/dashboard/presentation/dashboard_create_expense_view.dart:79` | Rincian dinamis |
| Preview number | `lib/features/dashboard/presentation/dashboard_create_expense_view.dart:88` | Nomor sementara |
| Save expense | `lib/features/dashboard/presentation/dashboard_create_expense_view.dart:94` | Validasi dan create expense |
| Build page | `lib/features/dashboard/presentation/dashboard_create_expense_view.dart:170` | Layout Add Expense |
| Rincian pengeluaran | `lib/features/dashboard/presentation/dashboard_create_expense_view.dart:202` | Section detail |
| Hapus detail | `lib/features/dashboard/presentation/dashboard_create_expense_view.dart:245` | Tombol hapus rincian |
| Tambah detail | `lib/features/dashboard/presentation/dashboard_create_expense_view.dart:260` | Tombol tambah rincian |
| Field status | `lib/features/dashboard/presentation/dashboard_create_expense_view.dart:273` | Status expense |
| Tombol simpan | `lib/features/dashboard/presentation/dashboard_create_expense_view.dart:308` | Submit expense |

## Fix Invoice Page

| Bagian | File/line | Untuk mengubah |
| --- | --- | --- |
| Widget root | `lib/features/dashboard/presentation/dashboard_fixed_invoice_view.dart:3` | Page Fix Invoice |
| State | `lib/features/dashboard/presentation/dashboard_fixed_invoice_view.dart:18` | State list fix invoice |
| Refresh fixed invoice | `lib/features/dashboard/presentation/dashboard_fixed_invoice_view.dart:136` | Sync/refresh data |
| Save fixed IDs | `lib/features/dashboard/presentation/dashboard_fixed_invoice_view.dart:314` | Cache IDs local |
| Save fixed batches | `lib/features/dashboard/presentation/dashboard_fixed_invoice_view.dart:343` | Cache batch local |
| Open batch preview | `lib/features/dashboard/presentation/dashboard_fixed_invoice_view.dart:1123` | Preview batch fix invoice |
| Load rows | `lib/features/dashboard/presentation/dashboard_fixed_invoice_view.dart:1489` | Fetch/merge fixed invoice |
| Build page | `lib/features/dashboard/presentation/dashboard_fixed_invoice_view.dart:1597` | Layout page |
| Refresh button | `lib/features/dashboard/presentation/dashboard_fixed_invoice_view.dart:1644` | Tombol refresh |
| Preview action | `lib/features/dashboard/presentation/dashboard_fixed_invoice_view.dart:1958` | Klik lihat batch |
| Fixed invoice support | `lib/features/dashboard/presentation/dashboard_fixed_invoice_support.dart:3`, `lib/features/dashboard/presentation/dashboard_invoice_support.dart:262` | Helper grouping legacy dan payment detail fixed invoice |
| Build legacy batch | `lib/features/dashboard/presentation/dashboard_fixed_invoice_support.dart:85` | Convert invoice lama ke batch |
| Build legacy batches | `lib/features/dashboard/presentation/dashboard_fixed_invoice_support.dart:145` | Group legacy fixed invoice |
| Batch/payment model | `lib/features/dashboard/presentation/dashboard_invoice_support.dart:27`, `lib/features/dashboard/presentation/dashboard_invoice_support.dart:157`, `lib/features/dashboard/presentation/dashboard_invoice_support.dart:236` | Struktur fixed invoice dan pembayaran |
| Payment entries | `lib/features/dashboard/presentation/dashboard_invoice_support.dart:428` | Detail pembayaran per invoice/detail |
| Merge/dedupe batches | `lib/features/dashboard/presentation/dashboard_invoice_support.dart:591`, `lib/features/dashboard/presentation/dashboard_invoice_support.dart:614` | Sinkron local/remote fixed invoice |

## Fleet, Armada, Order, Customer Registrations

| Page/fitur | File/line | Untuk mengubah |
| --- | --- | --- |
| Add fleet page | `lib/features/dashboard/presentation/dashboard_create_fleet_and_order_views.dart:3` | Page Tambah Armada |
| Save add fleet | `lib/features/dashboard/presentation/dashboard_create_fleet_and_order_views.dart:33` | Create armada |
| Build add fleet | `lib/features/dashboard/presentation/dashboard_create_fleet_and_order_views.dart:80` | Layout form tambah armada |
| Field status add fleet | `lib/features/dashboard/presentation/dashboard_create_fleet_and_order_views.dart:116` | Ready/Full/Inactive saat tambah |
| Save button add fleet | `lib/features/dashboard/presentation/dashboard_create_fleet_and_order_views.dart:131` | Submit tambah armada |
| Customer create order page | `lib/features/dashboard/presentation/dashboard_create_fleet_and_order_views.dart:149` | Page Order customer |
| Load order dependencies | `lib/features/dashboard/presentation/dashboard_create_fleet_and_order_views.dart:199` | Fetch armadas/profile |
| Pick order date | `lib/features/dashboard/presentation/dashboard_create_fleet_and_order_views.dart:206` | Date picker order |
| New order detail | `lib/features/dashboard/presentation/dashboard_create_fleet_and_order_views.dart:218` | Default detail muat/bongkar |
| Add/remove order detail | `lib/features/dashboard/presentation/dashboard_create_fleet_and_order_views.dart:227`, `lib/features/dashboard/presentation/dashboard_create_fleet_and_order_views.dart:231` | Rincian order |
| Pick detail order date | `lib/features/dashboard/presentation/dashboard_create_fleet_and_order_views.dart:236` | Tanggal detail order |
| Hydrate customer profile | `lib/features/dashboard/presentation/dashboard_create_fleet_and_order_views.dart:249` | Isi data profil otomatis |
| Save order | `lib/features/dashboard/presentation/dashboard_create_fleet_and_order_views.dart:258` | Create customer order |
| Build order page | `lib/features/dashboard/presentation/dashboard_create_fleet_and_order_views.dart:337` | Layout order |
| Section detail order | `lib/features/dashboard/presentation/dashboard_create_fleet_and_order_views.dart:444` | Rincian muat/bongkar/armada |
| Armada dropdown order | `lib/features/dashboard/presentation/dashboard_create_fleet_and_order_views.dart:485` | Pilihan armada customer |
| Submit order | `lib/features/dashboard/presentation/dashboard_create_fleet_and_order_views.dart:567` | Tombol simpan order |
| Fleet list page | `lib/features/dashboard/presentation/dashboard_admin_operations_views.dart:3` | Page Daftar Armada |
| Armada plate helper | `lib/features/dashboard/utils/armada_identifier_logic.dart:1`, `lib/features/dashboard/utils/armada_identifier_logic.dart:13`, `lib/features/dashboard/utils/armada_identifier_logic.dart:23` | Normalize plat, extract plat dari text, mapping armada |
| Load fleet list | `lib/features/dashboard/presentation/dashboard_admin_operations_views.dart:131` | Fetch armada dan usage |
| Refresh fleet list | `lib/features/dashboard/presentation/dashboard_admin_operations_views.dart:138` | Pull refresh |
| Open edit armada | `lib/features/dashboard/presentation/dashboard_admin_operations_views.dart:145` | Popup edit armada |
| Normalize fleet status | `lib/features/dashboard/presentation/dashboard_admin_operations_views.dart:152` | Ready/Full/Inactive |
| Status switch/dropdown | `lib/features/dashboard/presentation/dashboard_admin_operations_views.dart:217`, `lib/features/dashboard/presentation/dashboard_admin_operations_views.dart:231` | Toggle active dan status manual |
| Save edit armada | `lib/features/dashboard/presentation/dashboard_admin_operations_views.dart:294` | Payload update armada |
| Delete armada | `lib/features/dashboard/presentation/dashboard_admin_operations_views.dart:351` | Hapus armada |
| Build fleet list | `lib/features/dashboard/presentation/dashboard_admin_operations_views.dart:386` | Layout list armada |
| Card status armada | `lib/features/dashboard/presentation/dashboard_admin_operations_views.dart:530`, `lib/features/dashboard/presentation/dashboard_admin_operations_views.dart:553` | Status pill card |
| Edit/delete button card | `lib/features/dashboard/presentation/dashboard_admin_operations_views.dart:592`, `lib/features/dashboard/presentation/dashboard_admin_operations_views.dart:603` | Action card |
| Order acceptance page | `lib/features/dashboard/presentation/dashboard_admin_operations_views.dart:629` | Page Penerimaan Order |
| Load order acceptance | `lib/features/dashboard/presentation/dashboard_admin_operations_views.dart:659` | Fetch orders/customers/approval queue |
| Update order status | `lib/features/dashboard/presentation/dashboard_admin_operations_views.dart:667` | Accept/reject/update status |
| Open invoice create from order | `lib/features/dashboard/presentation/dashboard_admin_operations_views.dart:751` | Convert order jadi income |
| Build order acceptance | `lib/features/dashboard/presentation/dashboard_admin_operations_views.dart:832` | Layout list order |
| Status pill order | `lib/features/dashboard/presentation/dashboard_admin_operations_views.dart:915`, `lib/features/dashboard/presentation/dashboard_admin_operations_views.dart:1054` | Badge status order |
| Tombol status order | `lib/features/dashboard/presentation/dashboard_admin_operations_views.dart:1085`, `lib/features/dashboard/presentation/dashboard_admin_operations_views.dart:1102` | Aksi update order |
| Tombol buat invoice | `lib/features/dashboard/presentation/dashboard_admin_operations_views.dart:1121` | Buat income dari order |
| Customer registrations page | `lib/features/dashboard/presentation/dashboard_admin_operations_views.dart:1147` | Page registrasi customer |
| Build customer registrations | `lib/features/dashboard/presentation/dashboard_admin_operations_views.dart:1170` | Layout daftar customer |
| Role pill customer | `lib/features/dashboard/presentation/dashboard_admin_operations_views.dart:1218` | Badge role customer |

## Admin User, Role, Access

| Page/fitur | File/line | Untuk mengubah |
| --- | --- | --- |
| Add user page | `lib/features/dashboard/presentation/dashboard_admin_user_views.dart:3` | Page Tambah User |
| Save add user mock | `lib/features/dashboard/presentation/dashboard_admin_user_views.dart:40` | Simpan user UI saat ini |
| Build add user | `lib/features/dashboard/presentation/dashboard_admin_user_views.dart:70` | Layout tambah user |
| Submit add user | `lib/features/dashboard/presentation/dashboard_admin_user_views.dart:197` | Tombol save |
| Assign role page | `lib/features/dashboard/presentation/dashboard_admin_user_views.dart:213` | Page Assign Role |
| Build assign role | `lib/features/dashboard/presentation/dashboard_admin_user_views.dart:263` | Layout assign role |
| Role dropdown | `lib/features/dashboard/presentation/dashboard_admin_user_views.dart:392` | Pilihan role |
| Role access page | `lib/features/dashboard/presentation/dashboard_admin_user_views.dart:416` | Page Role Access |
| Add/edit role dialog | `lib/features/dashboard/presentation/dashboard_admin_user_views.dart:455` | Popup role |
| Role name input | `lib/features/dashboard/presentation/dashboard_admin_user_views.dart:480` | Nama role |
| Role save validation | `lib/features/dashboard/presentation/dashboard_admin_user_views.dart:536` | Validasi nama role |
| Delete role | `lib/features/dashboard/presentation/dashboard_admin_user_views.dart:580` | Hapus role |
| Build role access | `lib/features/dashboard/presentation/dashboard_admin_user_views.dart:602` | Layout role access |
| Add role button | `lib/features/dashboard/presentation/dashboard_admin_user_views.dart:647` | Tombol role baru |
| Edit/delete role row | `lib/features/dashboard/presentation/dashboard_admin_user_views.dart:722`, `lib/features/dashboard/presentation/dashboard_admin_user_views.dart:727` | Action role |
| Access denied | `lib/features/dashboard/presentation/dashboard_admin_user_views.dart:745` | Page akses ditolak |

## Calendar dan Notifications

| Page/fitur | File/line | Untuk mengubah |
| --- | --- | --- |
| Coming soon page | `lib/features/dashboard/presentation/dashboard_calendar_notifications_views.dart:3` | Placeholder page |
| Calendar page | `lib/features/dashboard/presentation/dashboard_calendar_notifications_views.dart:158` | Page Kalender |
| Load calendar | `lib/features/dashboard/presentation/dashboard_calendar_notifications_views.dart:180` | Fetch invoices/expenses/orders |
| Refresh calendar | `lib/features/dashboard/presentation/dashboard_calendar_notifications_views.dart:188` | Pull refresh |
| Build events | `lib/features/dashboard/presentation/dashboard_calendar_notifications_views.dart:195` | Mapping data ke event kalender |
| Group events by date | `lib/features/dashboard/presentation/dashboard_calendar_notifications_views.dart:649` | Kalender per tanggal |
| Sort events | `lib/features/dashboard/presentation/dashboard_calendar_notifications_views.dart:669` | Urutan event |
| Event color | `lib/features/dashboard/presentation/dashboard_calendar_notifications_views.dart:759` | Warna event |
| Open event dialog | `lib/features/dashboard/presentation/dashboard_calendar_notifications_views.dart:765` | Detail event saat diklik |
| Build calendar | `lib/features/dashboard/presentation/dashboard_calendar_notifications_views.dart:788` | Layout kalender |
| Event item tap | `lib/features/dashboard/presentation/dashboard_calendar_notifications_views.dart:950` | Klik event |
| Customer notifications page | `lib/features/dashboard/presentation/dashboard_calendar_notifications_views.dart:1021` | Page Notifikasi customer |
| Load notifications | `lib/features/dashboard/presentation/dashboard_calendar_notifications_views.dart:1046` | Fetch order + customer_notifications |
| Mark read customer notif | `lib/features/dashboard/presentation/dashboard_calendar_notifications_views.dart:1060` | Tandai dibaca |
| Build notification items | `lib/features/dashboard/presentation/dashboard_calendar_notifications_views.dart:1075` | Mapping notifikasi |
| Build notifications page | `lib/features/dashboard/presentation/dashboard_calendar_notifications_views.dart:1174` | Layout list notifikasi |
| Empty state notif | `lib/features/dashboard/presentation/dashboard_calendar_notifications_views.dart:1201` | Teks jika kosong |
| Mark read button | `lib/features/dashboard/presentation/dashboard_calendar_notifications_views.dart:1274` | Tombol tandai dibaca |
| Calendar event model | `lib/features/dashboard/presentation/dashboard_calendar_notifications_views.dart:1297` | Model event kalender |

## Customer Pages dan Settings

| Page/fitur | File/line | Untuk mengubah |
| --- | --- | --- |
| Order history page | `lib/features/dashboard/presentation/dashboard_customer_views.dart:3` | Page Riwayat Order |
| Load order history | `lib/features/dashboard/presentation/dashboard_customer_views.dart:21` | Fetch order current user |
| Refresh order history | `lib/features/dashboard/presentation/dashboard_customer_views.dart:24` | Pull refresh |
| Pay order | `lib/features/dashboard/presentation/dashboard_customer_views.dart:31` | Payment order customer |
| Build order history | `lib/features/dashboard/presentation/dashboard_customer_views.dart:140` | Layout order history |
| Settings page | `lib/features/dashboard/presentation/dashboard_customer_views.dart:253` | Page Pengaturan |
| Fetch profile/init biometric | `lib/features/dashboard/presentation/dashboard_customer_views.dart:300`, `lib/features/dashboard/presentation/dashboard_customer_views.dart:333` | Load profil dan biometric |
| Toggle biometric | `lib/features/dashboard/presentation/dashboard_customer_views.dart:380` | Enable/disable biometric |
| Save profile | `lib/features/dashboard/presentation/dashboard_customer_views.dart:409` | Update profil |
| Save password | `lib/features/dashboard/presentation/dashboard_customer_views.dart:447` | Update password |
| Build settings | `lib/features/dashboard/presentation/dashboard_customer_views.dart:505` | Layout settings |
| Profile section | `lib/features/dashboard/presentation/dashboard_customer_views.dart:533` | Section profil akun |
| Username field | `lib/features/dashboard/presentation/dashboard_customer_views.dart:578` | Field username |
| Role display | `lib/features/dashboard/presentation/dashboard_customer_views.dart:613` | Teks role |
| Save profile button | `lib/features/dashboard/presentation/dashboard_customer_views.dart:620` | Tombol simpan profil |
| Biometric switch | `lib/features/dashboard/presentation/dashboard_customer_views.dart:702` | Toggle biometric UI |
| Change password section | `lib/features/dashboard/presentation/dashboard_customer_views.dart:713` | Section password |
| Current/new/confirm password | `lib/features/dashboard/presentation/dashboard_customer_views.dart:718`, `lib/features/dashboard/presentation/dashboard_customer_views.dart:737`, `lib/features/dashboard/presentation/dashboard_customer_views.dart:756` | Field password |
| Update password button | `lib/features/dashboard/presentation/dashboard_customer_views.dart:777` | Submit password |

## Data Layer Supabase

| Bagian | File/line | Untuk mengubah |
| --- | --- | --- |
| Repository utama | `lib/features/dashboard/data/dashboard_repository.dart:147` | Class induk semua part repository |
| Optional columns fallback | `lib/features/dashboard/data/dashboard_repository.dart:154` | Kolom optional invoice/expense/fixed batch |
| Current role | `lib/features/dashboard/data/dashboard_repository.dart:210`, `lib/features/dashboard/data/dashboard_repository.dart:224` | Resolve role admin/owner/pengurus/customer |
| Customer notification insert/read | `lib/features/dashboard/data/dashboard_repository.dart:313`, `lib/features/dashboard/data/dashboard_repository.dart:383` | Insert dan mark read notifikasi customer |
| Broadcast staff/customer push | `lib/features/dashboard/data/dashboard_repository.dart:399`, `lib/features/dashboard/data/dashboard_repository.dart:450` | RPC create_role_notifications/send-push |
| Notify pengurus income/edit | `lib/features/dashboard/data/dashboard_repository.dart:516`, `lib/features/dashboard/data/dashboard_repository.dart:563` | Notifikasi approval pengurus |
| Sync armada by end date | `lib/features/dashboard/data/dashboard_repository.dart:650` | Ready/Full berdasarkan invoice aktif |
| Normalize armada row | `lib/features/dashboard/data/dashboard_repository.dart:750` | Status armada default |
| Effective income details | `lib/features/dashboard/data/dashboard_repository.dart:885` | Normalisasi rincian invoice |
| Detail subtotal invoice | `lib/features/dashboard/utils/invoice_detail_amount_logic.dart:1`, `lib/features/dashboard/data/dashboard_repository.dart:1004` | Manual subtotal/subtotal_auto/tonase x harga terpusat |
| Manual armada detection | `lib/features/dashboard/utils/manual_armada_logic.dart:1`, `lib/features/dashboard/data/dashboard_repository.dart:1023` | Deteksi Gabungan/manual terpusat |
| Gabungan pricing utility | `lib/features/dashboard/utils/gabungan_pricing_rule_logic.dart:1` | Normalize rute, match DB rule, fallback harga/kg Gabungan |
| Tonase gabungan | `lib/features/dashboard/data/dashboard_repository.dart:1046` | Resolve tonase dari detail |
| Auto expense from income | `lib/features/dashboard/data/dashboard_repository.dart:1205` | Membuat/update expense Sangu dan Gabungan |
| Sync row auto expense | `lib/features/dashboard/data/dashboard_repository.dart:1264` | Insert/update/delete auto expense |
| Build detail gabungan expense | `lib/features/dashboard/data/dashboard_repository.dart:1414` | Detail expense kategori Gabungan |
| Backfill auto expense | `lib/features/dashboard/data/dashboard_repository.dart:1554` | Membuat auto expense untuk invoice lama |
| Sync tanggal invoice detail | `lib/features/dashboard/data/dashboard_repository.dart:1700` | Benahi tanggal detail tunggal |
| Backfill special income pricing | `lib/features/dashboard/data/dashboard_repository.dart:1783` | Update invoice lama sesuai rule harga |
| Sangu rules | `lib/features/dashboard/data/dashboard_repository.dart:1927`, `lib/features/dashboard/data/dashboard_repository.dart:1971` | Rule sangu sopir |
| Set armada status | `lib/features/dashboard/data/dashboard_repository.dart:2161`, `lib/features/dashboard/data/dashboard_repository.dart:2180` | Update status armada |
| Fetch invoices | `lib/features/dashboard/data/dashboard_repository_fetch.dart:4` | Fetch semua invoice |
| Fetch invoices by IDs | `lib/features/dashboard/data/dashboard_repository_fetch.dart:27` | Fetch fixed batch/detail |
| Fetch invoices since/scope | `lib/features/dashboard/data/dashboard_repository_fetch.dart:90`, `lib/features/dashboard/data/dashboard_repository_fetch.dart:110` | Fetch invoice list period |
| Fetch expenses | `lib/features/dashboard/data/dashboard_repository_fetch.dart:139` | Fetch expense |
| Fetch fixed invoice batches | `lib/features/dashboard/data/dashboard_repository_fetch.dart:203` | Fetch fixed invoices |
| Upsert/delete fixed batch | `lib/features/dashboard/data/dashboard_repository_fetch.dart:246`, `lib/features/dashboard/data/dashboard_repository_fetch.dart:306` | Save/hapus fixed invoice batch |
| Normalize legacy invoice numbers | `lib/features/dashboard/data/dashboard_repository_fetch.dart:322` | Migrasi format nomor |
| Fetch armadas | `lib/features/dashboard/data/dashboard_repository_fetch.dart:393` | Fetch list armada |
| Fetch invoice armada usage | `lib/features/dashboard/data/dashboard_repository_fetch.dart:453` | Usage armada di invoice |
| Fetch customer options income | `lib/features/dashboard/data/dashboard_repository_fetch.dart:477` | Dropdown autofill customer/rute |
| Fetch harga/kg rules | `lib/features/dashboard/data/dashboard_repository_fetch.dart:680` | Ambil `harga_per_ton_rules` |
| Fetch orders | `lib/features/dashboard/data/dashboard_repository_fetch.dart:717` | Fetch customer orders |
| Fetch customer profiles | `lib/features/dashboard/data/dashboard_repository_fetch.dart:738` | Registrasi customer |
| Fetch customer notifications | `lib/features/dashboard/data/dashboard_repository_fetch.dart:753` | Notifikasi in-app customer |
| Create invoice | `lib/features/dashboard/data/dashboard_repository_crud.dart:35` | Insert income/invoice |
| Insert single invoice | `lib/features/dashboard/data/dashboard_repository_crud.dart:288` | Payload invoice ke Supabase |
| Generate income invoice number | `lib/features/dashboard/data/dashboard_repository_crud.dart:555` | Nomor invoice income |
| Create expense | `lib/features/dashboard/data/dashboard_repository_crud.dart:611` | Insert expense |
| Create armada | `lib/features/dashboard/data/dashboard_repository_crud.dart:674` | Insert armada |
| Fetch invoice by ID | `lib/features/dashboard/data/dashboard_repository_crud.dart:707` | Detail invoice untuk edit |
| Update invoice | `lib/features/dashboard/data/dashboard_repository_crud.dart:732` | Update income/edit income |
| Update print meta bulk | `lib/features/dashboard/data/dashboard_repository_crud.dart:904` | Update no invoice/KOP setelah print |
| Delete invoice | `lib/features/dashboard/data/dashboard_repository_crud.dart:1006` | Hapus invoice |
| Fetch/update/delete expense | `lib/features/dashboard/data/dashboard_repository_crud.dart:1084`, `lib/features/dashboard/data/dashboard_repository_crud.dart:1101`, `lib/features/dashboard/data/dashboard_repository_crud.dart:1188` | CRUD expense |
| Generate expense number | `lib/features/dashboard/data/dashboard_repository_crud.dart:1136` | Nomor expense |
| Update/delete armada | `lib/features/dashboard/data/dashboard_repository_crud.dart:1196`, `lib/features/dashboard/data/dashboard_repository_crud.dart:1231` | CRUD armada |
| Create/update/pay order | `lib/features/dashboard/data/dashboard_repository_crud.dart:1239`, `lib/features/dashboard/data/dashboard_repository_crud.dart:1287`, `lib/features/dashboard/data/dashboard_repository_crud.dart:1301` | Order customer |
| Dispatch invoice delivery | `lib/features/dashboard/data/dashboard_repository_crud.dart:1348` | Kirim invoice ke customer/email |
| Update profile/password | `lib/features/dashboard/data/dashboard_repository_crud.dart:1409`, `lib/features/dashboard/data/dashboard_repository_crud.dart:1495` | Settings profile/password |
| Admin dashboard data | `lib/features/dashboard/data/dashboard_repository_dashboard.dart:185` | Load dashboard admin |
| Admin live sections | `lib/features/dashboard/data/dashboard_repository_dashboard.dart:252` | Refresh armada/activity |
| Customer dashboard data | `lib/features/dashboard/data/dashboard_repository_dashboard.dart:305` | Dashboard customer |
| Finance reminder summary | `lib/features/dashboard/data/dashboard_repository_dashboard.dart:4`, `lib/features/dashboard/data/dashboard_repository_dashboard.dart:16` | Ringkasan mingguan/bulanan |
| Pengurus approval queue | `lib/features/dashboard/data/dashboard_repository_pengurus.dart:4` | Queue Penerimaan Order |
| Count pending pengurus | `lib/features/dashboard/data/dashboard_repository_pengurus.dart:72` | Badge approval |
| Request edit pengurus | `lib/features/dashboard/data/dashboard_repository_pengurus.dart:77` | Minta izin edit |
| Approve/reject pengurus income | `lib/features/dashboard/data/dashboard_repository_pengurus.dart:96`, `lib/features/dashboard/data/dashboard_repository_pengurus.dart:160` | Approval income |
| Approve/reject edit request | `lib/features/dashboard/data/dashboard_repository_pengurus.dart:195`, `lib/features/dashboard/data/dashboard_repository_pengurus.dart:230` | Approval edit |
| Repository schema fallback | `lib/features/dashboard/data/dashboard_repository_support.dart:982`, `lib/features/dashboard/data/dashboard_repository_support.dart:1044`, `lib/features/dashboard/data/dashboard_repository_support.dart:1189` | Fallback kolom Supabase lama |
| Harga rule DB matching | `lib/features/dashboard/data/dashboard_repository_support.dart:1475` | Match harga/kg dari database |
| Apply pricing rule | `lib/features/dashboard/data/dashboard_repository_support.dart:1670` | Apply rule ke detail invoice |

## Pricing, PPH, Payment, Tolakan Utils

| Utility | File/line | Untuk mengubah |
| --- | --- | --- |
| Built-in income pricing | `lib/features/dashboard/utils/income_pricing_rule_logic.dart:99` | Rule fallback harga/kg customer/rute |
| Armada identifier | `lib/features/dashboard/utils/armada_identifier_logic.dart:1`, `lib/features/dashboard/utils/armada_identifier_logic.dart:13`, `lib/features/dashboard/utils/armada_identifier_logic.dart:23` | Normalize plat, extract plat, mapping ID/plat/nama armada |
| Fleet status | `lib/features/dashboard/utils/fleet_status_logic.dart:1`, `lib/features/dashboard/utils/fleet_status_logic.dart:38`, `lib/features/dashboard/utils/fleet_status_logic.dart:44` | Opsi dan normalisasi `Ready/Full/Inactive`, selectable armada |
| Invoice detail amount | `lib/features/dashboard/utils/invoice_detail_amount_logic.dart:1`, `lib/features/dashboard/utils/invoice_detail_amount_logic.dart:29`, `lib/features/dashboard/utils/invoice_detail_amount_logic.dart:70` | Parsing Rupiah/decimal, subtotal detail, total detail |
| Invoice print layout | `lib/features/dashboard/utils/invoice_print_layout_logic.dart:1`, `lib/features/dashboard/utils/invoice_print_layout_logic.dart:10`, `lib/features/dashboard/utils/invoice_print_layout_logic.dart:19` | Batas compact/portrait invoice print |
| Match lokasi selain Betoyo | `lib/features/dashboard/utils/income_pricing_rule_logic.dart:16`, `lib/features/dashboard/utils/income_pricing_rule_logic.dart:37` | Logic `Selain Betoyo` untuk MKP |
| Gabungan pricing | `lib/features/dashboard/utils/gabungan_pricing_rule_logic.dart:16`, `lib/features/dashboard/utils/gabungan_pricing_rule_logic.dart:53`, `lib/features/dashboard/utils/gabungan_pricing_rule_logic.dart:118` | Normalize rute, match rule DB, fallback harga/kg Gabungan |
| Manual armada/Gabungan | `lib/features/dashboard/utils/manual_armada_logic.dart:1`, `lib/features/dashboard/utils/manual_armada_logic.dart:19`, `lib/features/dashboard/utils/manual_armada_logic.dart:23` | Normalize label, deteksi row manual, label display |
| Expense classifier | `lib/features/dashboard/utils/expense_classifier_logic.dart:1`, `lib/features/dashboard/utils/expense_classifier_logic.dart:48`, `lib/features/dashboard/utils/expense_classifier_logic.dart:87` | Deteksi auto sangu/gabungan, marker invoice, token link |
| PPH 2 persen | `lib/features/dashboard/utils/invoice_pph_logic.dart:3`, `lib/features/dashboard/utils/invoice_pph_logic.dart:9`, `lib/features/dashboard/utils/invoice_pph_logic.dart:15` | Round, PPH, total setelah PPH |
| Payment rounding fixed invoice | `lib/features/dashboard/utils/payment_rounding_logic.dart` | Pembulatan sisa bayar |
| Payment status | `lib/features/dashboard/utils/payment_status_logic.dart:1`, `lib/features/dashboard/utils/payment_status_logic.dart:19`, `lib/features/dashboard/utils/payment_status_logic.dart:47` | Normalize `Paid/Partial/Unpaid`, cegah `Unpaid` terbaca paid, resolve status dari nominal |
| Report payment edit/default | `lib/features/dashboard/utils/report_payment_edit_logic.dart:3`, `lib/features/dashboard/utils/report_payment_edit_logic.dart:17`, `lib/features/dashboard/utils/report_payment_edit_logic.dart:34`, `lib/features/dashboard/utils/report_payment_edit_logic.dart:44`, `lib/features/dashboard/utils/report_payment_edit_logic.dart:50`, `lib/features/dashboard/utils/report_payment_edit_logic.dart:64` | Parsing/format nominal, default bayar/sisa, dan hasil input bayar/sisa di preview laporan |
| Report print selection/totals | `lib/features/dashboard/utils/report_print_selection_logic.dart:3`, `lib/features/dashboard/utils/report_print_selection_logic.dart:13`, `lib/features/dashboard/utils/report_print_selection_logic.dart:49` | Filter row terpilih, apply input bayar/sisa, dan total income/expense sebelum cetak PDF |
| Report grouping/sorting | `lib/features/dashboard/utils/report_grouping_logic.dart:17` | Urutan laporan per invoice |
| Report label/header | `lib/features/dashboard/utils/report_label_logic.dart:27`, `lib/features/dashboard/utils/report_label_logic.dart:70`, `lib/features/dashboard/utils/report_label_logic.dart:104` | Judul laporan, scope, dan preview info print laporan |
| Report period/date | `lib/features/dashboard/utils/report_period_logic.dart:1`, `lib/features/dashboard/utils/report_period_logic.dart:31`, `lib/features/dashboard/utils/report_period_logic.dart:38` | Nama bulan ID/EN, range bulan/tahun, label periode laporan |
| Report table layout/rows/widths/fonts/totals | `lib/features/dashboard/utils/report_table_layout_logic.dart:7`, `lib/features/dashboard/utils/report_table_layout_logic.dart:21`, `lib/features/dashboard/utils/report_table_layout_logic.dart:31`, `lib/features/dashboard/utils/report_table_layout_logic.dart:51`, `lib/features/dashboard/utils/report_table_layout_logic.dart:82`, `lib/features/dashboard/utils/report_table_layout_logic.dart:181`, `lib/features/dashboard/utils/report_table_layout_logic.dart:263`, `lib/features/dashboard/utils/report_table_layout_logic.dart:304`, `lib/features/dashboard/utils/report_table_layout_logic.dart:336`, `lib/features/dashboard/utils/report_table_layout_logic.dart:357`, `lib/features/dashboard/utils/report_table_layout_logic.dart:446` | Mode tabel, header PDF, isi row, preset lebar kolom, sizing font, highlight status bayar, indeks kolom numeric/date/text prioritas, dan baris total laporan |
| Sangu rule logic | `lib/features/dashboard/utils/sangu_rule_logic.dart` | Rule sangu sopir |
| Tolakan logic | `lib/features/dashboard/utils/tolakan_logic.dart` | Deteksi muatan Tolakan |

## Database, Supabase, Edge Functions

| Bagian | File/line | Untuk mengubah |
| --- | --- | --- |
| Rule harga/kg DB | `harga_per_ton_rules` di Supabase | Rule operasional live seperti Gabungan/SGM dikelola langsung di database |
| Rule sangu sopir DB | `sangu_driver_rules` di Supabase | Nominal sangu live dikelola langsung di database |
| Fallback harga/kg app | `lib/features/dashboard/utils/income_pricing_rule_logic.dart:99`, `lib/features/dashboard/utils/gabungan_pricing_rule_logic.dart:119` | Cadangan ketika rule DB belum tersedia di device |
| Fallback sangu app | `lib/features/dashboard/utils/sangu_rule_logic.dart:1` | Cadangan ketika rule DB belum tersedia di device |
| Finance reminder edge function | `supabase/functions/finance-reminder-push/index.ts` | Push mingguan/bulanan |
| Send push edge function | `supabase/functions/send-push/index.ts` | Kirim FCM/notifikasi role/user |
| Supabase config | `supabase/config.toml` | Local Supabase config |

## Notifications

| Bagian | File/line | Untuk mengubah |
| --- | --- | --- |
| Push target enum | `lib/core/notifications/push_notification_service.dart:20` | Target navigasi push |
| Push service | `lib/core/notifications/push_notification_service.dart:71` | Setup FCM/local notif |
| Initialize push | `lib/core/notifications/push_notification_service.dart:124` | Init Firebase/local notification |
| Permission prompt | `lib/core/notifications/push_notification_service.dart:189` | Izin notif |
| Bind session | `lib/core/notifications/push_notification_service.dart:193` | Bind user/role token |
| Finance reminder refresh | `lib/core/notifications/push_notification_service.dart:330`, `lib/core/notifications/push_notification_service.dart:334` | Jadwalkan ulang reminder |
| Weekly reminder | `lib/core/notifications/push_notification_service.dart:357` | Notif laporan mingguan |
| Monthly reminder | `lib/core/notifications/push_notification_service.dart:392` | Notif laporan bulanan |
| Reminder title/body | `lib/core/notifications/push_notification_service.dart:499`, `lib/core/notifications/push_notification_service.dart:517` | Copywriting reminder |
| Payload -> target | `lib/core/notifications/push_notification_service.dart:690` | Decode target notifikasi |
| Foreground remote notif | `lib/core/notifications/push_notification_service.dart:743` | Tampilkan notif saat app aktif |
| Android settings helper | `lib/core/notifications/android_device_settings_service.dart:4` | Autostart/battery/notification settings |

## Model Files

| Model | File/line | Untuk mengubah |
| --- | --- | --- |
| Dashboard metric | `lib/features/dashboard/models/dashboard_models.dart:1` | Total card |
| Monthly series | `lib/features/dashboard/models/dashboard_models.dart:13` | Grafik bulanan |
| Armada usage | `lib/features/dashboard/models/dashboard_models.dart:23` | Ringkasan armada |
| Transaction item | `lib/features/dashboard/models/dashboard_models.dart:35` | Recent/latest transaction card |
| Activity item | `lib/features/dashboard/models/dashboard_models.dart:63` | Recent activity |
| Dashboard bundle | `lib/features/dashboard/models/dashboard_models.dart:79` | Data dashboard admin |
| Live sections | `lib/features/dashboard/models/dashboard_models.dart:99` | Auto-refresh subset |
| Customer order summary | `lib/features/dashboard/models/dashboard_models.dart:109` | Dashboard customer |
| Customer dashboard bundle | `lib/features/dashboard/models/dashboard_models.dart:127` | Data dashboard customer |

## Asset Visual

| Asset | Untuk mengubah |
| --- | --- |
| `assets/images/iconapk.png` | Logo app/notifikasi/PDF |
| `assets/images/kopsurat.jpeg` | KOP invoice CV |
| `assets/images/kopsuratpt.png` | KOP invoice PT |
| `assets/images/logo.webp`, `assets/images/logo-light.webp` | Logo login/sidebar |
| `assets/images/notif.png` | Visual notifikasi |
| `assets/images/pp-admin.webp`, `assets/images/pp-owner.webp` | Avatar default role |
| `assets/templates/invoice_table_template.xlsx` | Template tabel print invoice |
| `assets/fonts/Inter-Regular.ttf`, `assets/fonts/Inter-Italic.ttf` | Font app/PDF |

## Checklist Saat Programmer Edit

| Jika mengubah | Wajib cek |
| --- | --- |
| Nama menu/page | `_menuLabel` di `dashboard_page.dart:455`, drawer icon di `dashboard_page.dart:1914`, body switch di `dashboard_page.dart:1398` |
| Field Add Income | Samakan juga Edit Income di `dashboard_invoice_list_edit_support.dart:4` dan Preview/Print di `dashboard_invoice_list_preview_support.dart:5` |
| Harga/kg atau rule rute | Update utils, repository support, patch SQL, dan report laba |
| Status armada | Update add fleet, edit fleet, repository update, dan status badge |
| Print invoice | Cek batas row, printable rows, table body, assets KOP, template xlsx |
| Notifikasi | Cek push service, repository insert notification, dashboard header, customer notifications page |
| Fixed invoice | Cek fixed view, invoice support payment model, repository fixed batch fetch/upsert |
| Database schema | Tambah patch SQL baru dan pastikan repository punya fallback kalau kolom belum ada |
