# Global Standartlarga O'tish Rejasi (Roadmap)

> Bog'liq: [`01_ARCHITECTURE.md`](01_ARCHITECTURE.md) · [`02_CODE_QUALITY.md`](02_CODE_QUALITY.md) · [`03_SECURITY.md`](03_SECURITY.md)

Bu reja loyihani bosqichma-bosqich global standartlarga yaqinlashtiradi.
Har bir bosqich **mustaqil qiymat beradi** va oldingisini buzmaydi.
Prinsip: **kichik, xavfsiz qadamlar** — katta "big bang" refaktoring emas.

---

## Bosqich 0 — Darhol (xavfsizlik + tozalik) · ~1 kun

> Bularsiz keyingi ishlarni boshlash xavfli.

- [ ] `private_key.pem`, `public_key.pem`, `license.json`ni git'dan olib tashlash
      (`git rm --cached`) va `.gitignore`ga qo'shish → [`03_SECURITY.md`](03_SECURITY.md)
- [ ] RSA kalit juftligini yangilash (rotate) va private key build'ga
      kirmasligini tasdiqlash
- [ ] `{userdesktop}/` papkasi va `ZellySetup_*.exe` build artefaktlarini
      repodan olib tashlash
- [ ] `pubspec.yaml` `description` va `README.md`ni to'g'rilash (yoki `docs/`ga havola)

**Natija:** repozitoriya xavfsiz va toza.

---

## Bosqich 1 — Tez g'alabalar (kod sifati) · ~1–2 kun

> Kod o'zgarmaydi, faqat toza bo'ladi. Riska past.

- [ ] `dart fix --apply` — 255 ta `withOpacity` va boshqa deprecation'lar
- [ ] Barcha `print()` (69 ta) → `AppLogger` ga almashtirish
- [ ] `use_build_context_synchronously` (36 ta) — `if (!context.mounted) return;`
      qo'shish yoki context'ni async'dan chiqarish
- [ ] O'lik kodni o'chirish (`_whereTime`, `dead_code`, unused)
- [ ] `analysis_options.yaml`ni kuchaytirish → [`02_CODE_QUALITY.md`](02_CODE_QUALITY.md) §5
- [ ] `flutter analyze` **0 issue** bo'lguncha yetkazish

**Natija:** `flutter analyze` toza, CI'ga tayyor.

---

## Bosqich 2 — Data layer namunasi · ✅ BAJARILDI (2026-08-07)

> Bitta domenda to'g'ri patternni o'rnatamiz, keyin nusxalaymiz.

- [x] `lib/data/repositories/` papkasini yaratish (+ `BaseRepository<T>`)
- [x] **Namuna:** `CategoryRepository` (soddadan boshlab), keyin
      `ProductRepository` — provider va ekranlardagi SQL repo'ga ko'chirildi
- [x] Provider'larni repository orqali ishlashga o'tkazish
      (konstruktor injection: `Provider({Repo? repository})`)
- [~] DI: provider'lar repo'ni konstruktor orqali oladi (standart holatda o'zi
      yaratadi). `main.dart`da to'liq DI-grafik hali sozlanmagan — ixtiyoriy.
- [ ] `ProductRepository` uchun alohida unit test hali yozilmagan
      (`cart_service_charge_test` mavjud va o'tadi)

**Natija:** ergashish uchun tayyor namuna o'rnatildi; `flutter analyze` 0 xato.

---

## Bosqich 3 — Data layer'ni tarqatish · ✅ BAJARILDI (2026-08-07)

> Namunani qolgan domenlarga bosqichma-bosqich qo'llash.

- [x] Domen bo'yicha repository yaratish — **18 repozitoriy**: base, category,
      location, customer, waiter, table, user, saboy, developer, expense, order
      (cart), delivery, product, report, settings, printer + mavjud shift,
      inventory
- [x] **Ekranlardagi barcha to'g'ridan-to'g'ri SQL'ni yo'q qilish** (10 ta fayl) —
      `lib/features/` da endi 0 ta `DatabaseHelper`/`rawQuery`
- [x] Barcha 18 provider faqat repository'ga tayanadi (istisno:
      `connectivity_provider` — u remote data source'ning o'zi)
- [x] Qoida amalda: hech bir `features/*` fayli `DatabaseHelper`ni import qilmaydi
      (kelajakda CI'da grep-tekshiruvi bilan majburlash tavsiya etiladi)

**Natija:** izchil `UI → Provider → Repository → DataSource` arxitekturasi
joriy qilindi. ✅

---

## Bosqich 4 — "God file"larni bo'lish · ~1–2 hafta

- [ ] `api_server.dart` (2830) → modul bo'yicha route fayllari
- [ ] `printing_service.dart` (2221) → `ReceiptBuilder`, `ShiftReportBuilder`...
- [ ] `pos_screen.dart` (2422) → kichik widget'lar + logika service'ga
- [ ] `cart_provider.dart` (2043) → hisob-kitobni sof service'ga chiqarish
- [ ] `database_helper.dart` (2176) → `schema/` + `migrations/` fayllariga

**Natija:** hech bir fayl ~600 satrdan oshmaydi; SRP hurmat qilinadi.

---

## Bosqich 5 — Testlar va CI/CD · davomiy

- [ ] Kritik biznes-logikani unit test bilan qoplash (to'lov, chegirma,
      soliq, smena balansi, litsenziya)
- [ ] Repository'lar uchun integratsiya testlari
- [ ] GitHub Actions (yoki boshqa CI): `flutter analyze` + `flutter test`
      har push'da
- [ ] Test qamrovi maqsadini belgilash (masalan, kritik modullar uchun 70%+)

**Natija:** o'zgarishlar avtomatik tekshiriladi, regressiya kamayadi.

---

## Umumiy vaqt bahosi

| Bosqich | Taxminiy | Holat |
|---------|----------|:-----:|
| 0 — Xavfsizlik | 1 kun | ⏳ Bajarilmagan |
| 1 — Tez g'alabalar | 1–2 kun | ⏳ Bajarilmagan |
| 2 — Data layer namunasi | 3–5 kun | ✅ Bajarildi |
| 3 — Tarqatish | 1–2 hafta | ✅ Bajarildi |
| 4 — God file'lar | 1–2 hafta | ⏳ Bajarilmagan |
| 5 — Testlar/CI | davomiy | ⏳ Bajarilmagan |

> **Bajarildi:** Bosqich 2–3 (Data layer to'liq joriy qilindi, 18 repozitoriy,
> `flutter analyze` 0 xato). Batafsil: [`01_ARCHITECTURE.md`](01_ARCHITECTURE.md) §4.5.
>
> **Keyingi tavsiya:** Bosqich 0 (xavfsizlik — git'dagi RSA kalit) va Bosqich 1
> (tez g'alabalar) — eng kam xarajatda eng katta ta'sir. Keyin Bosqich 4–5.

---

## Ishni qanday olib boramiz

Har bir bosqichda men (Claude):
1. Avval o'zgarishni tushuntiraman va reja beraman;
2. Kichik, tekshiriladigan qadamlarga bo'lib bajaraman;
3. Har qadamdan keyin `flutter analyze`/`flutter test` bilan tasdiqlayman;
4. Bu `docs/` fayllarini yangilab boraman (holat kuzatuvi).

Boshlash uchun ayting: **qaysi bosqichdan boshlaymiz?** (tavsiyam — Bosqich 0).
