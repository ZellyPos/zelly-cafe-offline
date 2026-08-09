# Omborxona moduli — YAKUNIY spetsifikatsiya (kodga tayyor)

> Asos: [`ombor.md`](ombor.md) (asl g'oya) + [`ombor_tahlil.md`](ombor_tahlil.md) (tahlil)
> Barcha qarorlar tasdiqlangan · 2026-08-07
> Arxitektura: yangi data-layer ([`01_ARCHITECTURE.md`](01_ARCHITECTURE.md) §4.5) — repository orqali.

Bu hujjat — dasturlashga tayyor to'liq tavsif: ma'lumot modeli, oqimlar (aniq
mantiq bilan), sahifalar, kerakli repository metodlari va mavjud kod refaktori.

---

## 0. Tasdiqlangan qarorlar

| # | Qaror |
|---|-------|
| 1 | "Pishirish" xomashyoni avtomatik chegiradi (retsept × son) + tayyor son ↑ |
| 2 | Barcha taomlar oldindan tayyorlanadi (buyurtmaga tayyorlash yo'q) |
| 3 | Inventarizatsiya real songa tenglashtiradi (farqni yozadi) |
| 4 | Sotib olib sotiladigan mahsulot (Coca-Cola) bor — "Kirim" orqali to'ldiriladi |
| 5 | Tannarx (narx) kiritiladi — food-cost % uchun |
| 6 | Tayyor mahsulot buzilishi (waste) — alohida "Chiqim" + inventarizatsiya |

---

## 1. Ma'lumot modeli (DB)

### Mavjud jadvallar (saqlanadi)
`ingredients`, `ingredient_stock`, `stock_movements`, `recipes`, `recipe_items`,
`products`, `order_inventory_flags`.

### Kerakli o'zgarishlar / qo'shimchalar

| Jadval | O'zgarish | Sabab |
|--------|-----------|-------|
| `products` | `+ product_type TEXT` (`'prepared'` \| `'resale'`) | Tayyorlanadi vs sotib olinadi |
| `products` | `+ avg_cost REAL DEFAULT 0` | Resale mahsulot tannarxi |
| `ingredients` | `+ image_path TEXT` | 6-band: xomashyo rasmi |
| `ingredients` | `+ avg_cost REAL DEFAULT 0` | O'rtacha tannarx (food-cost uchun) |
| `stock_movements` | `+ supplier TEXT` (yoki `note`dan foydalanish) | 7-band: "kimdan olingani" |
| **`product_movements`** (YANGI) | `id, product_id, type, qty, ref_table, ref_id, cost_price, note, created_at, created_by` | Tayyor mahsulot jurnali (pishirish/sotuv/waste/adjust) |

> `product_movements.type`: `PRODUCE` (pishirish), `PURCHASE` (resale kirim),
> `SALE` (sotuv), `WASTE` (chiqim), `ADJUST` (inventarizatsiya).
> Bu — tayyor mahsulot uchun `stock_movements`ning ekvivalenti (chunki mavjud
> `stock_movements` faqat xomashyoga mo'ljallangan).

### Mahsulot turlari — yakuniy jadval

| Tur | `product_type` | Retsept | Stock qanday oshadi | Sotuvda |
|-----|:--------------:|:-------:|---------------------|---------|
| **Tayyorlanadi** (somsa, non) | `prepared` | ✅ Ha | **Pishirish** (xomashyo ↓ + son ↑) | Son ↓ |
| **Sotib olinadi** (Coca-Cola) | `resale` | ❌ Yo'q | **Kirim** (son ↑ + tannarx) | Son ↓ |

---

## 2. Oqimlar (aniq mantiq)

### A. Kirim (IN) — xomashyo yoki resale mahsulot
```
for each tanlangan (ingredient | resale product):
    qty, cost_price, supplier(matn)
    if ingredient:
        ingredient_stock.on_hand += qty
        ingredients.avg_cost = weightedAvg(eski_qoldiq, eski_cost, qty, cost_price)
        stock_movements += IN(ingredient, qty, cost_price, supplier, reason='purchase')
    if resale product:
        products.quantity += qty
        products.avg_cost = weightedAvg(...)
        product_movements += PURCHASE(product, qty, cost_price, supplier)
```

### B. Chiqim (OUT) — xomashyo (waste/boshqa)
```
ingredient_stock.on_hand -= qty
stock_movements += OUT(ingredient, qty, reason='waste', note)
```

### C. Pishirish (Production) — `prepared` mahsulot ⭐
```
transaction:
  for each (product, count):
    recipe = recipes[product.id]
    for item in recipe.items:
        need = (item.qty / recipe.yield_qty) * count
        if ingredient_stock.on_hand < need AND !allowNegative:
            error("Xomashyo yetarli emas: <ingredient>")   # yoki ogohlantirish
        ingredient_stock.on_hand -= need
        stock_movements += OUT(ingredient, need, reason='production',
                               ref_table='products', ref_id=product.id)
    products.quantity += count
    product_movements += PRODUCE(product, count)
```

### D. Sotuv (Sale) — POS checkout ⭐ (REFAKTOR)
```
for each product in order:
    products.quantity -= qty          # HAR IKKALA tur uchun (retail)
    product_movements += SALE(product, qty, ref=order)
    # ❌ Xomashyo chegirilMAYDI (prepared uchun pishirishda ketgan;
    #    resale uchun retsept yo'q)
```

### E. Tayyor mahsulot Chiqim / Waste
```
products.quantity -= qty
product_movements += WASTE(product, qty, note='buzildi'/...)
```

### F. Inventarizatsiya (real songa tenglashtirish)
```
for each sanalgan (ingredient | product):
    real = kiritilgan_son
    system = joriy_qoldiq
    diff = real - system
    qoldiq = real                     # nolga EMAS — realga tenglashtirish
    movement += ADJUST(item, diff, reason='inventory')
```

---

## 3. Food-cost (tannarx foizi) — bonus

Tannarx kiritilgani uchun (Qaror 5) endi hisoblash mumkin:
```
recipe_cost(product) = Σ(item.qty × ingredient.avg_cost) / recipe.yield_qty
food_cost_%          = recipe_cost / product.price × 100
resale mahsulot      = product.avg_cost / product.price × 100
```
Bu — restoran uchun eng muhim KPI (odatda 25–35% maqbul).

---

## 4. Sahifalar (ombor.md tozalangan holda)

### 4.1. Ombor bosh sahifa — 2 tab
- **Mahsulotlar** (default): card/jadval, qidiruv, filter, view-toggle.
  - `prepared` mahsulotда **"Pishirish"** knopkasi (§C modal)
  - `resale` mahsulotда **"Kirim"** amali (§A)
  - Har card: nom, kategoriya, narx, **son**, (ixtiyoriy) food-cost %
- **Xomashyolar**: card/jadval, qidiruv, filter. **Pishirish yo'q**.

### 4.2. Pishirish modali (3-band)
- Tayyor (`prepared`) mahsulotlar ro'yxati + qidiruv
- Ko'p tanlash, har qatorda son kiritish
- Pastda "Saqlash" → §C mantig'i (bitta tranzaksiyada)
- Yuqorida `X`, tashqi bosishda ham yopiladi
- ⚠️ Saqlashda xomashyo yetarligini tekshirish (§C)

### 4.3. Mahsulot detail (5-band)
- Mahsulot ma'lumotlari (faqat **ko'rish** — tahrir yo'q)
- **Retsept (ingredientlar) ro'yxati**: nom, sarf miqdori, min miqdor, ombordagi miqdor
- Ingredient qo'shish / o'chirish / miqdor tahriri — **shu yerda**
- (Qo'shimcha) recipe_cost va food-cost % ko'rsatilsa foydali

### 4.4. Xomashyo detail (6-band)
- Rasm, nom, ombordagi miqdor, min miqdor, (qo'shimcha) avg_cost — tahrirlanadi

### 4.5. Kirim/Chiqim sahifasi (7-band) — sidebar: Ombor ostida
- Qidiruv
- **Kirim / Chiqim** — knopka ko'rinishida (select emas)
- Ro'yxatda: xomashyolar **+ resale mahsulotlar** (kirim ikkalasiga tegishli)
- Ko'p tanlash, har qatorда qty **+ narx** (Qaror 5) + "kimdan" (supplier matn)
- "Tarix" knopkasi → §4.6
- "Inventarizatsiya" knopkasi → §4.7
- Saqlash → §A yoki §B

### 4.6. Kirim/Chiqim + Inventarizatsiya tarixi (8-band)
- `stock_movements` + `product_movements` + inventarizatsiya yozuvlari
- Filtr: sana, tur (IN/OUT/PRODUCE/WASTE/ADJUST), item
- Qulay jadval: sana, item, tur, qty, narx, kim, izoh

### 4.7. Inventarizatsiya sahifasi (9-band)
- Xomashyo **yoki** tayyor mahsulot tanlanadi
- Har item uchun: tizim qoldig'i | **real son kiritiladi** | farq (avtomatik)
- Saqlash → §F (realga tenglashtirish, farq ADJUST sifatida)

---

## 5. Repository / Provider metodlari (data-layer)

Yangi `InventoryRepository` kengaytiriladi (yoki `ProductionRepository`,
`ProcurementRepository` ajratiladi):

```
// Kirim / Chiqim
Future<void> stockIn(int ingredientId, double qty, double cost, String? supplier)
Future<void> stockOut(int ingredientId, double qty, String reason, String? note)
Future<void> resaleStockIn(int productId, double qty, double cost, String? supplier)

// Pishirish
Future<void> produce(List<({int productId, double count})> items)   // §C, bitta txn

// Tayyor mahsulot chiqim
Future<void> productWaste(int productId, double qty, String? note)

// Inventarizatsiya
Future<void> reconcileIngredients(Map<int,double> realCounts)
Future<void> reconcileProducts(Map<int,double> realCounts)

// O'qish
Future<List<Ingredient>> getIngredients()
Future<List<Product>> getPreparedProducts()
Future<List<Product>> getResaleProducts()
Future<Recipe?> getRecipe(int productId)
Future<List<Movement>> getHistory({filters})
Future<double> recipeCost(int productId)     // food-cost
```

Ekranlar `InventoryProvider` orqali chaqiradi (SQL ekranlarda bo'lmaydi —
yangi arxitektura qoidasi).

---

## 6. ⚠️ Mavjud kod REFAKTORI (birinchi bajariladi)

`lib/core/services/inventory_service.dart` hozir **sotuvda** retsept bo'yicha
xomashyoni chegiradi. Yangi modelda:

| Amal | Hozir | Yangi |
|------|-------|-------|
| `_handleRecipeDeduction` | Sotuvda (`processOrderPaid`) | **Pishirishга** (`produce`) ko'chiriladi |
| Sotuvdagi chegirish | Retsept (2) → ingredient ↓ | Faqat `products.quantity` ↓ (barcha tur) |
| `order_inventory_flags` | Sotuv chegirishini himoyalaydi | Saqlanadi — sotuv retail chegirishi uchun |

> ❗ Bu qadamsiz xomashyo **ikki marta** kamayadi (pishirishда + sotuvда).
> Shu bois refaktor birinchi navbatда.

---

## 7. Bajarish tartibi (tavsiya)

1. **DB migratsiya:** `product_type`, `avg_cost`, `image_path`, `supplier`,
   `product_movements` jadvali.
2. **Refaktor:** retsept-chegirishni sotuvdan olib, `produce()`ga ko'chirish;
   sotuvni retail-only qilish.
3. **Repository:** yuqoridagi metodlar.
4. **Ekranlar:** bosh sahifa (2 tab) → detail'lar → kirim/chiqim → tarix →
   inventarizatsiya.
5. **Food-cost** ko'rsatkichini qo'shish (ixtiyoriy, oxirida).

---

## 8. Yakuniy holat — hamma savol yopildi ✅

| Masala | Holat |
|--------|:-----:|
| Pishirish xomashyoni chegiradi | ✅ Qaror 1 |
| Faqat partiyali taom (buyurtmaga yo'q) | ✅ Qaror 2 |
| Inventarizatsiya = realga tenglashtirish | ✅ Qaror 3 |
| Resale mahsulot (Coca-Cola) → Kirim | ✅ Qaror 4 |
| Tannarx + food-cost | ✅ Qaror 5 |
| Tayyor mahsulot waste | ✅ Qaror 6 |

Modul dasturlashga tayyor. Boshlash uchun tavsiya: **1-qadam (DB migratsiya)**
va **2-qadam (refaktor)**.
