# Xavfsizlik Tahlili

> Bog'liq: [`00_OVERVIEW.md`](00_OVERVIEW.md) · [`04_ROADMAP.md`](04_ROADMAP.md)

---

## 0. Joriy holat — 2026-08-18

| Topilma | Holat |
|---|---|
| 🔴 Maxfiy kalit git'da | 🟡 **Qisman** — kuzatuvdan chiqarildi va `.gitignore`ga qo'shildi; **tarixda qoldi** (qarang §1) |
| 🔴 Kalit ilova build'iga kiradimi | ✅ **Yo'q** — `build/` da `.pem` topilmadi; `pubspec.yaml` assets'ida faqat `assets/images/` |
| 🔴 API tokeni taxmin qilinardi (`admin-token-1`) | ✅ **Hal qilindi** — tasodifiy, 12 soatlik, bekor qilinadigan token |
| 🔴 Ko'p endpoint autentifikatsiyani umuman tekshirmasdi | ✅ **Hal qilindi** — markazlashgan middleware |
| 🔴 `GET /users` PIN kodlarni qaytarardi | ✅ **Hal qilindi** — PIN javoblardan olib tashlandi |
| 🟡 PIN brute-force himoyasi yo'q | ✅ **Hal qilindi** — 5 urinish → 5 daqiqa blok |
| 🟡 Ofitsiant barcha hisobotlarni ko'ra olardi | ✅ **Hal qilindi** — rolga qarab bo'lindi |
| 🟡 SQL injection | ✅ **Xavf topilmadi** — barcha so'rovlar parametrlangan (qarang §3) |
| 🟡 HTTP (TLS yo'q) | ⏳ Ochiq — tarmoqni ajratish bilan yumshatiladi |
| 🟡 PIN'lar bazada ochiq matnda | ⏳ Ochiq — hash migratsiyasi kerak |

Batafsil: [`API.md`](../API.md) §2 va §8, [`01_ARCHITECTURE.md`](01_ARCHITECTURE.md) §4.6.

---

## 🔴 1. KRITIK: Maxfiy RSA kaliti git'ga commit qilingan

Loyiha ildizida va **git tarixida** quyidagi fayllar kuzatilmoqda:

```
private_key.pem     ← RSA MAXFIY KALIT (litsenziya imzolash)
public_key.pem
license.json
```

`git ls-files` bu fayllarni **kuzatilayotgan (tracked)** deb ko'rsatadi.

### Nega bu jiddiy?
Loyiha litsenziyalarni RSA bilan imzolaydi (`core/security/rsa_signer.dart`).
**Maxfiy kalit** — bu butun litsenziya tizimining ishonch ildizi. U ochiq
bo'lsa, istalgan odam **soxta, "haqiqiy" ko'rinadigan litsenziya** yaratishi
mumkin — ya'ni himoya butunlay yo'qoladi.

Repozitoriya bir marta boshqalarga (GitHub, hamkor, sobiq xodim) ko'rinсa,
kalit allaqachon oshkor bo'lgan hisoblanadi.

### Nima qilish kerak (tartib bilan)
1. **Kalitni git'dan olib tashlash:**
   ```bash
   git rm --cached private_key.pem public_key.pem license.json
   ```
2. `.gitignore`ga qo'shish:
   ```gitignore
   *.pem
   license.json
   *.env
   ```
3. **Eng muhimi — kalit juftligini YANGILASH (rotate).** Eski kalit
   kompromatsiya qilingan deb hisoblang, chunki u tarixda qolgan. Yangi juftlik
   yarating va imzolash tizimini yangi kalitga o'tkazing.
4. Git tarixidan butunlay o'chirish (agar repo baham ko'rilgan bo'lsa):
   `git filter-repo` yoki BFG Repo-Cleaner bilan.
5. Maxfiy kalitni **hech qachon** ilova bilan tarqatmaslik — u faqat
   litsenziya generatoringiz (ishlab chiquvchi tomonda) turishi kerak.
   Ilovaga faqat **public key** kiradi.

> Muhim savol: `private_key.pem` ilova build'iga (yetkazib beriladigan `.exe`)
> kirib ketmaganini tekshiring. Agar kirsa, har bir mijozda maxfiy kalit bor
> degani.

---

## ✅ 2. Lokal server autentifikatsiyasi — hal qilindi (2026-08-18)

**Topilgan muammo (o'sha paytdagidan ham jiddiyroq bo'lib chiqdi):**

```dart
'token': 'admin-token-${user['id']}',   // eski kod
```

Token oddiy, taxmin qilinadigan qator edi. Ya'ni **istalgan odam
`Authorization: Bearer admin-token-1` yuborib to'liq admin huquqini olardi** —
PIN kerak emas, brute-force kerak emas. Bundan tashqari:

- Token muddatsiz va bekor qilib bo'lmaydigan edi (xodim ishdan ketsa ham
  tokeni ishlardi);
- autentifikatsiya endpoint'lar **ichida qo'lda** bajarilgan — ko'p endpoint
  umuman tekshirmasdi;
- `GET /users` javobida **PIN kodlar** ochiq qaytarilardi;
- ofitsiant butun savdo hisobotini, mijozlar bazasini va xarajatlarni
  ko'ra olardi.

**Bajarilgan yechim** (`lib/core/server/auth_token_service.dart` +
`ApiServer._authMiddleware()`):

| Chora | Tafsilot |
|---|---|
| Tasodifiy token | `Random.secure()`, 32 bayt, base64url |
| Muddat | 12 soat, har so'rovda uzayadi (smena davomida qayta login yo'q) |
| Bekor qilish | `/auth/logout`; xodim o'chirilganda avtomatik |
| Markazlashgan tekshiruv | Bitta middleware — endpoint yozganda unutib bo'lmaydi |
| Brute-force | 5 daqiqada 5 urinish → 5 daqiqa blok (`429`) |
| Ma'lumot oqishi | PIN'lar javoblardan olib tashlandi |
| Rolga bo'lish | Hisobot/xodim/mijoz/xarajat — faqat admin/kassir |
| Ishonchsiz kirish | `waiter_id` endi faqat tokendan olinadi |

Qamrov: `test/api_auth_test.dart` — 9 test.

**Qolgan ochiq nuqtalar:** TLS yo'q (HTTP), PIN'lar bazada ochiq matnda.
Ikkalasi ham [`API.md`](../API.md) §8 da hujjatlangan.

---

## ✅ 3. SQL injection — xavf topilmadi

Butun `lib/` bo'yicha `rawQuery`/`rawInsert` chaqiruvlari tekshirildi.
Interpolatsiya (`$`) uchraydigan barcha joylar xavfsiz:

| Joy | Nima interpolatsiya qilinadi | Xavfsizmi |
|---|---|---|
| `inventory_service.dart:267` | `int` mahsulot ID'lari (ichki `Map` kalitlari) | ✅ Foydalanuvchi matni emas |
| `database_helper.dart:2392` | Kod tuzgan `WHERE` bandi — qiymatlar `?` orqali | ✅ |
| `inventory_repository.dart:1066` | `UNION ALL` qismlari — kod tuzadi | ✅ |
| `developer_repository.dart:59` | Jadval nomi (ichki ro'yxatdan) | ✅ Faqat dasturchi ekranida |

Foydalanuvchi kiritgan qiymatlar hamma joyda `?` parametri orqali uzatiladi.

> **Kuzatuvda ushlash kerak:** `DeveloperRepository.runRawQuery()` — ixtiyoriy
> SQL bajaradi. Bu ataylab qilingan (dasturchi konsoli) va API orqali
> **ochilmagan**, lekin kelajakda uni endpoint qilib chiqarmaslik kerak.

---

## 🟢 4. Ijobiy topilmalar

- Kodda **hardcoded parol/token/api-key topilmadi** (grep bo'yicha) — yaxshi.
- RSA + device fingerprint + time-tamper guard bilan o'ylangan litsenziya
  arxitekturasi mavjud (`core/security/`).
- Global xato ushlash (`runZonedGuarded`) — xatolar oshkor bo'lib ketmaydi.
- Bootstrap xato ekrani texnik tafsilotni foydalanuvchiga ko'rsatmaydi
  ("administratorga murojaat qiling").

---

## 5. Xavfsizlik bo'yicha ustuvor ro'yxat

| Ustuvorlik | Ish | Holat |
|:---------:|-----|:---:|
| 🔴 Darhol | `*.pem`, `license.json`ni git'dan olib tashlash + `.gitignore` | ✅ |
| 🔴 Darhol | Private key ilova build'iga kirmasligini tasdiqlash | ✅ |
| 🟡 Yaqinda | Server token muddati + PIN rate-limiting | ✅ |
| 🟡 Yaqinda | Barcha SQL parametrlangan ekanini audit qilish | ✅ |
| 🔴 **Sizdan** | Git **tarixidan** kalitni tozalash (`git filter-repo` + force-push) | ⏳ |
| 🔴 **Sizdan** | RSA kalit juftligini yangilash (mijoz litsenziyalariga ta'sir qiladi) | ⏳ |
| 🟡 Keyin | PIN'larni hash qilish (bcrypt) | ⏳ |
| 🟢 Keyin | Lokal TLS / shifrlangan ulanish | ⏳ |

Oxirgi ikki "sizdan" bandi bo'yicha qadamlar:
[`04_ROADMAP.md`](04_ROADMAP.md) → "Qo'lda bajariladigan ishlar".

> Eslatma: bu tahlil statik kod skani asosida. To'liq xavfsizlik auditi uchun
> `/security-review` skill'ini alohida ishga tushirish tavsiya etiladi.
