## Ombor

- **Mahsulotlar sahifasiga kategoriya tanlagichi qo'shildi.** Ilgari kategoriya faqat kartochkadagi mayda yozuv edi — endi yuqorida tanlanadi.
- **Pishirish oynasida ham kategoriyalar** paydo bo'ldi (ixcham ko'rinishda).
- Harakatlar tarixi mahsulot o'chirilganda ham saqlanadi; saqlash muddati sozlanadi (default 24 oy).

## Xavfsizlik

> **DIQQAT — ofitsiant ilovalari bir marta qayta kirishi kerak.**
> Eski kirish kalitlari (`admin-token-…`) endi ishlamaydi. Telefonda PIN kodni qaytadan kiritish yetarli, ma'lumot yo'qolmaydi.

Serverga kirish tizimi butunlay qayta yozildi. Ilgari kalit taxmin qilinadigan edi — bir xil tarmoqdagi istalgan qurilma PIN kodsiz admin huquqini olishi mumkin edi. Endi:

- kalit tasodifiy, 12 soatlik va istalgan payt bekor qilinadi
- xodim o'chirilsa uning qurilmasi darhol kirishdan chiqadi
- PIN kodni taxmin qilishga urinish cheklandi (5 marta xato → 5 daqiqa blok)
- PIN kodlar endi tarmoq orqali uzatilmaydi
- savdo hisobotlari, mijozlar bazasi va xarajatlar ofitsiantlarga yopildi

## Ichki yaxshilanishlar

- Kod tahlili 393 ta ogohlantirishdan 10 taga tushdi
- Avtomatik testlar: 67 ta, hammasi o'tadi (ilgari 5 tasi yiqilardi)
- API hujjati to'liq qayta yozildi (`API.md`)
