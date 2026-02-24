#!/usr/bin/env python3
"""
Zelly POS Update Server - Quick Start Script
"""

import os
import sys
import subprocess

def check_dependencies():
    """Dependencies ni tekshirish"""
    try:
        import fastapi
        import uvicorn
        print("✅ Dependencies already installed")
        return True
    except ImportError:
        print("📦 Installing dependencies...")
        subprocess.check_call([sys.executable, "-m", "pip", "install", "-r", "requirements.txt"])
        return True

def create_log_file():
    """Log faylini yaratish"""
    if not os.path.exists("update_logs.txt"):
        with open("update_logs.txt", "w", encoding="utf-8") as f:
            f.write("Zelly POS Update Server - Log Started\n")
            f.write("=" * 50 + "\n")
        print("📝 Log file created")

def main():
    print("🚀 Starting Zelly POS Update Server...")
    print("=" * 50)
    
    # Papkani tekshirish
    if not os.path.exists("version_server.py"):
        print("❌ Error: version_server.py not found!")
        sys.exit(1)
    
    # Dependencies ni tekshirish
    if not check_dependencies():
        print("❌ Failed to install dependencies")
        sys.exit(1)
    
    # Log faylini yaratish
    create_log_file()
    
    # Serverni ishga tushirish
    print("🌐 Starting server on http://localhost:8000")
    print("📖 API docs: http://localhost:8000/docs")
    print("🔍 Health check: http://localhost:8000/health")
    print("=" * 50)
    
    try:
        import uvicorn
        uvicorn.run(
            "version_server:app",
            host="0.0.0.0",
            port=8000,
            reload=True,
            log_level="info"
        )
    except KeyboardInterrupt:
        print("\n👋 Server stopped by user")
    except Exception as e:
        print(f"❌ Server error: {e}")

if __name__ == "__main__":
    main()
