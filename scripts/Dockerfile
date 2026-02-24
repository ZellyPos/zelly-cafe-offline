FROM python:3.11-slim

WORKDIR /app

# Requirements ni o'rnatish
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Kodni nusxalash
COPY version_server.py .

# Log fayli uchun papka
RUN mkdir -p /app/logs

# Port ochish
EXPOSE 8000

# Environment variables
ENV PYTHONUNBUFFERED=1

# Serverni ishga tushirish
CMD ["uvicorn", "version_server:app", "--host", "0.0.0.0", "--port", "8000"]
