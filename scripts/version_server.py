#!/usr/bin/env python3
"""
Zelly POS Auto-Update Server
FastAPI based version management server
"""

from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from typing import Optional, Dict, List
import json
import os
from datetime import datetime
import uvicorn
import hashlib

app = FastAPI(
    title="Zelly POS Update Server",
    description="Auto-update server for Zelly POS application",
    version="1.0.0"
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["*"],
)

# Version database
VERSIONS = {
    "1.0.2": {
        "version": "1.0.2",
        "build_number": "3",
        "download_url": "https://your-server.com/updates/updater_v102.exe",
        "release_notes": """- Stol o'zgartirish dialogi yaxshilandi
- Auto-update funksiyasi qo'shildi
- Xatoliklar tuzatildi""",
        "mandatory": False,
        "min_supported_version": "1.0.0",
        "release_date": "2026-02-23",
        "file_size": "15.2 MB",
        "sha256_hash": "a1b2c3d4e5f6...",  # Fayl hash
        "changelog_url": "https://your-server.com/changelog/1.0.2"
    },
    "1.0.3": {
        "version": "1.0.3", 
        "build_number": "4",
        "download_url": "https://your-server.com/updates/updater_v103.exe",
        "release_notes": """- Yangi hisobotlar qo'shildi
- Performance yaxshilandi
- Xavfsizlik patchlari""",
        "mandatory": True,
        "min_supported_version": "1.0.1",
        "release_date": "2026-03-01",
        "file_size": "16.1 MB",
        "sha256_hash": "f6e5d4c3b2a1...",
        "changelog_url": "https://your-server.com/changelog/1.0.3"
    }
}

class UpdateCheckRequest(BaseModel):
    current_version: str
    platform: str = "windows"
    architecture: str = "x64"
    user_id: Optional[str] = None

class UpdateInfo(BaseModel):
    version: str
    build_number: str
    download_url: str
    release_notes: str
    mandatory: bool
    min_supported_version: str
    release_date: str
    file_size: str
    sha256_hash: str
    changelog_url: str

class UpdateResponse(BaseModel):
    update_available: bool
    current_version: str
    latest_version: Optional[str] = None
    update_info: Optional[UpdateInfo] = None
    message: str

# Log fayli
LOG_FILE = "update_logs.txt"

def log_update_check(client_ip: str, user_agent: str, current_version: str, update_available: bool):
    """Update checklarni log qilish"""
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    log_entry = f"{timestamp} - IP: {client_ip} - Version: {current_version} - Update: {update_available} - UA: {user_agent}\n"
    
    try:
        with open(LOG_FILE, "a", encoding="utf-8") as f:
            f.write(log_entry)
    except Exception as e:
        print(f"Log yozish xatoligi: {e}")

def get_latest_version() -> str:
    """Eng so'ngi versiyani olish"""
    versions = list(VERSIONS.keys())
    versions.sort(key=lambda x: tuple(map(int, x.split('.'))))
    return versions[-1] if versions else "1.0.0"

def is_newer_version(new_version: str, old_version: str) -> bool:
    """Versiyani solishtirish"""
    try:
        new_parts = list(map(int, new_version.split('.')))
        old_parts = list(map(int, old_version.split('.')))
        
        # Uzunlikni tenglashtirish
        max_len = max(len(new_parts), len(old_parts))
        new_parts.extend([0] * (max_len - len(new_parts)))
        old_parts.extend([0] * (max_len - len(old_parts)))
        
        return new_parts > old_parts
    except:
        return False

@app.get("/")
async def root():
    """Root endpoint"""
    return {
        "service": "Zelly POS Update Server",
        "version": "1.0.0",
        "status": "running",
        "timestamp": datetime.now().isoformat()
    }

@app.get("/health")
async def health_check():
    """Health check"""
    return {"status": "healthy", "timestamp": datetime.now().isoformat()}

@app.post("/check", response_model=UpdateResponse)
async def check_for_updates(request: UpdateCheckRequest, http_request: Request):
    """Yangilash borligini tekshirish"""
    
    try:
        current_version = request.current_version
        latest_version = get_latest_version()
        
        # Log yozish
        client_ip = http_request.client.host if http_request.client else "unknown"
        user_agent = http_request.headers.get("user-agent", "unknown")
        
        update_available = is_newer_version(latest_version, current_version)
        
        log_update_check(client_ip, user_agent, current_version, update_available)
        
        if update_available and latest_version in VERSIONS:
            update_info = VERSIONS[latest_version]
            return UpdateResponse(
                update_available=True,
                current_version=current_version,
                latest_version=latest_version,
                update_info=UpdateInfo(**update_info),
                message=f"Update available: {latest_version}"
            )
        else:
            return UpdateResponse(
                update_available=False,
                current_version=current_version,
                message="You have the latest version"
            )
            
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Update check failed: {str(e)}")

@app.get("/version/{version}")
async def get_version_info(version: str):
    """Ma'lum versiya haqida ma'lumot"""
    
    if version not in VERSIONS:
        raise HTTPException(status_code=404, detail="Version not found")
    
    return VERSIONS[version]

@app.get("/versions")
async def list_all_versions():
    """Barcha versiyalar ro'yxati"""
    return {
        "versions": VERSIONS,
        "latest": get_latest_version(),
        "total_versions": len(VERSIONS)
    }

@app.post("/download/{version}")
async def get_download_info(version: str):
    """Download ma'lumotlari"""
    
    if version not in VERSIONS:
        raise HTTPException(status_code=404, detail="Version not found")
    
    version_info = VERSIONS[version]
    
    # Haqiqiy fayl mavjudligini tekshirish (agar kerak bo'lsa)
    # Bu yerda siz fayl mavjudligini tekshirishingiz mumkin
    
    return {
        "download_url": version_info["download_url"],
        "file_size": version_info["file_size"],
        "sha256_hash": version_info["sha256_hash"],
        "download_count": 0, # Bu ma'lumotni database dan olishingiz mumkin
        "last_updated": version_info["release_date"]
    }

@app.get("/changelog/{version}")
async def get_changelog(version: str):
    """Changelog olish"""
    
    if version not in VERSIONS:
        raise HTTPException(status_code=404, detail="Version not found")
    
    return {
        "version": version,
        "release_notes": VERSIONS[version]["release_notes"],
        "release_date": VERSIONS[version]["release_date"],
        "changelog_url": VERSIONS[version]["changelog_url"]
    }

@app.get("/stats")
async def get_update_stats():
    """Update statistikasi"""
    
    try:
        # Log faylini o'qish
        if os.path.exists(LOG_FILE):
            with open(LOG_FILE, "r", encoding="utf-8") as f:
                lines = f.readlines()
            
            total_checks = len(lines)
            recent_checks = len([line for line in lines if "2026-02-23" in line]) # Bugungi
            
            return {
                "total_update_checks": total_checks,
                "recent_checks_24h": recent_checks,
                "latest_version": get_latest_version(),
                "server_uptime": datetime.now().isoformat()
            }
        else:
            return {
                "total_update_checks": 0,
                "recent_checks_24h": 0,
                "latest_version": get_latest_version(),
                "server_uptime": datetime.now().isoformat()
            }
            
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Stats failed: {str(e)}")

# Static files serving (agar kerak bo'lsa)
# from fastapi.staticfiles import StaticFiles
# app.mount("/updates", StaticFiles(directory="updates"), name="updates")

if __name__ == "__main__":
    print("🚀 Zelly POS Update Server is starting...")
    print(f"📊 Latest version: {get_latest_version()}")
    print(f"📝 Total versions: {len(VERSIONS)}")
    print("🌐 Server running on: http://localhost:8000")
    print("📖 Docs available at: http://localhost:8000/docs")
    
    uvicorn.run(
        "version_server:app",
        host="0.0.0.0",
        port=8000,
        reload=True,
        log_level="info"
    )
