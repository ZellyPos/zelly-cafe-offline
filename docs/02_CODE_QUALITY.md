# Kod Sifati, Linting va Texnik Qarz

> Bog'liq: [`01_ARCHITECTURE.md`](01_ARCHITECTURE.md) · [`04_ROADMAP.md`](04_ROADMAP.md)

---

## 0. Joriy holat — 2026-08-18 ✅

| Ko'rsatkich | Avval (2026-08-07) | **Hozir** |
|---|---:|---:|
| `flutter analyze` | 393 issue | **10** (0 xato, 10 warning) |
| `withOpacity` (eskirgan) | 255 | **0** |
| `print()` ishlab chiqarish kodida | 72 | **0** |
| `use_build_context_synchronously` | 36 | **10** |
| O'lik kod / ishlatilmagan e'lonlar | 6 | **0** |
| Testlar | 6 fayl, **5 tasi yiqilardi** | 6 fayl, **67 test — hammasi o'tadi** |
| Linter qoidalari | default shablon | 10 qoida + 8 ta `error` darajasi |
| Git'da maxfiy fayllar | `.pem` × 2, `license.json` | kuzatuvdan chiqarildi |

**Qolgan 10 warning** — hammasi `cart_provider.dart` da: `BuildContext`
async metodlarga uzatiladi. To'g'ri yechim — provider'dan `BuildContext`ni
butunlay olib tashlash ([`04_ROADMAP.md`](04_ROADMAP.md) Bosqich 4). Ular
`warning` darajasida — ko'rinib turadi, lekin CI'ni to'xtatmaydi.

**Sifat qulfi.** Tuzatilgan har bir muammoning linti `analysis_options.yaml`
da `error` darajasiga ko'tarildi (`avoid_print`, `dead_code`,
`unused_element`, `constant_identifier_names`, ...) — ya'ni ular
**qaytib kela olmaydi**, kod kompilyatsiya bo'lmaydi.

---

<details>
<summary>Quyidagi bo'limlar — 2026-08-07 dagi dastlabki tahlil (tarix uchun)</summary>

## 1. `flutter analyze` natijasi: 393 ta issue

| Qoida | Soni | Jiddiylik | Izoh |
|-------|-----:|:---------:|------|
| `deprecated_member_use` (`withOpacity`) | **255** | info | `withOpacity` → `withValues()` ga o'tish kerak |
| `avoid_print` | **72** | info | Ishlab chiqarish kodida `print()` |
| `use_build_context_synchronously` | **36** | ⚠️ warning-darajali | Async'dan keyin `BuildContext` — real xato xavfi |
| `unnecessary_underscores` | 12 | info | Foydalanilmaydigan `_` parametrlar |
| `constant_identifier_names` | 5 | info | `IN`, `OUT`, `ADJUST` — camelCase emas |
| `unnecessary_non_null_assertion` | 3 | info | Keraksiz `!` |
| `dead_null_aware_expression` | 3 | info | Keraksiz `??` |
| `dead_code` | 3 | ⚠️ | Erishib bo'lmaydigan kod |
| `unused_element` / `unused_local_variable` | 3 | ⚠️ | O'lik kod (`_whereTime` va h.k.) |
| `curly_braces_in_flow_control_structures` | 1 | info | `if` bloksiz |

> **255 ta `withOpacity`** — bitta buyruq bilan (`dart fix`) yoki qidiruv-almashtirish
> bilan avtomatik tuzatiladi. Bu "quick win".

---

## 2. Eng muhim: `use_build_context_synchronously` (36 ta)

Bularning aksari `cart_provider.dart`da. `await`dan keyin `BuildContext`
ishlatilsa, widget allaqachon `dispose` bo'lgan bo'lishi mumkin →
runtime crash yoki `mounted` xatosi.

**Tuzatish namunasi:**
```dart
// ❌ noto'g'ri
await saveOrder();
Navigator.pop(context);           // context async'dan keyin

// ✅ to'g'ri
await saveOrder();
if (!context.mounted) return;
Navigator.pop(context);
```

Yaxshiroq: provider ichida `BuildContext` umuman ishlatilmasligi kerak
(qarang [`01_ARCHITECTURE.md`](01_ARCHITECTURE.md) §2.3).

---

## 3. Logging: 69 ta `print()` — lekin `AppLogger` bor

Loyihada professional `AppLogger` (fayl + zona xatolarini ushlash) mavjud,
ammo kodda hali **69 ta `print()`** qolgan (`database_helper.dart` failsafe
bloklarida va boshqa joylarda).

**Tavsiya:** barcha `print()` → `AppLogger.d/i/w/e()` ga almashtirish.
`avoid_print` lintini `error` darajasiga ko'tarib, regressiyani oldini olish.

---

## 4. Texnik qarz markerlari: 227 ta TODO/FIXME/HACK

Kod bazasida **227 ta** `TODO`/`FIXME`/`HACK`/`XXX` izoh bor. Bu ko'rsatkich
yig'ilib qolgan qarorlarni bildiradi.

**Tavsiya:** ularni ro'yxatga olib (masalan `docs/TECH_DEBT.md`), ustuvorlik
bo'yicha saralash; hech bo'lmasa har biriga sabab/muddat qo'shish.

---

## 5. Linter konfiguratsiyasi juda minimal

Hozirgi `analysis_options.yaml` faqat `package:flutter_lints/flutter.yaml`ni
ulaydi, qo'shimcha qoidalar yo'q. Global standart loyihalar ancha qattiqroq
qoidalar bilan ishlaydi.

**Tavsiya — kuchaytirilgan konfiguratsiya:**
```yaml
include: package:flutter_lints/flutter.yaml

analyzer:
  language:
    strict-casts: true
    strict-raw-types: true
  errors:
    avoid_print: error
    use_build_context_synchronously: error
    deprecated_member_use: warning
  exclude:
    - "**/*.g.dart"
    - build/**

linter:
  rules:
    - prefer_single_quotes
    - always_declare_return_types
    - require_trailing_commas
    - avoid_dynamic_calls
    - prefer_const_constructors
    - unawaited_futures
    - sort_child_properties_last
```

Yanada kuchliroq to'plam uchun `very_good_analysis` yoki `lints` paketini
ko'rib chiqish mumkin.

---

## 6. Nomlash va standart bo'lmagan joylar

- `pubspec.yaml`: `description: "A new Flutter project."` — default matn,
  o'zgartirilsin.
- `README.md`: Flutter default shabloni + `zelly-cafe-offline` takrorlangan
  qatorlar. To'liq qayta yozilsin (yoki `docs/`ga havola qilinsin).
- `models/inventory_models.dart`: `IN`, `OUT`, `ADJUST`, `RETURN` konstantalari
  camelCase emas → `inItems`/`out...` yoki `enum` ishlatish.
- Ildizda `{userdesktop}` nomli papka + `ZellySetup_1.0.0.exe` (build artefakti)
  repozitoriyada — olib tashlanishi kerak (build fayllari git'da bo'lmasligi kerak).

---

## 7. Testlar: 134 fayldan atigi 5 test

| Test fayli | Qamrov |
|------------|--------|
| `analytics_test.dart` | analytics |
| `cart_service_charge_test.dart` | savat hisob-kitobi |
| `inventory_test.dart` | ombor |
| `shift_test.dart` | smena (`print` ishlatadi — lint) |
| `widget_test.dart` | default |

Kritik biznes-logika (to'lov, chegirma, smena yopish, litsenziya) test bilan
himoyalanmagan. `DatabaseHelper`da `databasePathOverride` borligi test yozishni
osonlashtiradi — bundan foydalanish kerak.

**Maqsad:** avval kritik hisob-kitoblarni (to'lov, chegirma, soliq, smena
balansi) unit test bilan qoplash.

---

## 8. Tez g'alabalar (quick wins) — kamxarajat, ta'sir yuqori

| # | Ish | Ta'sir |
|---|-----|--------|
| 1 | `dart fix --apply` (withOpacity va boshqalar) | 255+ issue yo'qoladi |
| 2 | `print()` → `AppLogger` | 72 lint + izchil logging |
| 3 | `use_build_context_synchronously` tuzatish | crash xavfini kamaytiradi |
| 4 | `pubspec` + `README` matnini to'g'rilash | professional ko'rinish |
| 5 | `{userdesktop}/`, `.exe`, `.pem` ni git'dan olib tashlash | tozalik + xavfsizlik |
| 6 | Linter qoidalarini kuchaytirish | kelajakdagi regressiyani to'xtatadi |

Batafsil bosqichma-bosqich reja: [`04_ROADMAP.md`](04_ROADMAP.md).

</details>

---

## 9. Keyingi sifat maqsadi

Quyidagi lint qoidalari hali yoqilmagan (yoqilsa shuncha ogohlantirish
chiqadi). Har birini alohida ko'rib chiqish kerak — avtomatik tuzatib
bo'lmaydi:

| Qoida | Soni | Nima kerak |
|---|---:|---|
| `avoid_dynamic_calls` | ~100 | `Map<String, dynamic>` ustidagi chaqiruvlar — modellarni tiplashtirish bilan yo'qoladi |
| `unawaited_futures` | ~36 | Har biri "ataylab kutilmayapti"mi yoki unutilganmi — qo'lda tekshirish |
| `avoid_slow_async_io` | ~14 | `AppLogger`da ataylab async I/O — bu qoida bu loyihaga mos emas |

Ular `analysis_options.yaml` da izoh sifatida yozib qo'yilgan.
