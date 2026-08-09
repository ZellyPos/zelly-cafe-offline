# Omborxona moduli — Bajarilish jarayoni (progress)

> Spetsifikatsiya: [`ombor_final.md`](ombor_final.md) · Boshlangan: 2026-08-07
> Har bosqich yakunlanganda shu yerga yoziladi.

Bajarish tartibi: 1) DB migratsiya → 2) inventory_service refaktori →
3) InventoryRepository → 4) Ekranlar → 5) Food-cost.

---

## ✅ 1-bosqich — DB migratsiya (v54 → v55) — TUGADI (2026-08-07)

**Fayllar:** `lib/core/database_helper.dart`, `lib/models/product.dart`,
`lib/models/inventory_models.dart`

**Qilingan ishlar:**
- DB versiyasi **54 → 55** ko'tarildi.
- `_createDB` (yangi o'rnatish) va `_onUpgrade` (mavjud bazalar,
  `oldVersion < 55`) — ikkalasiga ham quyidagilar qo'shildi:

| Jadval | Qo'shilgan ustun/jadval | Maqsad |
|--------|-------------------------|--------|
| `products` | `product_type TEXT DEFAULT 'prepared'` | prepared / resale turi |
| `products` | `avg_cost REAL DEFAULT 0` | resale tannarxi |
| `ingredients` | `image_path TEXT` | xomashyo rasmi (6-band) |
| `ingredients` | `avg_cost REAL DEFAULT 0` | o'rtacha tannarx (food-cost) |
| `stock_movements` | `supplier TEXT` | "kimdan olingani" (7-band) |
| **`product_movements`** (yangi) | to'liq jadval + indeks | tayyor mahsulot jurnali |

- `product_movements` jadvali: `id, product_id, type(PRODUCE/PURCHASE/SALE/
  WASTE/ADJUST), qty, ref_table, ref_id, cost_price, supplier, note,
  created_at, created_by` + `idx_product_movements_lookup` indeksi.
- Migratsiya **idempotent** (mavjud v54 uslubidagi `PRAGMA table_info`
  tekshiruvi bilan) — qayta ishga tushsa xato bermaydi.

**Modellar yangilandi:**
- `Product`: `productType`, `avgCost` + `isPrepared`/`isResale` getterlari
  (toMap/fromMap/copyWith).
- `Ingredient`: `imagePath`, `avgCost` + `copyWith`.
- `StockMovement`: `supplier`.

**Tekshiruv:** `flutter analyze` — **0 xato** (faqat eski info-level lintlar).

> Eslatma: real DB migratsiyasi ilova birinchi ishga tushganda (`v54→v55`)
> avtomatik bajariladi. Test muhitida `sqlite3.dll` yuklanmagani uchun bu yerda
> runtime-tekshiruv qilinmadi; kod v54 migratsiyasi bilan bir xil ishonchli
> naqshda yozilgan.

---

## ✅ 2-bosqich — inventory_service refaktori — TUGADI (2026-08-07)

**Fayl:** `lib/core/services/inventory_service.dart`

**Eng muhim o'zgarish — xomashyo chegirish sotuvdan pishirishga ko'chdi:**

| Amal | Eski | Yangi |
|------|------|-------|
| **Sotuv** (`processOrderPaid`) | trackType 2 → retsept bo'yicha xomashyo ↓; trackType 1 → son ↓ | Faqat **tayyor son ↓** (barcha tur) + `product_movements` SALE |
| **Pishirish** (yangi `produce`) | — | Retsept×son bo'yicha **xomashyo ↓** (stock_movements OUT, reason=production) + **tayyor son ↑** + PRODUCE log |
| **Refund** (`reverseOrderPaid`) | retail → son ↑; retsept → xomashyo qaytarish | Faqat **tayyor son ↑** + ADJUST(note=refund) log |

**Natija:** endi xomashyo **faqat pishirishda** chegiriladi — ikki marta
chegirish yo'q. Sotuv sof retail (tayyor son). `order_inventory_flags`
idempotency saqlandi.

- Yangi metod: `produce(List<({int productId, double count})>, {userId})` —
  bitta tranzaksiyada retsept portlashi + tayyor son oshishi.
- Olib tashlangan: `_deductProductStock`, `_handleRetailDeduction`,
  `_handleRecipeDeduction`, eski `_reverseProductStock`.
- Saqlandi: `purchaseIn`, `wasteOut`, `adjustStock` (kirim/chiqim primitivlari).

**Tekshiruv:** `flutter analyze` — **0 xato**.

> Eslatma: `cart_provider` checkout allaqachon `enableInventory` bo'lsa
> `processOrderPaid`ni chaqiradi — signatura o'zgarmadi, moslik saqlandi.

---

## ✅ 3-bosqich — InventoryRepository metodlari — TUGADI (2026-08-07)

**Fayllar:** `lib/repositories/inventory_repository.dart`,
`lib/providers/inventory_provider.dart`

Mavjud repozitoriyga (ingredient CRUD, retsept, movements, flags allaqachon bor
edi) quyidagi metodlar qo'shildi:

| Metod | Vazifa |
|-------|--------|
| `stockIn(ingredientId, qty, cost, supplier)` | Xomashyo kirimi + **og'irlikli o'rtacha tannarx** |
| `stockOut(ingredientId, qty, reason, note)` | Xomashyo chiqimi (waste) |
| `resaleStockIn(productId, qty, cost, supplier)` | Resale mahsulot kirimi + tannarx |
| `productWaste(productId, qty, note)` | Tayyor mahsulot chiqimi |
| `reconcileIngredients(Map)` | Inventarizatsiya — xomashyo realga tenglashtirish |
| `reconcileProducts(Map)` | Inventarizatsiya — tayyor mahsulot realga tenglashtirish |
| `getIngredientsWithStock()` | Xomashyolar + qoldiq (JOIN) |
| `getPreparedProducts()` / `getResaleProducts()` | Tur bo'yicha mahsulotlar |
| `getProductMovements({productId})` | Tayyor mahsulot tarixi |

`InventoryProvider`ga shu metodlarni chaqiruvchi wrapper'lar + `produce()`
(pishirish, `InventoryService.produce`ni chaqiradi) qo'shildi.

**Tekshiruv:** `flutter analyze` — **0 xato**.

---

## ✅ 3.5-bosqich — 2 va 3-bosqich chala joylari yopildi (2026-08-09)

4-bosqichga (UI) o'tishdan oldin oldingi bosqichlar spetsifikatsiyaga
solishtirib qayta tekshirildi. Uchta bo'shliq topildi va yopildi:

| # | Muammo | Fayl | Yechim |
|---|--------|------|--------|
| 1 | `produce()` xomashyo yetarligini **tekshirmasdi** — qoldiq minusga tushardi (spec §C talab qilgan) | `inventory_service.dart` | Yozishdan **oldin** tekshirish + `InsufficientStockException` |
| 2 | `reverseOrderPaid` tranzaksiya ichida `getInventoryFlag`ni **txn'siz** chaqirardi — deadlock xavfi | `inventory_service.dart` | `txn` uzatildi |
| 3 | **Birlashgan tarix `getHistory({filters})` yo'q edi** (spec §5) — §4.6 ekrani busiz yozilmaydi | `inventory_repository.dart` | UNION ALL so'rovi + filtrlar |

**1 — Pishirishda xomashyo nazorati:**
- `produce()` endi ikki bosqichli: avval **barcha** mahsulotlar bo'yicha kerakli
  xomashyo yig'iladi (bir xomashyo bir necha retseptda bo'lsa **jamlanadi**),
  keyin bitta so'rovda qoldiqqa solishtiriladi.
- Yetmasa `InsufficientStockException` tashlanadi — tranzaksiya rollback
  bo'ladi, ya'ni **qisman yozilish yo'q**.
- Exception `shortages` ro'yxatini olib yuradi (nom, kerak, mavjud, birlik) va
  tayyor `message` beradi — UI to'g'ridan-to'g'ri ko'rsatishi mumkin.
- `allowNegative: true` bilan tekshiruvni chetlab o'tish mumkin (ixtiyoriy).

**3 — `getHistory()`:** `stock_movements` + `product_movements` bitta
ro'yxatga birlashadi. Ustunlar: `source` (ingredient/product), `item_id`,
`item_name`, `unit`, `type`, `qty`, `cost_price`, `supplier`, `note`,
`reason`, `created_at`, `created_by`. Filtrlar: `from`, `to`, `types[]`,
`itemId`, `source`, `limit`. Barcha parametrlar bog'langan (SQL injection yo'q).

`InventoryProvider`ga `getHistory()` wrapper'i qo'shildi; `produce()` endi
`allowNegative`ni uzatadi va tugagach `loadIngredients()` bilan qoldiqni
yangilaydi.

**Tekshiruv:** `flutter analyze` (3 fayl) — **0 xato**.

---

## 🔨 4-bosqich — Ekranlar (UI) — JARAYONDA

Spec §4 dagi 7 ta ekran tartib bilan yoziladi. Har qismi tugagach shu yerga
qo'shiladi.

### ✅ 4.1 — Ombor bosh sahifa (2 tab) — TUGADI (2026-08-09)

**Yangi fayl:** `lib/features/inventory/screens/warehouse_screen.dart`

- Ikki tab: **Mahsulotlar** (default) va **Xomashyolar**.
- **Qidiruv** (nom + kategoriya bo'yicha) va **karta/jadval** ko'rinish
  almashtirgichi — ikkala tabda ishlaydi.
- Mahsulotlar tabida tur filtri: *Hammasi / Tayyorlanadi / Sotib olinadi*.
- Har mahsulot kartasi: rasm, tur belgisi, nom, kategoriya, narx, **qoldiq**
  (0 yoki manfiy bo'lsa qizil).
  - `prepared` → **"Pishirish"** tugmasi (modal ochiladi)
  - `resale` → **"Kirim"** tugmasi (§A dialogi)
- Xomashyo kartasi: rasm, nom, qoldiq + birlik, min. miqdor, avg_cost.
  **Qoldiq minimaldan past bo'lsa** karta qizil hoshiyali + "Kam" belgisi.
- Tab almashganda qidiruv/filtr tozalanadi (ro'yxatlar turlicha).
- AppBar'da umumiy **"Pishirish"** tugmasi (mahsulot tanlamasdan ochish uchun).

**Yordamchi vidjet:** `widgets/inventory_image.dart` — rasmni
`ConnectivityProvider.getImageUrl` orqali lokal fayl yoki server URL sifatida
ko'rsatadi, bo'lmasa ikonka (client/server rejimlarida bir xil ishlaydi).

Menyuga (`inventory_menu_screen.dart`) birinchi karta sifatida ulandi. Eski
ekranlar (Xom-ashyolar, Kirim/Chiqim, Retseptlar, Tarix) hozircha joyida —
ular 4.3–4.6 da almashtiriladi.

### ✅ 4.2 — Pishirish modali — TUGADI (2026-08-09)

**Yangi fayl:** `lib/features/inventory/widgets/produce_dialog.dart`

- Faqat `prepared` mahsulotlar ro'yxati + qidiruv.
- **Ko'p tanlash**; tanlangan qatorda son maydoni ochiladi (default `1`).
- Kartadagi "Pishirish" tugmasidan kelsa — o'sha mahsulot **darhol tanlangan**.
- `X` tugmasi va **tashqi bosishda** yopiladi (`barrierDismissible: true`).
- Saqlash → `InventoryProvider.produce()` — bitta tranzaksiyada.
- ⚠️ **Xomashyo yetmasa**: `InsufficientStockException` ushlanadi va alohida
  dialogda "qaysi xomashyo / qancha kerak / qancha bor" ko'rsatiladi. Modal
  ochiq qoladi (son o'zgartirib qayta urinish mumkin), omborda **hech narsa
  o'zgarmaydi**.
- Saqlash paytida barcha maydonlar bloklanadi (ikki marta bosish oldi olinadi).

### ✅ 4.1a — Resale "Kirim" dialogi — TUGADI (2026-08-09)

**Yangi fayl:** `lib/features/inventory/widgets/resale_stock_in_dialog.dart`

Bitta resale mahsulot uchun tezkor kirim: miqdor + tannarx + "kimdan olindi".
Tannarx maydoni oldingi `avg_cost` bilan to'ldiriladi. `resaleStockIn()` orqali
og'irlikli o'rtacha tannarx qayta hisoblanadi. (Ko'p mahsulotli kirim — §4.5.)

**Tekshiruv:** `flutter analyze lib/features/inventory` — yangi fayllarda
**0 muammo** (23 ta info — eski fayllardagi `withOpacity`).
`flutter build windows --debug` — **muvaffaqiyatli**.

### ✅ 4.3 — Mahsulot detail (retsept boshqaruvi) — TUGADI (2026-08-09)

**Yangi fayl:** `lib/features/inventory/screens/product_detail_screen.dart`

- Yuqorida mahsulot ma'lumotlari — **faqat ko'rish** (spec talabi): rasm, nom,
  kategoriya, narx, qoldiq, turi. Tahrir "Mahsulotlar" bo'limida qoladi.
- `prepared` mahsulotda **Retsept bloki**:
  - Jadval: xomashyo | **sarf miqdori** (tahrirlanadi) | **omborda** | **min.
    miqdor** — spec §4.3 dagi to'rt ustun.
  - **"Xomashyo qo'shish"** → qidiruvli tanlash dialogi. Retseptda allaqachon
    bor xomashyo ro'yxatda **ko'rinmaydi** (takror qo'shish oldi olinadi —
    `recipe_items` da `UNIQUE(recipe_id, ingredient_id)` bor).
  - Har qatorda **o'chirish** tugmasi.
  - **"Bir retseptdan chiqadi"** (`yield_qty`) maydoni — sarf shu songa
    bo'linadi (§C mantig'i), shuning uchun ko'rinib turishi shart.
  - Qoldiq minimaldan past xomashyo qizil rangda.
- Saqlash tugmasi faqat **o'zgarish bo'lganda** faol. Miqdori 0 bo'lgan qator
  yoki `yield_qty <= 0` bilan saqlashga yo'l qo'yilmaydi.
- **Saqlanmagan o'zgarish himoyasi**: orqaga qaytishda tasdiq so'raladi
  (`PopScope` + AppBar tugmasi, ikkalasi ham).
- `resale` mahsulotda retsept o'rniga: tannarx, ustama va "Kirim" tugmasi.
- AppBar'da mahsulot turiga qarab **"Pishirish"** yoki **"Kirim"** tugmasi;
  bajarilgach qoldiq darhol yangilanadi.

### ✅ 4.4 — Xomashyo detail — TUGADI (2026-08-09)

**Yangi fayl:** `lib/features/inventory/screens/ingredient_detail_screen.dart`

- Tahrirlanadi: **rasm** (FilePicker, olib tashlash ham mumkin), nom, o'lchov
  birligi, min. miqdor, **ombordagi miqdor**, o'rtacha tannarx.
- ⭐ **Ombordagi miqdor to'g'ridan-to'g'ri yozilmaydi**: o'zgartirilsa
  `reconcileIngredients()` chaqiriladi, ya'ni farq **ADJUST** harakati sifatida
  yoziladi. Shunda tarix uzilmaydi va qoldiq qayerdan o'zgargani ko'rinadi.
  (Faqat haqiqatan o'zgargan bo'lsa — `1e-9` tolerantlik bilan tekshiriladi.)
- Pastda "Qoldiq qiymati" = tannarx × qoldiq, kiritish paytida jonli hisoblanadi.
- O'chirish tugmasi — tasdiq dialogi bilan.

**Ulanish:** bosh sahifadagi mahsulot va xomashyo kartalari (ham karta, ham
jadval ko'rinishida) bosilganda tegishli detail ochiladi; detail'dan
o'zgarish bilan qaytilsa ro'yxat avtomatik yangilanadi.

**Tekshiruv:** `flutter analyze lib/features/inventory` — yangi fayllarda
**0 muammo**.

### ✅ 4.5 — Kirim/Chiqim sahifasi — TUGADI (2026-08-09)

**Yangi fayl:** `lib/features/inventory/screens/stock_flow_screen.dart`

⚠️ **Avval repozitoriy kengaytirildi** — ko'p qatorni ketma-ket saqlash
xavfli edi (yarmi yozilib, yarmi yozilmay qolishi mumkin):

- `inventory_repository.dart` ga `StockItemKind`, `StockDirection`,
  `StockBatchLine` va **`applyStockBatch(lines)`** qo'shildi — barcha qatorlar
  **bitta tranzaksiyada**. Bitta qator xato bersa hammasi bekor bo'ladi.
- `stockIn / stockOut / resaleStockIn / productWaste` ichki mantig'i
  `_ingredientIn / _ingredientOut / _productIn / _productOut` primitivlariga
  ajratildi (tranzaksiya ichida ishlaydi); ommaviy metodlar shularni o'raydi.
  Kod takrorlanmaydi, xatti-harakat bir xil.
- 🐞 **Tannarx bug'i tuzatildi**: kirimda tannarx kiritilmasa (`cost = 0`)
  eski `avg_cost` **nolga tushib ketardi**. Endi `cost <= 0` bo'lsa o'rtacha
  tannarxga tegilmaydi.

**Ekran:**
- **Kirim / Chiqim** — knopka ko'rinishida (spec talabi: select emas).
- Ro'yxat yo'nalishga qarab o'zgaradi:
  - *Kirim*: xomashyolar + **resale** mahsulotlar (`prepared` yo'q — u
    pishirish orqali to'ldiriladi).
  - *Chiqim*: xomashyolar + **barcha** mahsulotlar (buzilish — Qaror 6).
- Qidiruv; ro'yxatda xomashyolar avval, keyin mahsulotlar.
- Ko'p tanlash; tanlangan qator ostida maydonlar ochiladi:
  - kirimda **miqdor + tannarx + "kimdan olindi"** (tannarx oldingi
    `avg_cost` bilan to'ldiriladi),
  - chiqimda **miqdor + izoh**.
- Yo'nalish almashsa tanlov tozalanadi (ro'yxat tarkibi boshqacha).
- AppBar'da **"Tarix"** va **"Inventarizatsiya"** tugmalari (§4.6, §4.7).
- Saqlashda miqdorsiz qatorlar nomi bilan ko'rsatiladi.

### ✅ 4.6 — Harakatlar tarixi — TUGADI (2026-08-09)

**Yangi fayl:** `lib/features/inventory/screens/stock_history_new_screen.dart`

- `getHistory()` ustiga qurilgan: **xomashyo + tayyor mahsulot** harakatlari
  bitta ro'yxatda, sana bo'yicha kamayish tartibida.
- Jadval ustunlari (spec §4.6): **sana · nomi · turi · miqdor · narx · kim ·
  izoh**.
- "Kim" ustuni uchun `getHistory()` ga `users` jadvali **LEFT JOIN** qilindi
  (`user_name`). Mahsulot birligi `products.unit` dan olinadi.
- Filtrlar: **sana oralig'i** (date range picker, tanlangan kun oxirigacha
  kiradi), **tur** (8 ta chip: Kirim/Chiqim/Pishirish/Sotuv/Buzilish/
  Tuzatish/Qaytarish), **birlik turi** (xomashyo / mahsulot / hammasi).
- Miqdor **ishorali va rangli**: qoldiqni oshiradigan harakatlar yashil `+`,
  kamaytiradiganlar qizil `−`. `ADJUST` da farq ishorasi o'zi hal qiladi.
- Izoh ustuni `supplier`, `note`, `reason` dan yig'iladi.
- Bitta birlik tarixini ochish uchun `itemId` + `source` parametrlari bor.

### ✅ 4.7 — Inventarizatsiya — TUGADI (2026-08-09)

**Yangi fayl:** `lib/features/inventory/screens/stocktaking_screen.dart`

- **Xomashyolar / Mahsulotlar** — knopka bilan almashtiriladi.
- Jadval: **nomi | tizimda | real son (kiritiladi) | farq (avtomatik)**.
  Farq jonli hisoblanadi: teng bo'lsa yashil "to'g'ri", ortiqcha ko'k `+`,
  kam qizil `−`.
- ⭐ **Faqat real son kiritilgan qatorlar** hisobga olinadi. Bo'sh qator
  "sanalmagan" — unga **tegilmaydi**. (Aks holda sanalmagan hamma narsa nolga
  tushib ketardi.) Pastda "N / M birlik sanaldi" ko'rsatiladi.
- Saqlashdan oldin **tasdiq dialogi**: nechta sanaldi, nechtasida farq bor.
  Qoldiq **realga tenglashtiriladi** (Qaror 3), farq `ADJUST` sifatida yoziladi.

### ✅ 4.8 — Menyu va eski ekranlarni tozalash — TUGADI (2026-08-09)

`inventory_menu_screen.dart` to'liq yangi ekranlarga o'tkazildi:
**Qoldiqlar · Kirim/Chiqim · Inventarizatsiya · Harakatlar tarixi**.

**O'chirilgan eski ekranlar** (yangilari to'liq almashtirdi):
`ingredients_screen.dart`, `recipes_screen.dart`,
`stock_management_screen.dart`, `stock_history_screen.dart`.

> Sabab: eski Kirim/Chiqim ekrani `purchaseIn`/`wasteOut` orqali ishlab,
> **tannarx va yetkazuvchini yozmasdi** — natijada `avg_cost` yangilanmay,
> food-cost hisobi buzilardi. Ikkita raqobatlashuvchi UI qolishi ma'lumotni
> nomutanosib qilardi.

Eski ekrandagi yagona yo'qolgan imkoniyat — **yangi xomashyo qo'shish** —
bosh sahifaning "Xomashyolar" tabiga ko'chirildi (AppBar tugmasi tabga qarab
o'zgaradi: Mahsulotlarda "Pishirish", Xomashyolarda "Xomashyo qo'shish").
Retsept tahriri esa mahsulot detaliga ko'chgan (§4.3).

**Tekshiruv:** `flutter analyze lib` — ombor fayllarida **0 xato/ogohlantirish**.
`flutter build windows --debug` — **muvaffaqiyatli**.

---

## ✅ 4-bosqich YAKUNLANDI — spec §4 dagi 7 ta ekranning hammasi tayyor

| Spec | Ekran | Fayl |
|------|-------|------|
| §4.1 | Ombor bosh sahifa (2 tab) | `warehouse_screen.dart` |
| §4.2 | Pishirish modali | `widgets/produce_dialog.dart` |
| §4.3 | Mahsulot detail (retsept) | `product_detail_screen.dart` |
| §4.4 | Xomashyo detail | `ingredient_detail_screen.dart` |
| §4.5 | Kirim/Chiqim | `stock_flow_screen.dart` |
| §4.6 | Tarix | `stock_history_new_screen.dart` |
| §4.7 | Inventarizatsiya | `stocktaking_screen.dart` |

---

## ✅ 5-bosqich — Food-cost — TUGADI (2026-08-09)

**Repozitoriy** (`inventory_repository.dart`):
- `recipeCost(productId)` — bitta mahsulot tannarxi; retsepti yo'q bo'lsa
  `null` (0 emas — "hisoblab bo'lmadi" bilan "tekin" farqlanadi).
- `getRecipeCosts({productIds})` — **bitta so'rovda** barcha mahsulotlar
  tannarxi (`GROUP BY r.id`). Ro'yxat ekranlarida N+1 so'rov bo'lmasligi uchun.

Formula (spec §3): `Σ(recipe_items.qty × ingredients.avg_cost) / yield_qty`.

**Yangi vidjet:** `widgets/food_cost_badge.dart`
- `food_cost_% = tannarx / narx × 100`.
- Rang: **≤35% yashil** (maqbul), **≤45% sariq**, **>45% qizil** — restoran
  amaliyotidagi 25–35% oralig'iga asoslangan.
- Tannarx yoki narx noma'lum bo'lsa **hech narsa ko'rsatilmaydi** (yolg'on 0%
  chalg'itadi).
- `percentOf()` va `colorFor()` statik yordamchilari boshqa joyda ham ishlatiladi.

**Ko'rsatiladigan joylar:**
1. **Ombor bosh sahifasi** (§4.1) — har mahsulot kartasi va jadval qatorida
   ixcham belgi. `prepared` uchun retsept tannarxi, `resale` uchun `avg_cost`.
2. **Mahsulot detali** (§4.3) — retsept ostida to'liq qator: "Bir dona
   tannarxi" + food-cost % + baho (*maqbul / yuqoriroq / juda yuqori*).
   - ⭐ Tannarx **joriy tahrirdan** hisoblanadi: miqdorni o'zgartirsangiz
     darhol yangilanadi, saqlashni kutmaydi.
   - Tannarxi kiritilmagan xomashyolar bo'lsa **nomi bilan ogohlantiriladi**
     ("hisob to'liq emas") — jim turib noto'g'ri raqam ko'rsatmaydi.
3. **Resale mahsulot detali** — tannarx va ustama yonida food-cost belgisi.

**Tekshiruv:** `flutter analyze` — **0 muammo**.
`flutter build windows --debug` — **muvaffaqiyatli**.

---

# 🎉 OMBOR MODULI TO'LIQ TUGADI

Barcha 5 bosqich yakunlandi. `docs/ombor_final.md` §8 dagi hamma qaror
kodda amalga oshirildi:

| Qaror | Qayerda |
|-------|---------|
| 1. Pishirish xomashyoni chegiradi | `InventoryService.produce()` + §4.2 modal |
| 2. Faqat partiyali tayyorlash | Sotuv retail-only (`_sellFinished`) |
| 3. Inventarizatsiya = realga tenglashtirish | §4.7 ekran + `reconcile*()` |
| 4. Resale mahsulot → Kirim | `product_type` + §4.5 va tezkor kirim dialogi |
| 5. Tannarx + food-cost | `avg_cost` + 5-bosqich |
| 6. Tayyor mahsulot waste | §4.5 Chiqim (barcha mahsulotlar) |

**Yo'l-yo'lakay tuzatilgan xatolar:**
1. `produce()` xomashyo yetarligini tekshirmasdi → qoldiq minusga tushardi.
2. `reverseOrderPaid` tranzaksiya ichida txn'siz o'qish → deadlock xavfi.
3. Kirimda tannarx kiritilmasa `avg_cost` **nolga tushib ketardi**.
4. Ko'p qatorli kirim/chiqim ketma-ket saqlanardi → yarim yozilish xavfi
   (endi bitta tranzaksiya).

---

## ✅ Runtime tekshiruvi (2026-08-09)

**1. Ilova haqiqiy bazada ishga tushirildi** (`flutter run -d windows`):
- Log: "Ma'lumotlar bazasi tayyor" — **v54→v55 migratsiyasi xatosiz o'tdi**.
- Bazadan tasdiqlandi (`tezzro_pos.db`): `user_version = 55`;
  `products.product_type`, `products.avg_cost`, `ingredients.image_path`,
  `ingredients.avg_cost`, `stock_movements.supplier` — **hammasi bor**;
  `product_movements` jadvali va `idx_product_movements_lookup` indeksi bor.
- Mavjud **367 ta mahsulot** `product_type = 'prepared'` ga o'tgan (DEFAULT
  qiymat ishladi). Ular orasidan sotib olinadiganlarini `resale` ga
  o'tkazish kerak bo'ladi — bu ma'lumot ishi, kod emas.

**2. Testlar to'liq qayta yozildi** — `test/inventory_test.dart`

Eski test **eski modelni** tekshirardi (sotuvda xomashyo chegirilishi) va yangi
mantiq bilan yiqilardi. Yangi model bo'yicha **20 ta test** yozildi, hammasi
o'tdi:

| Guruh | Qamrov |
|-------|--------|
| Pishirish | retsept chegirishi · `yield_qty` · yetishmovchilikda **rollback** · shortage tafsilotlari · **bir xomashyo ikki retseptda jamlanishi** · `allowNegative` |
| Sotuv/qaytarish | ⭐ sotuv xomashyoga **tegmasligi** · idempotentlik · refund (deadlock ham shu yerda tekshiriladi) |
| Kirim/chiqim | og'irlikli o'rtacha tannarx · **tannarxsiz kirim avg_cost'ni buzmasligi** · resale kirim · `applyStockBatch` · waste |
| Inventarizatsiya | realga tenglashtirish + ishorali ADJUST (xomashyo va mahsulot) |
| Tarix/food-cost | `getHistory` birlashtirish va 3 xil filtr · `recipeCost` · `getRecipeCosts` · retseptsizda `null` |

**3. Butun to'plam:** `flutter test` → **22 o'tdi, 5 yiqildi**.
Yiqilganlarning **hech biri ombor bilan bog'liq emas**:
- `analytics_test` (3 ta) va `widget_test` (1 ta) — `HEAD` da ham yiqiladi
  (tekshirildi), ya'ni bu ishdan oldin ham buzuq edi.
- `shift_test` (1 ta) — `shift_repository.getShiftSalesSummary()` **bu
  sessiyadan oldingi commit qilinmagan o'zgarish** bilan `order_payments`
  jadvalidan o'qishga o'tgan (`order_payments` va `getDiscountStatsByShift`
  `HEAD` da umuman yo'q), test esa hali ham faqat `orders.payment_type` ga
  yozadi → `totalCashSales = 0`. **Ombor moduliga aloqasi yo'q**, lekin
  to'lov bo'linishi ishi tugagach shu testni yangilash kerak.

> Eslatma: Windows'da testlar loyiha ildizidagi `sqlite3.dll` ga bog'liq
> (kuzatuvsiz fayl, `.gitignore` da ham yo'q). U bo'lmasa barcha DB testlari
> "Failed to load dynamic library" bilan yiqiladi.

**Keyingi ish uchun tavsiya (ixtiyoriy):**
- Ombor amallarini `AuditService` bilan bog'lash (kim nima qilgani —
  `created_by` allaqachon yoziladi, lekin UI'da foydalanuvchi uzatilmaydi).
- Hisobotlarga food-cost bo'yicha kesim qo'shish.
