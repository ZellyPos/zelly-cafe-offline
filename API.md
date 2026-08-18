# Zelly POS — API hujjati

> **Versiya:** 2.0 · **Oxirgi yangilanish:** 2026-08-18
> **Manba:** `lib/core/server/api_server.dart` (59 endpoint) va
> `lib/core/server/auth_token_service.dart`.
>
> Bu hujjat kafedagi Zelly POS serveriga ulanadigan mobil (ofitsiant) va veb
> ilovalar uchun mo'ljallangan.

---

## 1. Umumiy ma'lumot

### Base URL

Server POS kompyuterida yoki tarmoqdagi markaziy mashinada ishlaydi.

```
http://192.168.1.10:8080
```

Port `Sozlamalar → Tarmoq` bo'limida o'zgartiriladi (standart `8080`).

### Sarlavhalar

`/auth/login` dan tashqari **har bir so'rov** token talab qiladi:

```http
Authorization: Bearer <token>
Content-Type: application/json
```

### Ma'lumot formati

Barcha javoblar `application/json; charset=utf-8`. Pul qiymatlari — `double`
(so'm). Sanalar — ISO-8601 qatori (`2026-08-18T14:30:00.000`).

### CORS

Server barcha manbalarga ruxsat beradi (`Access-Control-Allow-Origin: *`),
`OPTIONS` preflight so'rovlari qo'llab-quvvatlanadi.

---

## 2. Autentifikatsiya

### Token qanday ishlaydi

| Xususiyat | Qiymat |
|---|---|
| Tur | Serverda saqlanadigan tasodifiy token (32 bayt, base64url) |
| Muddat | **12 soat**, har so'rovda yangilanadi (sliding expiry) |
| Saqlanishi | `api_sessions` jadvali — server qayta ishga tushsa ham saqlanadi |
| Bekor qilish | `/auth/logout`, xodim o'chirilganda avtomatik |

> ⚠️ **Muhim o'zgarish (v2.0):** ilgari token `admin-token-1` ko'rinishida
> taxmin qilinadigan edi. Endi token tasodifiy — uni "yasab" bo'lmaydi.
> Eski formatdagi tokenlar **ishlamaydi**, mijoz `/auth/login` orqali yangi
> token olishi shart.

---

### `POST /auth/login`

Xodimni PIN kod orqali kiritadi. Avval `waiters`, keyin `users` jadvalidan
qidiriladi.

**So'rov:**
```json
{ "pin": "1234" }
```

**Javob — ofitsiant (200):**
```json
{
  "token": "kJ8x2mQ...q7Z",
  "expires_at": "2026-08-19T02:30:00.000",
  "user": {
    "id": 5,
    "name": "Aziz",
    "role": "waiter",
    "permissions": ["print_receipt", "change_table"]
  }
}
```

**Javob — admin/kassir (200):**
```json
{
  "token": "9Fp1LbN...v3K",
  "expires_at": "2026-08-19T02:30:00.000",
  "user": {
    "id": 1,
    "name": "Admin",
    "role": "admin",
    "permissions": []
  }
}
```

**Xatolar:**

| Kod | Sabab |
|----|-------|
| `400` | PIN yuborilmadi |
| `401` | PIN noto'g'ri yoki xodim faol emas |
| `429` | Juda ko'p noto'g'ri urinish (pastga qarang) |

**Brute-force himoyasi.** Bir IP manzildan **5 daqiqada 5 ta** noto'g'ri
urinishdan keyin manzil **5 daqiqaga bloklanadi**:

```json
{
  "error": "Juda ko'p noto'g'ri urinish. 5 daqiqadan keyin qayta urinib ko'ring.",
  "retry_after": 287
}
```

Muvaffaqiyatli login hisoblagichni nolga qaytaradi.

---

### `GET /auth/me`

Joriy foydalanuvchini qaytaradi. Ma'lumot **bazadan yangilab** olinadi —
ilova ochiq turganda huquqlar o'zgargan bo'lishi mumkin.

```json
{
  "id": 5,
  "name": "Aziz",
  "role": "waiter",
  "permissions": ["print_receipt"],
  "expires_at": "2026-08-19T02:30:00.000"
}
```

Xodim o'chirilgan yoki faolsizlantirilgan bo'lsa — `401` va sessiya
avtomatik yopiladi.

---

### `POST /auth/logout`

Tokenni serverda bekor qiladi. Ilovadan chiqishda **albatta** chaqiring —
aks holda token 12 soat davomida ishlab qolaveradi.

```json
{ "success": true }
```

---

## 3. Ruxsatlar tizimi

### 3.1. Rollar

| Rol | Ta'rif |
|---|---|
| `admin` | To'liq huquq |
| `cashier` | To'liq huquq (POS operatsiyalari) |
| `waiter` | Cheklangan — faqat quyidagi granular huquqlar |

### 3.2. Ofitsiant huquqlari

`users`/`waiters` jadvalidagi `permissions` ustunida vergul bilan saqlanadi.

| ID | Ta'rif (UZ) | Qayerda tekshiriladi |
|---|---|---|
| `delete_item` | Taomni o'chirish | Mijoz ilovasi |
| `reduce_item` | Sonini kamaytirish | Mijoz ilovasi |
| `print_receipt` | Chek chiqarish | `POST /print_receipt` |
| `edit_price` | Narxni o'zgartirish | Mijoz ilovasi |
| `change_table` | Stolni almashtirish | `PUT /orders/<id>/move` |

Huquq yetmasa — `403`:
```json
{ "error": "Sizda \"change_table\" huquqi yo'q" }
```

### 3.3. 🔒 Faqat administrator uchun bo'limlar

Ofitsiant tokeni bilan quyidagi yo'llarga kirish **`403`** beradi. Bular
biznes uchun maxfiy ma'lumotlar:

```
/reports/*   (/reports/view dan tashqari)
/users, /users/<id>
/expenses, /expense_categories
/transactions
/customers
/waiters  → POST va DELETE (GET ochiq, lekin PIN kodlar yashiriladi)
```

> `GET /waiters` ofitsiantga ham ochiq, ammo javobdan `pin_code` maydoni
> olib tashlanadi. `GET /users` javobida `pin` hech qachon qaytarilmaydi.

---

## 4. Real-time kanal (WebSocket)

```
ws://192.168.1.10:8080/ws
```

Server holat o'zgarganda barcha ulangan mijozlarga xabar yuboradi. Xabar
faqat **signal** — ma'lumotning o'zi REST orqali olinadi.

**Xabar formati:**
```json
{ "event": "tables_updated", "ts": 1755512345678, "table_id": 4 }
```

| Event | Qachon | Qo'shimcha maydonlar |
|---|---|---|
| `tables_updated` | Stol band/bo'sh bo'ldi, buyurtma ko'chirildi, to'lov o'tdi | `table_id`, `location_id` (ba'zan) |
| `order_updated` | Buyurtma tarkibi o'zgardi | `order_id` |

Har bir xabarda `ts` — server vaqti (millisekund).

**Mijoz uchun tavsiya:** ulanish uzilsa avtomatik qayta ulanish (exponential
backoff) va har 20 soniyada `ping` yuborish — NAT/firewall ulanishni
yopib qo'ymasligi uchun. `WsClientService` shuni bajaradi.

---

## 5. Endpoint'lar

### 5.1. 📍 Zallar va stollar

| Metod | Yo'l | Ta'rif |
|---|---|---|
| `GET` | `/locations` | Barcha zal/xonalar |
| `POST` | `/locations` | Zal yaratish/yangilash |
| `DELETE` | `/locations/<id>` | Zalni o'chirish |
| `GET` | `/tables` | Stollar. Filtr: `?location_id=1` |
| `GET` | `/tables/summary` | **Asosiy ekran uchun** — stollar + faol buyurtma + ofitsiant |
| `POST` | `/tables` | Stol yaratish/yangilash (joylashuv, shakl, tarif) |
| `POST` | `/tables/merge` | Ikki stolni birlashtirish |
| `DELETE` | `/tables/<id>` | Stolni o'chirish |

#### `GET /tables/summary`

Ofitsiant ilovasining bosh ekrani uchun eng muhim endpoint — bitta so'rovda
zal nomi, stol holati, ochiq buyurtma summasi va ofitsiant nomini beradi.

```json
[
  {
    "id": 1,
    "location_id": 1,
    "location_name": "Yozgi ayvon",
    "name": "Stol #1",
    "status": 1,
    "pricing_type": 0,
    "hourly_rate": 0,
    "fixed_amount": 0,
    "service_percentage": 10,
    "active_order_id": "1712345678901",
    "order_id": "1712345678901",
    "order_total": 185000.0,
    "waiter_id": 5,
    "waiter_name": "Aziz",
    "bill_requested": 0,
    "opened_at": "2026-08-18T13:05:00.000",
    "x": 0.5, "y": 0.2, "width": 0.1, "height": 0.1, "shape": 0
  }
]
```

`status`: `0` — bo'sh, `1` — band.
`shape`: `0` — kvadrat, `1` — doira.
`x`/`y`/`width`/`height` — zal maydoniga nisbatan (`0.0`–`1.0`).

---

### 5.2. 📦 Mahsulotlar

| Metod | Yo'l | Ta'rif |
|---|---|---|
| `GET` | `/products` | Barcha mahsulotlar |
| `GET` | `/categories` | Menyu kategoriyalari |

```json
{
  "id": 10,
  "name": "Osh (Palov)",
  "price": 35000.0,
  "category": "Asosiy taomlar",
  "image_path": "1712345678.jpg",
  "unit": "portsiya",
  "quantity": 24.0,
  "track_type": 1,
  "is_set": 0,
  "is_active": 1,
  "no_service_charge": 0
}
```

> `image_path` faqat fayl nomi (to'liq yo'l emas) — rasmni
> `GET /uploads/<image_path>` orqali oling.
>
> `quantity` — ombor qoldig'i (agar `enable_inventory` yoqilgan bo'lsa).
> `no_service_charge: 1` — bu mahsulotga xizmat haqi qo'shilmaydi.

---

### 5.3. 👥 Xodimlar

| Metod | Yo'l | Ta'rif | Huquq |
|---|---|---|---|
| `GET` | `/waiters` | Ofitsiantlar ro'yxati | Hamma (PIN yashirin) |
| `POST` | `/waiters` | Yaratish/yangilash | 🔒 Admin |
| `DELETE` | `/waiters/<id>` | O'chirish (+ sessiyalarini yopadi) | 🔒 Admin |
| `GET` | `/users` | Admin/kassirlar (PIN'siz) | 🔒 Admin |
| `POST` | `/users` | Yaratish/yangilash | 🔒 Admin |
| `DELETE` | `/users/<id>` | O'chirish (+ sessiyalarini yopadi) | 🔒 Admin |

```json
{
  "id": 5,
  "name": "Aziz",
  "permissions": ["print_receipt", "change_table"],
  "type": 0,
  "value": 10,
  "is_active": 1
}
```

`type`: `0` — foizli xizmat haqi, `1` — qat'iy summa. `value` — foiz yoki summa.

---

### 5.4. 🛒 Buyurtmalar (asosiy POS oqimi)

| Metod | Yo'l | Ta'rif |
|---|---|---|
| `POST` | `/orders/open` | Stolga yangi buyurtma ochish |
| `GET` | `/orders/<id>` | Buyurtma + tarkibi |
| `POST` | `/orders/<id>/items` | Savatni serverga sinxronlash |
| `PUT` | `/orders/<id>/move` | Boshqa stolga ko'chirish |
| `POST` | `/orders/<id>/pay` | **To'lovni yakunlash** |
| `POST` | `/orders/<id>/bill_requested` | "Hisob so'raldi" belgisi |
| `DELETE` | `/orders/<id>/cancel` | Buyurtmani bekor qilish |

#### `POST /orders/open`

```json
{ "table_id": 1, "order_type": 0 }
```
`order_type`: `0` — zalda, `1` — saboy, `2` — yetkazib berish.

**Javob:**
```json
{ "order_id": "1712345678901" }
```

> `waiter_id` **tokendan** olinadi — mijoz uni o'zi tanlay olmaydi.
> Stolda ochiq buyurtma bo'lsa, `400` va mavjud `order_id` qaytadi.

#### `GET /orders/<id>`

```json
{
  "id": "1712345678901",
  "table_id": 1,
  "waiter_id": 5,
  "status": 0,
  "total": 185000.0,
  "grand_total": 203500.0,
  "food_total": 185000.0,
  "service_total": 18500.0,
  "room_charge": 0.0,
  "opened_at": "2026-08-18T13:05:00.000",
  "items": [
    {
      "id": 88,
      "order_id": "1712345678901",
      "product_id": 10,
      "product_name": "Osh (Palov)",
      "qty": 2.0,
      "price": 35000.0,
      "printed_qty": 2.0,
      "discount_amount": 0.0,
      "no_service_charge": 0,
      "category_id": "Asosiy taomlar"
    }
  ]
}
```

`status`: `0` — ochiq, `1` — to'langan, `2` — bekor qilingan.

#### `POST /orders/<id>/items`

Savatning **to'liq** holatini yuboradi (eskilari o'chirilib qayta yoziladi).

```json
{
  "items": [
    { "product_id": 10, "qty": 2, "price": 35000, "product_name": "Osh" },
    { "product_id": 22, "qty": 1, "price": 12000, "product_name": "Choy" }
  ]
}
```

> Server buyurtma egasini tekshiradi: ofitsiant **faqat o'ziga biriktirilgan**
> buyurtmani tahrirlay oladi. Admin/kassir uchun cheklov yo'q.
> Muvaffaqiyatda `order_updated` va `tables_updated` WS xabarlari yuboriladi.

#### `POST /orders/<id>/pay`

```json
{
  "payment_type": "Naqd",
  "paid_amount": 210000,
  "change": 6500,
  "food_total": 185000,
  "service_total": 18500,
  "room_charge": 0,
  "grand_total": 203500,
  "waiter_id": 5,
  "note": null
}
```

Server bitta tranzaksiyada: buyurtmani `status = 1` ga o'tkazadi, stolni
bo'shatadi, ombor qoldig'ini chegiradi va chekni chop etadi.

#### `PUT /orders/<id>/move` — `change_table` huquqi kerak

```json
{ "table_id": 7, "location_id": 2 }
```

#### `DELETE /orders/<id>/cancel`

Ofitsiant faqat **o'z** buyurtmasini bekor qila oladi. Admin/kassir esa
tarkibi bo'lgan buyurtmani ham bekor qila oladi.

---

### 5.5. 🖨 Chop etish

| Metod | Yo'l | Ta'rif | Huquq |
|---|---|---|---|
| `POST` | `/print_job` | Oshxona chekini chop etish (buyurtmani tasdiqlash) | — |
| `POST` | `/print_receipt` | Mijoz chekini chop etish | `print_receipt` |
| `GET` | `/printers` | Sozlangan printerlar ro'yxati | — |

`POST /print_job` — buyurtma tasdiqlanganda tayyor mahsulot qoldig'ini ham
chegiradi. Qoldiq yetmasa **`409`**:

```json
{ "error": "Osh (Palov): omborda 1 ta qoldi, 3 ta so'ralmoqda" }
```

> Mijoz `409` ni oddiy printer xatosidan ajratishi kerak — bu biznes xatosi,
> buyurtma tasdiqlanmagan.

---

### 5.6. 📊 Hisobotlar — 🔒 faqat admin/kassir

| Metod | Yo'l | Ta'rif |
|---|---|---|
| `GET` | `/reports/view` | Brauzer/Telegram WebApp uchun HTML panel (**token talab qilmaydi** — o'zi login so'raydi) |
| `GET` | `/reports/periods` | Mavjud hisobot davrlari |
| `GET` | `/reports/stats` | Umumiy ko'rsatkichlar |
| `GET` | `/reports/hourly` | Soatlik savdo |
| `GET` | `/reports/orders` | Buyurtmalar ro'yxati |
| `GET` | `/reports/products` | Mahsulotlar kesimida |
| `GET` | `/reports/waiters` | Ofitsiantlar samaradorligi |
| `GET` | `/reports/locations` | Zallar kesimida |
| `GET` | `/reports/tables` | Stollar kesimida |
| `GET` | `/reports/shifts` | Smenalar tarixi. `?limit=20` |
| `GET` | `/reports/zreport` | Z-hisobot (smena yakuni) |

Umumiy filtr parametrlari: `?start=2026-08-01&end=2026-08-18`.

---

### 5.7. 💰 Kassa va mijozlar — 🔒 faqat admin/kassir

| Metod | Yo'l | Ta'rif |
|---|---|---|
| `GET` | `/transactions` | To'lovlar va qarzlar tarixi |
| `POST` | `/transactions` | Yangi to'lov/qarz yozuvi |
| `GET` | `/customers` | Mijozlar (telefon raqamlari — shaxsiy ma'lumot) |
| `POST` | `/customers` | Mijoz yaratish/yangilash |
| `DELETE` | `/customers/<id>` | Mijozni o'chirish |
| `GET` | `/expenses` | Xarajatlar |
| `POST` | `/expenses` | Xarajat qo'shish |
| `DELETE` | `/expenses/<id>` | Xarajatni o'chirish |
| `GET` | `/expense_categories` | Xarajat turlari |
| `POST` | `/expense_categories` | Xarajat turi qo'shish |

---

### 5.8. ⚙️ Sozlamalar

#### `GET /settings`

Mijoz ilovasiga kerakli sozlamalarni qaytaradi (oq ro'yxat — boshqa
sozlamalar tarmoqqa chiqmaydi):

```
restaurant_name, receipt_restaurant_name, receipt_branch_name,
receipt_phone, receipt_address, receipt_footer_message,
receipt_show_room_charges, receipt_layout_type, receipt_cut_paper,
receipt_feed_lines, receipt_horizontal_margin,
kitchen_header_text, kitchen_font_large, kitchen_group_by_category,
kitchen_show_order_number, kitchen_show_table, kitchen_show_waiter,
kitchen_cut_paper, kitchen_feed_lines,
auto_confirm_order, enable_inventory
```

---

### 5.9. 🖼 Rasmlar

| Metod | Yo'l | Ta'rif |
|---|---|---|
| `POST` | `/upload/image` | Rasm yuklash. **Body — xom baytlar** (JSON emas) |
| `GET` | `/uploads/<fileName>` | Rasmni olish (**token talab qilmaydi**) |

`POST /upload/image` javobi:
```json
{ "fileName": "1712345678.jpg" }
```

> `GET /uploads/...` ochiq qoldirilgan, chunki brauzer va Flutter'ning
> `Image.network` vidjeti `<img>` so'roviga `Authorization` sarlavhasini
> qo'sha olmaydi.

---

## 6. Xato kodlari

| Kod | Ma'nosi | Nima qilish kerak |
|---|---|---|
| `200` | Muvaffaqiyat | — |
| `400` | Noto'g'ri so'rov yoki biznes qoidasi buzildi (masalan, stol allaqachon band) | Xabarni foydalanuvchiga ko'rsating |
| `401` | Token yo'q, yaroqsiz yoki muddati tugagan | **Login ekraniga qaytaring** va qayta kiring |
| `403` | Kirdingiz, lekin huquqingiz yetmaydi | Amalni bloklang, sababni ko'rsating |
| `404` | Obyekt topilmadi | — |
| `409` | Ombor qoldig'i yetmaydi | Buyurtma tasdiqlanmadi, foydalanuvchiga ayting |
| `429` | Login urinishlari cheklandi | `retry_after` soniya kuting |
| `500` | Server xatosi | Qayta urinish, xatoni loglash |

**Xato javobi formati** (barcha kodlar uchun bir xil):
```json
{ "error": "Tushunarli xabar" }
```

---

## 7. Mijoz uchun tavsiyalar

**1. `401` ni markazlashgan holda ushlang.** Har so'rovdan keyin
`401` kelsa — tokenni tozalab, login ekraniga qayting. Zelly'ning o'z
mijozi (`ConnectivityProvider._handleUnauthorized`) shunday qiladi.

**2. Chiqishda `/auth/logout` chaqiring.** Aks holda token 12 soat ishlaydi.

**3. Ma'lumotni WebSocket signaliga qarab yangilang**, har soniyada
so'rov yubormang (polling). `tables_updated` kelganda
`GET /tables/summary` ni bir marta chaqiring.

**4. `waiter_id` ni o'zingiz yubormang** — server uni tokendan oladi.

**5. Rasmlarni keshlang.** `image_path` fayl nomi o'zgarmaydi, shuning uchun
uni doimiy keshlash mumkin.

---

## 8. Ma'lum cheklovlar

Bular hujjatlangan, chunki mijoz ilovasi ularni hisobga olishi kerak:

| Cheklov | Ta'sir | Reja |
|---|---|---|
| **HTTP (TLS yo'q)** | Bir tarmoqdagi qurilma trafikni o'qishi mumkin. Kafe ichki Wi-Fi'sini mehmonlar tarmog'idan ajrating. | Self-signed TLS |
| **PIN'lar bazada ochiq matnda** | Bazaga fizik kirish = PIN'lar oshkor | PIN hash (bcrypt) |
| **Pagination yo'q** | `GET /transactions`, `/reports/orders` butun tarixni qaytaradi — bir yillik kafeda javob katta bo'ladi | `?limit`/`?offset` |
| **API versiyalash yo'q** | Yo'llar `/v1/` prefiksisiz | `/v1/` joriy qilish |
| **WebSocket'da token tekshirilmaydi** | Kanal faqat "nimadir o'zgardi" signalini yuboradi (ID'lardan boshqa ma'lumot yo'q), shuning uchun xavf past | Query-token bilan tekshirish |
| **Rate limit faqat login'da** | Boshqa endpoint'lar cheklanmagan | Umumiy rate limit |

---

## 9. O'zgarishlar tarixi

### v2.0 — 2026-08-18

**Buzuvchi o'zgarish:** eski `admin-token-<id>` / `waiter-token-<id>`
tokenlari **ishlamaydi**. Mijozlar `/auth/login` orqali yangi token olishi shart.

- Tasodifiy, muddatli, bekor qilinadigan token tizimi (`api_sessions`)
- Barcha endpoint'lar uchun markazlashgan autentifikatsiya qatlami
  (ilgari faqat ba'zi endpoint'lar tekshirardi)
- Login uchun brute-force himoyasi (`429`)
- Hisobot/xodim/mijoz/xarajat bo'limlari ofitsiantlar uchun yopildi
- `GET /users` javobidan `pin`, `GET /waiters` javobidan (ofitsiant uchun)
  `pin_code` olib tashlandi
- `POST /auth/logout` qo'shildi
- Noto'g'ri PIN uchun `403` → **`401`** (to'g'ri semantika)
- Hujjatga qo'shildi: WebSocket kanali, `/orders/<id>/pay`, `/reports/*`,
  `/settings`, `/printers`, `/transactions`, `/customers`, `/expenses`,
  `/users`, `/tables/merge`, `/orders/<id>/move`,
  `/orders/<id>/bill_requested`, `/auth/me` — jami 34 ta hujjatlanmagan
  endpoint

### v1.0

Dastlabki hujjat (~25 endpoint).
