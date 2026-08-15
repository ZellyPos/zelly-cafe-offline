# Ombor bo'limi — foydalanuvchi qo'llanmasi

> Zelly POS · v1.0.14 dan boshlab
> Bu qo'llanma ombor bilan **kundalik ishlash** haqida. Texnik tafsilotlar
> uchun: [`ombor_final.md`](ombor_final.md), [`ombor_progress.md`](ombor_progress.md)

---

## 1. Asosiy tushuncha — ikki xil mahsulot

Ombor to'g'ri ishlashi uchun eng avval shuni tushunish kerak. Har bir mahsulot
ikki turdan biriga tegishli:

| | **Tayyorlanadi** | **Sotib olinadi** |
|---|---|---|
| Misol | Somsa, lag'mon, non | Coca-Cola, suv, sigaret |
| Retsepti | ✅ Bor (xomashyodan) | ❌ Yo'q |
| Qoldiq qanday to'ladi | **Pishirish** orqali | **Kirim** orqali |
| Sotuvda | Soni kamayadi | Soni kamayadi |

**Nima uchun muhim:** tayyorlanadigan mahsulotni pishirganingizda xomashyo
avtomatik chegiriladi. Sotib olinadigan mahsulotda retsept yo'q — uni shunchaki
kirim qilasiz.

### ⚠️ Birinchi ish — mahsulot turlarini to'g'rilash

Yangilanishdan keyin **barcha mahsulotlar "Tayyorlanadi"** deb belgilangan
bo'ladi. Ichimlik va shunga o'xshash sotib olinadiganlarni qo'lda o'tkazish
kerak, aks holda ular uchun "Kirim" tugmasi chiqmaydi.

**Qanday:** Ombor → Qoldiqlar → mahsulot ustiga bosing → yuqorida **"Turi"**
almashtirgichidan **"Sotib olinadi"** ni tanlang.

> Agar mahsulotda retsept bo'lsa, "Sotib olinadi" ga o'tkazishda u o'chiriladi —
> ilova buni oldindan so'raydi.

---

## 2. Ombor bo'limi qayerda

**Chap menyu → Sozlamalar → Ombor**

To'rtta bo'lim chiqadi:

| Bo'lim | Nima uchun |
|--------|-----------|
| **Qoldiqlar** | Nima qancha qolganini ko'rish · pishirish · mahsulot sozlash |
| **Kirim / Chiqim** | Xomashyo/mahsulot olib kelinganda yoki buzilganda |
| **Inventarizatsiya** | Oy oxirida sanab, tizimni haqiqatga tenglashtirish |
| **Harakatlar tarixi** | Kim, qachon, nima qilgan |

---

## 3. Boshlash — ketma-ketlik

Birinchi marta sozlayotgan bo'lsangiz, aynan shu tartibda boring. Har qadam
oldingisiga tayanadi.

### 1-qadam. Xomashyolarni kiritish

Ombor → **Qoldiqlar** → **"Xomashyolar"** tabi → yuqoridagi
**"Xomashyo qo'shish"** tugmasi.

Kiritiladi: **nomi**, **o'lchov birligi** (`g`, `ml`, `dona`), **min. miqdor**.

> **O'lchov birligi haqida:** retseptda ham shu birlik ishlatiladi. Go'shtni
> grammda yuritsangiz, retseptda ham gramm yozasiz. Keyinchalik o'zgartirish
> chalkashlik keltiradi — boshidan to'g'ri tanlang.

> **Min. miqdor** — shu darajadan pastga tushsa, qoldiq qizil rangda va "Kam"
> belgisi bilan ko'rinadi. 0 qo'ysangiz ogohlantirish bo'lmaydi.

### 2-qadam. Xomashyoni kirim qilish (tannarx bilan)

Ombor → **Kirim / Chiqim** → **"Kirim"** tugmasi tanlangan holda.

1. Ro'yxatdan kerakli xomashyolarni belgilang (bir nechtasini birdan bo'ladi)
2. Har biriga: **miqdor**, **tannarx** (1 birlik uchun), **kimdan olindi**
3. **"Kirim qilish"**

> **Tannarxni albatta kiriting.** Usiz food-cost hisoblanmaydi va mahsulot
> tannarxini bilmay qolasiz. Tannarx har kirimda **o'rtachaga** qo'shiladi:
> 100 kg ni 10 000 so'mdan, keyin 300 kg ni 20 000 so'mdan olsangiz, o'rtacha
> 17 500 bo'ladi.

### 3-qadam. Retsept yozish

Ombor → **Qoldiqlar** → mahsulot ustiga bosing → **Retsept** bloki.

1. **"Xomashyo qo'shish"** → ro'yxatdan tanlang
2. **Sarf miqdori** ni yozing
3. **"Bir retseptdan chiqadi"** — bir marta pishirganda nechta chiqadi
4. **"Saqlash"**

**"Bir retseptdan chiqadi" nima degani:** agar bir qozon lag'mondan 10 porsiya
chiqsa, bu yerga `10` yozib, xomashyoni **butun qozonga** kerak bo'lgan miqdorda
kiritasiz. Ilova 1 porsiyaga qanchadan ketishini o'zi hisoblaydi.

Misol — bir qozondan 10 porsiya:

| Xomashyo | Sarf (qozonga) |
|----------|----------------|
| Go'sht | 1500 g |
| Un | 2000 g |

Bir retseptdan chiqadi: **10** → 1 porsiyaga 150 g go'sht ketadi.

> Jadvalda har xomashyoning **omborda qanchaligi** va **min. miqdori** ham
> ko'rinadi — retsept yozayotib yetarli-yetarli emasligini darrov bilasiz.

### 4-qadam. Pishirish

Ertalab (yoki partiya tayyorlaganda) qilinadigan asosiy amal.

Ombor → **Qoldiqlar** → yuqorida **"Pishirish"** tugmasi.

1. Pishirilgan mahsulotlarni belgilang
2. Har biriga **nechta** tayyorlanganini yozing
3. **"Saqlash"**

Shunda: **xomashyo retsept bo'yicha chegiriladi**, **tayyor mahsulot soni
oshadi**.

> Bitta mahsulotni tez pishirish uchun uning kartasidagi 🔥 tugmasini bosing —
> modal o'sha mahsulot tanlangan holda ochiladi.

**Xomashyo yetmasa:** ilova qaysi xomashyo yetishmayotganini, qancha kerakligini
va qancha borligini ko'rsatadi. **Hech narsa saqlanmaydi** — omborda o'zgarish
bo'lmaydi. Sonni kamaytirib qayta urinasiz yoki avval xomashyo kirim qilasiz.

### 5-qadam. Sotuv — avtomatik

Kassada sotilganda **tayyor mahsulot soni** o'zi kamayadi. Hech narsa qilish
kerak emas.

> **Muhim:** sotuvda xomashyo **chegirilmaydi**. U pishirishda allaqachon
> chegirilgan. Aks holda ikki marta kamayardi.

---

## 4. Kundalik ish tartibi

**Ertalab:**
1. Ombor → Qoldiqlar → "Xomashyolar" tabini ko'rib chiqing — qizil ("Kam")
   bo'lganlarini yozib oling
2. Kerakli mahsulotlarni **Pishirish** orqali kiriting

**Mahsulot kelganda:**
- Kirim / Chiqim → **Kirim** → miqdor, tannarx, kimdan → saqlash

**Nimadir buzilsa/to'kilsa:**
- Kirim / Chiqim → **Chiqim** → miqdor va izoh (sabab) → saqlash
- Chiqimda xomashyo ham, tayyor mahsulot ham bo'ladi

**Oy oxirida:**
- **Inventarizatsiya** o'tkazing (pastda)

---

## 5. Inventarizatsiya

Haqiqiy qoldiq bilan tizimdagi son bir xil bo'lmasligi tabiiy — to'kilgan,
o'lchovda farq, hisobga olinmagan sarf. Inventarizatsiya shuni tenglashtiradi.

Ombor → **Inventarizatsiya**

1. **Xomashyolar** yoki **Mahsulotlar** ni tanlang
2. Har qatorda tizimdagi son ko'rinadi — yoniga **real sanalgan** sonni yozing
3. **Farq** avtomatik hisoblanadi (yashil = to'g'ri, ko'k = ortiqcha,
   qizil = kam)
4. **"Yakunlash"** → tasdiqlang

> ⭐ **Bo'sh qoldirilgan qatorlarga tegilmaydi.** Faqat 10 ta xomashyoni
> sanagan bo'lsangiz, faqat o'sha 10 tasi tenglashtiriladi — qolganlari
> avvalgidek qoladi. Hammasini birdan sanash shart emas, bo'lib-bo'lib qilsa
> ham bo'ladi.

Farq **"Tuzatish"** (ADJUST) sifatida tarixga yoziladi — keyin qaysi kuni
qancha farq chiqqanini ko'rish mumkin.

---

## 6. Harakatlar tarixi

Ombor → **Harakatlar tarixi**

Ombordagi **har bir o'zgarish** shu yerda. Ustunlar: sana, nomi, turi, miqdor,
narx, kim, izoh.

Harakat turlari:

| Turi | Ma'nosi | Qoldiqqa |
|------|---------|:--------:|
| **Kirim** | Sotib olindi / olib kelindi | ➕ |
| **Pishirish** | Tayyorlandi (xomashyo ketdi) | ➕ |
| **Sotuv** | Kassada sotildi | ➖ |
| **Chiqim** | Buzildi / to'kildi | ➖ |
| **Tuzatish** | Inventarizatsiya farqi | ➕ yoki ➖ |
| **Qaytarish** | Buyurtma bekor qilindi | ➕ |

Filtrlar: **sana oralig'i**, **harakat turi**, **xomashyo/mahsulot**.

> Misol: "O'tgan hafta qancha go'sht buzilgan?" → sana oralig'ini tanlang +
> "Chiqim" turini belgilang + "Xomashyo" ni tanlang.

---

## 7. Food-cost — foyda nazorati

Har mahsulot kartasida foiz ko'rinadi. Bu — **tannarxning sotuv narxiga
nisbati**.

| Rang | Foiz | Ma'nosi |
|:----:|------|---------|
| 🟢 | 35% gacha | Yaxshi |
| 🟡 | 35–45% | Yuqoriroq — narx yoki retseptni ko'rib chiqing |
| 🔴 | 45% dan yuqori | Juda yuqori — bu mahsulotdan foyda kam |

Masalan 30% degani: 25 000 so'mlik somsaning tannarxi 7 500 so'm.

**Qanday hisoblanadi:** retsept bo'yicha xomashyolarning o'rtacha tannarxi
qo'shiladi va bir donaga bo'linadi.

> **Foiz ko'rinmayapti?** Demak xomashyolarning tannarxi kiritilmagan. Mahsulot
> detalini ochsangiz, qaysi xomashyoda tannarx yo'qligi nomi bilan yoziladi.
> Tannarx **Kirim** qilganda avtomatik to'ladi.

Mahsulot detalida to'liq ko'rinadi: bir dona tannarxi, foiz va baho
(*maqbul / yuqoriroq / juda yuqori*). Retseptdagi miqdorni o'zgartirsangiz,
foiz **darhol** qayta hisoblanadi — saqlashdan oldin ta'sirini ko'rasiz.

---

## 8. Ko'p uchraydigan savollar

**Mahsulotda "Kirim" tugmasi yo'q, "Pishirish" chiqyapti.**
Uning turi "Tayyorlanadi" bo'lib turibdi. Mahsulot detalini ochib, "Turi" ni
"Sotib olinadi" ga o'tkazing (1-bo'limga qarang).

**Pishirmoqchiman, lekin "Xomashyo yetarli emas" deyapti.**
Ro'yxatda nima yetishmayotgani yozilgan. Avval o'sha xomashyoni **Kirim**
qiling, keyin qayta urinib ko'ring. Omborda hech narsa o'zgarmagan.

**Xomashyo qoldig'i noto'g'ri ko'rinyapti.**
**Inventarizatsiya** qiling — real sanab, tizimni to'g'rilaysiz. Farq tarixga
yoziladi.

**Retseptsiz mahsulotni pishirsam nima bo'ladi?**
Tayyor soni oshadi, lekin xomashyo chegirilmaydi. Retsept yozilmagan bo'lsa
ilova buni detal sahifasida eslatib turadi.

**Xomashyoning rasmi va tannarxini qayerdan o'zgartiraman?**
Ombor → Qoldiqlar → "Xomashyolar" tabi → xomashyo ustiga bosing.

**Ombordagi miqdorni qo'lda o'zgartirsam bo'ladimi?**
Ha, xomashyo detalidan. Lekin farq **"Tuzatish"** sifatida tarixga yoziladi —
ya'ni izsiz o'zgartirib bo'lmaydi. Bu ataylab shunday.

**Buyurtma bekor qilinsa qoldiq qaytadimi?**
Tayyor mahsulot soni qaytadi. Xomashyo qaytmaydi — u pishirishda sarflangan,
mahsulot esa hali omborda turibdi.

---

## 9. Eslab qolish uchun

1. **Xomashyo faqat pishirishda kamayadi**, sotuvda emas
2. **Tannarxni har kirimda kiriting** — usiz food-cost yo'q
3. **Inventarizatsiyada bo'sh qator = sanalmagan**, unga tegilmaydi
4. **Xomashyo yetmasa hech narsa saqlanmaydi** — yarim ish bo'lmaydi
5. **Har bir o'zgarish tarixda qoladi** — kim, qachon, qancha
