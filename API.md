# Zelly POS - API Documentation (Professional v1.0)

This documentation provides a comprehensive guide for developers building mobile or web applications that integrate with the Zelly POS internal server.

## 1. General Information

### Base URL
The server runs locally on the POS machine or as a central server in the network.
- **Example**: `http://192.168.1.10:8080`

### Headers
Every request (except `/auth/login`) must include the authentication token.
- `Authorization: Bearer <your_token>`
- `Content-Type: application/json`

---

## 2. Authentication

### POST `/auth/login`
Authenticates a user (Admin/Cashier) or a Waiter via PIN.

**Request:**
```json
{
  "pin": "1234"
}
```

**Successful Response (Admin/Cashier):**
```json
{
  "token": "admin-token-1",
  "user": {
    "id": 1,
    "name": "Admin",
    "role": "admin" 
  }
}
```

**Successful Response (Waiter):**
```json
{
  "token": "waiter-token-5",
  "user": {
    "id": 5,
    "name": "Aziz",
    "role": "waiter",
    "permissions": ["print_receipt", "change_table"]
  }
}
```

---

## 3. Permission System

Waiters have granular permissions. Admins have all permissions by default.

| Permission ID | Description (UZ) | Description (RU) |
|---------------|------------------|------------------|
| `delete_item` | Taomni o'chirish | Удаление блюда |
| `reduce_item` | Soni kamaytirish | Уменьшение кол-ва |
| `print_receipt`| Chek chiqarish  | Печать чека |
| `edit_price`  | Narxni o'zgartirish | Изменение цены |
| `change_table`| Stolni almashtirish | Смена стола |

---

## 4. Entity Models

### Product
```json
{
  "id": 10,
  "name": "Osh (Palov)",
  "price": 35000.0,
  "category": "Asosiy taomlar",
  "image_path": "1712345678.jpg",
  "unit": "portsiya",
  "is_active": 1,
  "no_service_charge": 0
}
```

### Table
```json
{
  "id": 1,
  "location_id": 1,
  "name": "Stol #1",
  "status": 0, // 0: Bo'sh, 1: Band
  "active_order_id": "1712345678901",
  "x": 0.5, "y": 0.2, // Koordinatalar (0.0 - 1.0)
  "width": 0.1, "height": 0.1,
  "shape": 0 // 0:kvadrat, 1:doira
}
```

---

## 5. Endpoints Checklist

### 📍 Locations & Tables
- `GET /locations`: List all zones/rooms.
- `POST /locations`: Create/Update location.
- `DELETE /locations/<id>`: Delete location.
- `GET /tables`: List all tables. Query `?location_id=1` for filtering.
- `GET /tables/summary`: Detailed table status including active order totals and waiter names.
- `POST /tables`: Create/Update table (position, shape, rates).
- `DELETE /tables/<id>`: Delete table.

### 📦 Products & Inventory
- `GET /products`: List all active products.
- `GET /categories`: List all menu categories.
- `GET /inventory`: (Coming soon) Stock levels and movements.

### 👥 Waiters & Management
- `GET /waiters`: List all waiters with their configurations.
- `POST /waiters`: Create/Update waiter (Name, PIN, Permissions, Percentage).
- `DELETE /waiters/<id>`: Delete waiter.

### 🛒 Orders (Core POS Flow)
- `POST /orders/open`: Open a new order for a table.
  - Body: `{ "table_id": 1, "order_type": 0 }`
  - Returns: `{ "order_id": "..." }`
- `GET /orders/<id>`: Get full order details including items.
- `POST /orders/<id>/items`: Update items in an order (Sync cart).
  - Body: `{ "items": [ { "product_id": 1, "qty": 2, "price": 10000, "product_name": "..." } ] }`
- `DELETE /orders/<id>/cancel`: Cancel an empty order to free the table.

### 📊 Reports & Activity
- `GET /reports/view`: HTML response formatted for Telegram WebApp or Browser monitoring.
- `GET /transactions`: History of payments and debts.
- `POST /transactions`: Register a new payment/debt entry.

### 🖼️ Media
- `POST /upload/image`: Upload product image (Binary body). Returns `fileName`.
- `GET /uploads/<fileName>`: Retrieve image.

---

## 6. Success & Error Codes

- `200 OK`: Request was successful.
- `400 Bad Request`: Validation error or invalid logic (e.g., table already occupied).
- `401 Unauthorized`: Token missing or expired.
- `403 Forbidden`: Insufficient permissions (Wrong PIN or role lacks permission).
- `404 Not Found`: Entity (Order, Product, etc.) not found.
