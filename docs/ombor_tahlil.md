# Omborxona moduli — Chuqur tahlil va yakuniy model

> Manba: [`ombor.md`](ombor.md) spetsifikatsiyasi · Tahlil sanasi: 2026-08-07
> Mavjud kod bilan solishtirildi: `inventory_service.dart`, `inventory_models.dart`,
> `recipes`, `stock_movements`, `trackType`.

Bu hujjat `ombor.md` dagi g'oyalarni global standart (restoran ERP) va loyihaning
mavjud kodi bilan solishtiradi, kelishilgan qarorlarni qayd etadi va **yakuniy,
kodga mos modelni** belgilaydi.

---

## 1. Kelishilgan qarorlar (foydalanuvchi tasdiqladi)

| # | Savol | Qaror |
|---|-------|-------|
| 1 | Pishirishda xomashyo avtomatik chegirilsinmi? | ✅ **Ha** |
| 2 | Buyurtmaga tayyorlanadigan (lag'mon kabi) taomlar bormi? | ❌ **Yo'q** — barcha taomlar oldindan (partiyali) tayyorlanadi |
| 3 | Inventarizatsiya nima qiladi? | ✅ **Real songa tenglashtiradi** (farqni yozadi), nolga tushirmaydi |

Bu qarorlar modelni **soddalashtiradi**: bitta yagona "ishlab chiqarish (production)"
oqimi yetarli — alohida "buyurtmaga tayyorlash" oqimi kerak emas.

---

## 2. Yakuniy model — bitta "ishlab chiqarish" oqimi

Barcha taomlar oldindan tayyorlangani uchun, xomashyo **faqat pishirish
paytida** chegiriladi, sotuvda esa faqat **tayyor mahsulot soni** kamayadi.

```
①  KIRIM (xomashyo)          ②  PISHIRISH (production)        ③  SOTUV (POS)
   Yetkazuvchidan               "100 ta somsa tayyorlandi"       Mijoz somsa oldi
   ┌──────────────┐             ┌───────────────────────┐        ┌──────────────┐
   │ Un    +50 kg │             │ Un    −20 kg (OUT)    │        │ Somsa  −1    │
   │ Go'sht +30kg │             │ Go'sht −15 kg (OUT)   │        │ (tayyor son) │
   │ (narx, kimdan)│            │ Yog'  −3 L  (OUT)     │        │              │
   └──────────────┘             │ ───────────────────── │        │ Xomashyoga   │
        │                        │ Somsa +100 (tayyor)   │        │ TEGMAYDI ⚠️  │
        ▼                        └───────────────────────┘        └──────────────┘
   ingredient.on_hand ↑              (retsept × 100)                product.quantity ↓
```

**Muhim qoida:** xomashyo **ikki marta chegirilmasligi** kerak.
- Xomashyo → faqat **②Pishirish**da chegiriladi.
- Sotuvda (③) → faqat **tayyor mahsulot soni** kamayadi, xomashyoga tegilmaydi.

```
④  INVENTARIZATSIYA (real sanoq)
   Tizim: Un = 50 kg  |  Real sanaldi: 47 kg
   → Farq −3 kg ADJUST sifatida yoziladi
   → Tizim 47 kg ga TENGLASHTIRILADI (nolga emas)
```

---

## 3. 🔗 Mavjud kod bilan bog'liqlik (eng muhim refaktor)

Hozirgi `inventory_service.dart` **sotuv paytida** retsept bo'yicha xomashyoni
chegiradi (`processOrderPaid → _handleRecipeDeduction`). Yangi modelda bu
**noto'g'ri** bo'lib qoladi — chunki xomashyo endi **pishirishda** chegiriladi.

### Kerakli o'zgarishlar

| Joy | Hozir | Yangi model |
|-----|-------|-------------|
| **Xomashyo chegirish** | Sotuvda (`processOrderPaid`) | **Pishirishda** (yangi `produce()` metodi) |
| **Sotuvda** (`processOrderPaid`) | Retsept portlashi → ingredient ↓ | Faqat **tayyor son** ↓ (retail) |
| **`trackType` ma'nosi** | 1=retail, 2=retsept (bir-birini istisno qiladi) | Taom = retsept (pishirish uchun) **+** son (sotuv uchun) — birlashadi |

> ⚠️ **Ikki marta chegirish xavfi:** agar `processOrderPaid` o'zgartirilmasa,
> xomashyo ham pishirishda, ham sotuvda ketadi → qoldiq minusga tushadi.
> Shuning uchun sotuvdagi retsept-chegirishni **o'chirish** shart.

### Yangi "Pishirish" (production) mantig'i — taxminiy

```
produce(productId, count):
  transaction:
    retsept = recipes[productId]
    for item in retsept.items:
        kerak = (item.qty / retsept.yield_qty) * count
        # yetarlilik tekshiruvi (Masala 5)
        ingredient_stock[item.ingredientId] -= kerak
        stock_movements += OUT(ingredient, kerak, reason='production', ref=product)
    products[productId].quantity += count
    # (ixtiyoriy) production_log += {product, count, sana, kim}
```

Bu deyarli tayyor — mavjud `_handleRecipeDeduction` kodini **sotuvdan olib,
pishirishga ko'chirish** kifoya.

---

## 4. 🟡 To'ldirilishi kerak bo'lgan masalalar

| # | Masala | Tavsiya |
|---|--------|---------|
| 1 | **Tannarx (narx) yo'q** | Kirimga xomashyo **narxi** maydoni qo'shilsin. Kodda `cost_price` bor — ishlatilsin. Bu food-cost % va foyda uchun asos |
| 2 | **Tayyor mahsulot buzilishi (waste)** | Kirim/chiqim faqat xomashyoga. 5 ta somsa buzilsa qayerda yoziladi? Tayyor mahsulot uchun ham "chiqim/waste" kerak (yoki inventarizatsiya orqali) |
| 3 | **Yetkazuvchi qarzi** | "Kimdan olingani" — hozir faqat matn. MVP uchun yetarli; kelajakda yetkazuvchi + qarz jadvali |
| 4 | **Sotib olib sotiladigan mahsulot (masalan Coca-Cola)** | Retsepti yo'q, pishirilmaydi. Uning soni qanday oshadi? Variant: (a) uni xomashyo sifatida sotish, (b) kirimni tayyor mahsulotga ham ochish, (c) 1 birlik "retsept" berish. **Aniqlashtirish kerak** |
| 5 | **Xomashyo yetarli emasligi** | Pishirishda un yetmasa: bloklaymi / ogohlantirib ruxsat / minusga ruxsat? Kodda `allowNegativeStock` bor — shundan foydalanish mumkin |
| 6 | **O'lchov birligi konvertatsiyasi** | "1 qop = 50 kg" — MVP uchun shart emas, kelajak uchun |

---

## 5. Band-ma-band baho (`ombor.md`)

| Band | Baho | Izoh |
|------|:----:|------|
| 1. Ikki bo'lim (mahsulot/xomashyo) | 🟢 | To'g'ri tuzilma |
| 2. Mahsulotlar bo'limi (card/jadval, qidiruv, filter) | 🟢 | Yaxshi |
| 3. Pishirish knopkasi | 🟢 → | Endi to'g'ri: xomashyoni ham chegiradi (Qaror 1) |
| 4. Xomashyolar bo'limi (pishirishsiz) | 🟢 | Mantiqiy |
| 5. Mahsulot detail (ingredient ro'yxati/tahrir) | 🟢 | Bu — retsept. Faqat ingredient tahriri to'g'ri |
| 6. Ingredient detail (rasm/nom/qoldiq/min) | 🟢 | Yetarli |
| 7. Kirim/chiqim sahifasi | 🟡 | Narx maydoni qo'shilsin (Masala 1). Ko'p tanlash, knopka-select — yaxshi |
| 8. Kirim/chiqim + inventarizatsiya tarixi | 🟢 | Muhim va to'g'ri |
| 9. Inventarizatsiya | 🟢 → | Endi to'g'ri: real songa tenglashtiradi (Qaror 3) |

---

## 6. ✅ Kuchli tomonlar

- UI oqimi aniq va qulay (modal, ko'p tanlash, inline son kiritish, X + tashqi bosishda yopilish)
- Mahsulot detail'da faqat ingredient tahriri — to'g'ri chegaralash
- Kirim/chiqimni xomashyoga, pishirishni mahsulotga ajratish — mantiqiy
- "Pishirish = ishlab chiqarish" yondashuvi — partiyali taomlar (somsa, non) uchun **to'g'ri restoran modeli**
- Mavjud `stock_movements` jurnali va `recipes` — yangi modelga deyarli tayyor poydevor

---

## 7. Ochiq savollar (keyingi bosqichga)

1. **Sotib olib sotiladigan mahsulotlar** (Coca-Cola) bormi? Bo'lsa, ularning soni qanday to'ldiriladi? (Masala 4)
2. **Tannarx** kiritilsinmi? (food-cost hisob1 uchun) — tavsiya: ha
3. **Tayyor mahsulot buzilishi** (waste) qayerda qayd etiladi — alohida chiqimmi yoki inventarizatsiya orqalimi?

---

## 8. Keyingi qadam

Yuqoridagi 3 ochiq savolga javob berilsa, `ombor.md` ni **yakuniy, to'liq va
kodga mos** versiyaga aylantirish mumkin:
- aniq DB o'zgarishlari (kerak bo'lsa `production_log`, `products.is_prepared`, narx),
- `inventory_service` refaktori (retsept-chegirishni sotuvdan pishirishga ko'chirish),
- har bir sahifa uchun aniq provider/repository metodlari.

> Eslatma: bu modul yangi `ProductionRepository`/`InventoryRepository` orqali
> ishlab, loyihaning yangi data-layer arxitekturasiga
> ([`01_ARCHITECTURE.md`](01_ARCHITECTURE.md) §4.5) mos bo'lishi kerak.
