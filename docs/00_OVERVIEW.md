# Tezzro POS — Loyiha Umumiy Holati

> Oxirgi tahlil: 2026-08-07 · Versiya: `1.0.13` · Muallif: kod tahlili (Claude)

Bu hujjat loyihaning **hozirgi haqiqiy holatini** aks ettiradi (rejalashtirilgan
emas, balki kodda mavjud bo'lgani). Batafsil tahlil va tavsiyalar alohida
fayllarda:

- [`01_ARCHITECTURE.md`](01_ARCHITECTURE.md) — arxitektura tahlili va tavsiyalar
- [`02_CODE_QUALITY.md`](02_CODE_QUALITY.md) — kod sifati, linting, texnik qarz
- [`03_SECURITY.md`](03_SECURITY.md) — xavfsizlik topilmalari
- [`04_ROADMAP.md`](04_ROADMAP.md) — global standartlarga o'tish rejasi

---

## 1. Loyiha nima?

**Tezzro (Zelly) POS** — kafe/restoran uchun **Windows desktop** savdo nuqtasi
(Point of Sale) ilovasi. Offline ishlaydi, lokal SQLite bazasida ma'lumot
saqlaydi va lokal tarmoq orqali boshqa qurilmalar (masalan, ofitsiant
telefonlari) bilan HTTP/WebSocket server orqali bog'lanadi.

### Asosiy imkoniyatlar
| Modul | Tavsif |
|-------|--------|
| POS | Buyurtma qabul qilish, savat, chegirma, to'lov |
| Stollar (Tables) | Zal rejasi (floor plan), stol boshqaruvi |
| Yetkazib berish (Delivery) | Kuryer, hududlar, yetkazish buyurtmalari |
| Saboy | Olib ketish buyurtmalari |
| Ombor (Inventory) | Ingredientlar, retseptlar, zaxira harakati |
| Smena (Shift) | Ochish/yopish, kassa harakati, hisobot |
| Hisobotlar (Reports) | Dashboard, mahsulot/stol/ofitsiant/lokatsiya kesimida |
| Boshqaruv (Mgmt) | Mahsulot, kategoriya, mijoz, ofitsiant, xarajat, kassir |
| Litsenziya | RSA imzolangan offline litsenziya tizimi |
| Chop etish | Termal printer (USB/Bluetooth), chek/hisobot |
| Telegram | Bot orqali xabar/hisobot yuborish |
| Server | Lokal REST API + WebSocket (mobil integratsiya) |

---

## 2. Texnologiyalar to'plami

| Qatlam | Texnologiya |
|--------|-------------|
| Framework | Flutter (Dart SDK `^3.10.3`) |
| Platforma | Windows desktop (`window_manager`) |
| State management | **Provider** (`ChangeNotifier`) |
| Ma'lumotlar bazasi | SQLite (`sqflite_common_ffi`) |
| Server | `shelf` + `shelf_router` + `shelf_web_socket` |
| Chop etish | `blue_thermal_printer`, `esc_pos_utils_plus`, `printing`, `pdf` |
| Xavfsizlik | `pointycastle`, `crypto` (RSA litsenziya imzolash) |
| Eksport | `excel`, `pdf`, `share_plus` |
| Grafiklar | `fl_chart` |
| UI yordamchilar | `flutter_screenutil`, `google_fonts`, `flutter_onscreen_keyboard` |

---

## 3. Kod bazasi ko'lami

| Ko'rsatkich | Qiymat |
|-------------|--------|
| Dart fayllar soni | **134** |
| Umumiy kod satri (LOC) | **~59 500** |
| DB jadvallar (`CREATE TABLE`) | **60** |
| DB versiyasi (migratsiya) | **54** |
| Provider'lar | 19 |
| Model'lar | 22 |
| Repository'lar | **18** (data layer to'liq joriy qilindi ✅) |
| Ekranlar/feature fayllari | ~65 |
| Test fayllari | **5** (past qamrov) |

### Eng katta fayllar ("god files")
| Fayl | Satr |
|------|------|
| `lib/core/server/api_server.dart` | 2 830 |
| `lib/features/pos/pos_screen.dart` | 2 422 |
| `lib/core/printing_service.dart` | 2 221 |
| `lib/core/database_helper.dart` | 2 176 |
| `lib/providers/cart_provider.dart` | 2 043 |
| `lib/features/reports/screens/dashboard_screen.dart` | 1 779 |

> Bu fayllar Single Responsibility prinsipini buzadi va bo'lib yuborilishi
> kerak. Batafsil: [`01_ARCHITECTURE.md`](01_ARCHITECTURE.md).

---

## 4. Papka tuzilishi

```
lib/
├── main.dart                 # Bootstrap, MultiProvider, ilova ildizi
├── core/                     # Umumiy infratuzilma
│   ├── database_helper.dart  # SQLite (60 jadval, 54 migratsiya) — juda katta
│   ├── printing_service.dart # Termal chop etish
│   ├── theme.dart, translations.dart, app_strings.dart, app_logger.dart
│   ├── security/             # RSA imzo/tekshirish, device fingerprint
│   ├── server/               # api_server.dart, websocket_manager.dart
│   ├── services/             # license, shift, inventory, audit, analytics...
│   └── utils/
├── features/                 # Ekranlar (feature-first — yaxshi)
│   ├── pos/  tables/  delivery/  saboy/  inventory/  shift/
│   ├── reports/  mgmt/  settings/  login/  license/  main_layout/
├── models/                   # 22 ta model (immutable, toMap/fromMap) — toza
├── providers/                # 19 ta ChangeNotifier
├── repositories/             # FAQAT 2 ta (inventory, shift) — nomuvofiq
└── widgets/                  # (bo'sh / kam ishlatiladi)
```

**Ijobiy:** feature-first tuzilish, immutable modellar, markazlashgan logger,
theme va tarjima tizimi mavjud.

**Muammoli:** ma'lumotlarga kirish qatlami (data layer) yo'q — SQL kodi
provider va ekranlarga tarqalgan; bir nechta "god file" mavjud.

---

## 5. Ma'lumot oqimi (hozirgi holat)

```
UI (features/*)  ──►  Provider (ChangeNotifier)  ──►  DatabaseHelper (SQLite)
      │                      │                              ▲
      └──────── ba'zan to'g'ridan-to'g'ri SQL ─────────────┘  ⚠️ qatlam buzilishi
```

- 19 provider'dan **18 tasi** `DatabaseHelper`ga to'g'ridan-to'g'ri murojaat qiladi.
- **10 ta ekran** ham to'g'ridan-to'g'ri SQL (`rawQuery`/`DatabaseHelper`) ishlatadi.
- Faqat `inventory` va `shift` modullarida repository qatlami bor.

To'g'ri model: `UI → Provider → Repository → DataSource (SQLite/API)`.
Batafsil: [`01_ARCHITECTURE.md`](01_ARCHITECTURE.md).

---

## 6. Umumiy baho (qisqacha)

| Yo'nalish | Baho | Izoh |
|-----------|:----:|------|
| Funksionallik | 🟢 Kuchli | To'liq POS funksiyalari ishlaydi |
| Papka tuzilishi | 🟡 O'rta | Feature-first yaxshi, lekin data layer yo'q |
| Arxitektura izchilligi | 🟢 Yaxshilandi | Data layer joriy qilindi (18 repo); god files hali qoldi |
| Kod sifati / linting | 🟡 O'rta | 393 analyzer ogohlantirishi, minimal lint |
| Xavfsizlik | 🔴 Diqqat! | **Maxfiy RSA kalit git'da** ([`03_SECURITY.md`](03_SECURITY.md)) |
| Testlar | 🔴 Zaif | 134 fayldan atigi 5 ta test |
| Hujjatlashtirish | 🟡 O'rta | API.md bor, README default (endi bu docs) |

Keyingi qadamlar: [`04_ROADMAP.md`](04_ROADMAP.md).
