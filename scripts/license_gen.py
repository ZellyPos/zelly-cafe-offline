import json
import base64
import os
from datetime import datetime
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.asymmetric import padding
from cryptography.hazmat.primitives import serialization

def sign_license(payload_json, private_key_path="private_key.pem"):
    """Litsenziya payload-ini imzolaydi."""
    # PAYLOAD NORMALIZAGIYA (Dart toCanonicalJson() bilan bir xil bo'lishi shart)
    # Dart: jsonEncode(_sortMap(toMap()))
    payload_data = json.loads(payload_json)
    
    # Dart: toMap() returns snake_case keys for all fields
    # Biz Python-da sort_keys=True va separators=(',', ':') ishlatamiz
    canonical_json = json.dumps(payload_data, sort_keys=True, separators=(',', ':'))
    
    with open(private_key_path, "rb") as key_file:
        private_key = serialization.load_pem_private_key(
            key_file.read(),
            password=None
        )
    
    signature = private_key.sign(
        canonical_json.encode('utf-8'),
        padding.PKCS1v15(),
        hashes.SHA256()
    )
    
    return base64.b64encode(signature).decode('utf-8')

def create_license(device_id, expiry_date_str, company="Zelly User", private_key_path="private_key.pem"):
    """To'liq license.json faylini yaratadi."""
    # EXPIRE DATE NORMALIZATSIYASI (Dart toIso8601String() bilan bir xil: YYYY-MM-DDTHH:MM:SS)
    try:
        if "T" not in expiry_date_str:
            # Faqat sana berilgan bo'lsa, T00:00:00 qo'shamiz
            dt = datetime.strptime(expiry_date_str, "%Y-%m-%d")
            expiry_norm = dt.strftime("%Y-%m-%dT%H:%M:%S")
        else:
            # To'liq format bo'lsa, microsecondsiz qilib olamiz
            dt = datetime.fromisoformat(expiry_date_str)
            expiry_norm = dt.strftime("%Y-%m-%dT%H:%M:%S")
    except Exception as e:
        print(f"Sana formati xato! (Kutilgan: YYYY-MM-DD): {e}")
        return

    now_str = datetime.now().strftime("%Y-%m-%dT%H:%M:%S")
    
    payload = {
        "company": company,
        "device_id": device_id,
        "expiry": expiry_norm,
        "features": {
            "ai_analytics": True,
            "inventory_mgmt": True,
            "multi_printer": True
        },
        "issued_at": now_str,
        "plan": "PREMIUM",
        "product": "Zelly POS"
    }
    
    # Payload-ni JSON-ga o'tkazish
    payload_json = json.dumps(payload)
    signature = sign_license(payload_json, private_key_path)
    
    license_file = {
        "payload": payload,
        "signature": signature
    }
    
    with open("license.json", "w") as f:
        json.dump(license_file, f, indent=4)
    
    print("-" * 40)
    print("LITSENZIYA YARATILDI: license.json")
    print(f"HWID: {device_id}")
    print(f"MUDDATI: {expiry_date_str}")
    print(f"KOMPANIYA: {company}")
    print("-" * 40)

if __name__ == "__main__":
    if not os.path.exists("private_key.pem"):
        print("Xatolik: private_key.pem topilmadi!")
    else:
        print("=== Zelly POS Litsenziya Generator ===")
        hwid = input("Qurilma ID (HWID): ").strip()
        if not hwid:
            print("Xatolik: HWID bo'sh bo'lishi mumkin emas!")
        else:
            expiry = input("Muddati (YYYY-MM-DD): ").strip() or "2026-12-31"
            name = input("Kompaniya nomi: ").strip() or "Zelly POS User"
            create_license(hwid, expiry, name)
