# Global Standartlarga O'tish Rejasi (Roadmap)

> Bog'liq: [`01_ARCHITECTURE.md`](01_ARCHITECTURE.md) · [`02_CODE_QUALITY.md`](02_CODE_QUALITY.md) · [`03_SECURITY.md`](03_SECURITY.md)

Bu reja loyihani bosqichma-bosqich global standartlarga yaqinlashtiradi.
Har bir bosqich **mustaqil qiymat beradi** va oldingisini buzmaydi.
Prinsip: **kichik, xavfsiz qadamlar** — katta "big bang" refaktoring emas.

---

## Bosqich 0 — Xavfsizlik + tozalik · ✅ BAJARILDI (2026-08-18)

- [x] `private_key.pem`, `public_key.pem`, `license.json` git kuzatuvidan
      chiqarildi (`git rm --cached`); `.gitignore`ga `*.pem`, `*.key`,
      `*.p12`, `*.jks`, `secrets.json` qo'shildi
- [x] **API autentifikatsiyasi qayta yozildi** — taxmin qilinadigan
      `admin-token-<id>` o'rniga tasodifiy, muddatli, bekor qilinadigan token
      → [`01_ARCHITECTURE.md`](01_ARCHITECTURE.md) §4.6, [`API.md`](../API.md) §9
- [x] Login uchun brute-force himoyasi (5 urinish → 5 daqiqa blok)
- [x] PIN kodlar API javoblaridan olib tashlandi
- [x] Litsenziya imzosini `print()` bilan konsolga chiqarish olib tashlandi

**⚠️ Foydalanuvchi bajarishi kerak** (bu ishlarni avtomatik qilib bo'lmaydi,
chunki ular mijozlarga ta'sir qiladi — pastdagi "Qo'lda bajariladigan ishlar"
bo'limiga qarang):
- [ ] Git **tarixidan** kalitni tozalash (`git filter-repo`) + force-push
- [ ] RSA kalit juftligini yangilash va mijozlarga yangi litsenziya berish

---

## Bosqich 1 — Tez g'alabalar (kod sifati) · ✅ BAJARILDI (2026-08-18)

- [x] `dart fix --apply` + 225 ta `withOpacity` → `withValues(alpha:)`
- [x] Barcha 72 ta `print()` → `AppLogger.d/i/w/e()`
- [x] `use_build_context_synchronously`: 36 → **10** (qolgani `cart_provider`,
      Bosqich 4 refaktorini talab qiladi)
- [x] O'lik kod va ishlatilmagan e'lonlar o'chirildi
- [x] Enum nomlari camelCase (`MovementType.stockIn`, `PrinterType.usbLegacy`) —
      bazadagi qiymatlar `dbValue` orqali eski holida saqlandi
- [x] `analysis_options.yaml` kuchaytirildi: 10 lint qoidasi + 8 ta `error`
      darajasi (tuzatilgan muammo qaytib kela olmaydi)
- [x] **Yiqilgan 5 test tuzatildi** — testlar eskirgan sxemaga tayangan edi
      (`service_fee` → `service_total`, to'lovlar endi `order_payments` da)
- [x] `widget_test.dart` (Flutter shablonidagi "counter" testi) o'chirildi,
      o'rniga `api_auth_test.dart` — 9 ta xavfsizlik testi

**Natija:** `flutter analyze` 393 → **10** (0 xato). `flutter test`: **67/67 o'tadi**.
`flutter build windows` muvaffaqiyatli.

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
| 0 — Xavfsizlik | 1 kun | ✅ Bajarildi (2026-08-18) |
| 1 — Tez g'alabalar | 1–2 kun | ✅ Bajarildi (2026-08-18) |
| 2 — Data layer namunasi | 3–5 kun | ✅ Bajarildi (2026-08-07) |
| 3 — Tarqatish | 1–2 hafta | ✅ Bajarildi (2026-08-07) |
| 4 — God file'lar | 1–2 hafta | ⏳ **Keyingi ish** |
| 5 — Testlar/CI | davomiy | 🔄 Boshlandi (67 test) |

**Keyingi tavsiya — Bosqich 4**, `api_server.dart` dan boshlab: u endi
xavfsizlik qatlamiga ega, shuning uchun route'larga bo'lish xavfsiz.
Keyin `cart_provider` dan `BuildContext`ni olib tashlash (qolgan 10 warning).

---

## Kalit tarixdan tozalandi — 2026-08-18 ✅ (qisman)

### Bajarildi

`git filter-branch` bilan `private_key.pem`, `public_key.pem`,
`license.json` **butun tarixdan** olib tashlandi va ikkala remote'ga
force-push qilindi.

- Zaxira: `C:\Users\Muhammadi\Zelly\_zaxira\tezzro-backup.git` (mirror,
  eski tarix to'liq) + kalit fayllarning nusxasi
- 19 ta teg (`v1.0.0` … `v1.0.18`) saqlandi va qayta yozildi
- Lokal tekshiruv: `git rev-list --objects --all | grep private_key` — bo'sh
- Kod buzilmadi: 67 test o'tadi, `flutter analyze` o'zgarmadi

### 🔴 Lekin: eski commitlar GitHub'da HALI OCHIQ

Force-push'dan keyin ham GitHub **yetim qolgan (orphaned) commitlarni**
SHA bo'yicha to'g'ridan-to'g'ri berishda davom etadi:

```
https://raw.githubusercontent.com/ZellyPos/zelly-cafe-offline/82bcc4a/private_key.pem
→ 200 OK, kalit to'liq o'qiladi
```

Bu GitHub'ning ma'lum xatti-harakati — u o'chirilgan obyektlarni avtomatik
yig'ishtirmaydi. `git push --force` faqat *shoxobchalarni* (ref) o'zgartiradi,
serverdagi obyektlarni emas.

**Buni faqat GitHub Support to'liq o'chira oladi:**

1. https://support.github.com/ ga murojaat qiling
2. So'rov matni: *"Please run garbage collection / remove cached views for
   repository `ZellyPos/zelly-cafe-offline` (and `zellyuz/zellyoffline`).
   Sensitive data was force-pushed out of history but orphaned commits are
   still accessible by SHA."*
3. Eski commit SHA'larini ilova qiling: `82bcc4a`, `2e1490c`, `db545ce`,
   `5070b95`

### 🔴 2. RSA kalit juftligini yangilash — endi MAJBURIY

Repozitoriya **ochiq (public)** bo'lgani va kalit uzoq vaqt shu holatda
turgani uchun kalitni **kompromatsiya qilingan deb hisoblash kerak**.
GitHub'ni skanerlaydigan botlar maxfiy kalitlarni avtomatik yig'adi.
Tarixni tozalash bu faktni o'zgartirmaydi — u faqat kelajakdagi tasodifiy
topilishni to'xtatadi.

Ya'ni **hozir har kim soxta, "haqiqiy" ko'rinadigan litsenziya yasashi
mumkin**. Yagona haqiqiy yechim — kalitni almashtirish.

Qadamlar:
1. Yangi RSA juftlik generatsiya qiling (2048 bit yoki undan yuqori)
2. `lib/core/services/license_service.dart` dagi `_publicKey` konstantasini
   yangilang
3. Barcha faol mijozlar uchun yangi `license.json` generatsiya qiling
4. Yangi versiyani chiqaring va litsenziyalarni mijozlarga yuboring

> ⚠️ Bu **barcha mavjud mijoz litsenziyalarini bekor qiladi**. Shuning uchun
> yangi litsenziyalar tayyor bo'lgandan keyingina versiyani tarqating —
> aks holda mijozlarning ilovasi ochilmay qoladi.

**Yangi kalit qayerda turishi kerak:** faqat sizning kompyuteringizda,
git'dan tashqarida. `.gitignore` da `*.pem` bor, lekin eng ishonchlisi —
kalitni umuman loyiha papkasida saqlamaslik.

### Boshqa dasturchilar uchun

Tarix qayta yozilgani uchun eski nusxalar mos kelmaydi. Kimda repo klon
qilingan bo'lsa, qayta klon qilishi kerak:

```bash
# eski papkani o'chirib
git clone https://github.com/ZellyPos/zelly-cafe-offline.git
```

---

## Ishni qanday olib boramiz

Har bir bosqichda men (Claude):
1. Avval o'zgarishni tushuntiraman va reja beraman;
2. Kichik, tekshiriladigan qadamlarga bo'lib bajaraman;
3. Har qadamdan keyin `flutter analyze`/`flutter test` bilan tasdiqlayman;
4. Bu `docs/` fayllarini yangilab boraman (holat kuzatuvi).

Boshlash uchun ayting: **qaysi bosqichdan boshlaymiz?** (tavsiyam — Bosqich 0).
