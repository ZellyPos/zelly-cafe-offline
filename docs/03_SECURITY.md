# Xavfsizlik Tahlili

> Bog'liq: [`00_OVERVIEW.md`](00_OVERVIEW.md) · [`04_ROADMAP.md`](04_ROADMAP.md)
> ⚠️ Bu hujjatda **darhol hal qilinishi kerak** bo'lgan topilma bor.

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

## 🟡 2. Lokal server (`api_server.dart`) autentifikatsiyasi

Server `Authorization: Bearer <token>` ishlatadi (`API.md`). Tekshirilishi
kerak bo'lgan nuqtalar:

- Token qanday yaratiladi va muddati bormi (expiry)?
- HTTP (shifrlanmagan) ishlatilyaptimi? Lokal tarmoqda ham PIN/token ochiq
  uzatilsa, xuddi shu Wi-Fi'dagi qurilma uni ushlashi mumkin.
- Rate limiting bormi (PIN brute-force'ga qarshi)?
- CORS sozlamalari qanchalik ochiq?

**Tavsiya:** token muddati + PIN uchun urinishlar chegarasi, imkon bo'lsa
lokal TLS yoki hech bo'lmasa token'ni qisqa muddatli qilish.

---

## 🟡 3. SQL injection xavfi

Kod bazasida `rawQuery`/`rawInsert` keng ishlatilgan (provider va ekranlarda).
Agar biror joyda foydalanuvchi kiritgan matn to'g'ridan-to'g'ri SQL satriga
qo'shilsa (string interpolation bilan), bu injection xavfini yaratadi.

**Tavsiya:** barcha so'rovlarda **parametrlangan** shakldan foydalanish:
```dart
// ✅ to'g'ri
db.rawQuery('SELECT * FROM products WHERE name = ?', [userInput]);
// ❌ xatarli
db.rawQuery("SELECT * FROM products WHERE name = '$userInput'");
```
Repository qatloviga o'tish (qarang [`01_ARCHITECTURE.md`](01_ARCHITECTURE.md))
bu tekshiruvni bitta joyga jamlaydi.

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

| Ustuvorlik | Ish |
|:---------:|-----|
| 🔴 Darhol | `*.pem`, `license.json`ni git'dan olib tashlash + `.gitignore` |
| 🔴 Darhol | RSA kalit juftligini yangilash (rotate) |
| 🔴 Darhol | Private key ilova build'iga kirmasligini tasdiqlash |
| 🟡 Yaqinda | Server token muddati + PIN rate-limiting |
| 🟡 Yaqinda | Barcha SQL parametrlangan ekanini audit qilish |
| 🟢 Keyin | Lokal TLS / shifrlangan ulanish |

> Eslatma: bu tahlil statik kod skani asosida. To'liq xavfsizlik auditi uchun
> `/security-review` skill'ini alohida ishga tushirish tavsiya etiladi.
