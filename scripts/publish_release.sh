#!/usr/bin/env bash
# GitHub'da release yaratib, installerni yuklaydi.
#
# Avto-yangilanish `zellyuz/zellyoffline` repozitoriyasining OXIRGI
# release'idan o'qiydi (lib/core/update_service.dart), shuning uchun
# release aynan o'sha yerga chiqadi.
#
# Ishlatish:
#   bash scripts/publish_release.sh 1.0.19
#
# Token git credential manager'dan olinadi (git push ishlayotgan bo'lsa,
# u yerda bor). Xohlasangiz GITHUB_TOKEN bilan ham berish mumkin.

set -euo pipefail

VERSION="${1:-}"
if [ -z "$VERSION" ]; then
  echo "Ishlatish: bash scripts/publish_release.sh <versiya>   (masalan 1.0.19)" >&2
  exit 2
fi

REPO="zellyuz/zellyoffline"
TAG="v$VERSION"
ASSET="$HOME/Desktop/ZellySetup_$VERSION.exe"
NOTES_FILE="${NOTES_FILE:-}"

if [ ! -f "$ASSET" ]; then
  echo "Installer topilmadi: $ASSET" >&2
  echo "Avval:  flutter build windows --release" >&2
  echo "        '/c/Program Files (x86)/Inno Setup 6/ISCC.exe' zelly_installer.iss" >&2
  exit 1
fi

TOKEN="${GITHUB_TOKEN:-}"
if [ -z "$TOKEN" ]; then
  TOKEN=$(printf "protocol=https\nhost=github.com\n\n" \
          | git credential fill | grep '^password=' | cut -d= -f2-)
fi
if [ -z "$TOKEN" ]; then
  echo "GitHub token topilmadi. GITHUB_TOKEN=... qilib bering." >&2
  exit 1
fi

echo "Repo:      $REPO"
echo "Teg:       $TAG"
echo "Installer: $ASSET ($(du -h "$ASSET" | cut -f1))"
echo

# Teg mavjudligini tekshiramiz — release faqat mavjud tegga ishora qilsin.
if ! git rev-parse "$TAG" >/dev/null 2>&1; then
  echo "Lokal '$TAG' tegi yo'q. Avval:" >&2
  echo "  git tag -a $TAG -m 'Versiya $VERSION' && git push zellyuz $TAG" >&2
  exit 1
fi

# ── 1. Release yaratish ──────────────────────────────────────────────────
BODY_FILE=$(mktemp)
if [ -n "$NOTES_FILE" ] && [ -f "$NOTES_FILE" ]; then
  NOTES=$(cat "$NOTES_FILE")
else
  NOTES="Zelly POS $VERSION"
fi

# JSON'ni node bilan xavfsiz yig'amiz (qo'lda qochirishda xato oson).
node -e '
const fs = require("fs");
const [tag, name, notes, out] = process.argv.slice(1);
fs.writeFileSync(out, JSON.stringify({
  tag_name: tag, target_commitish: "main", name: name,
  body: notes, draft: false, prerelease: false,
}));
' "$TAG" "VERSION $VERSION" "$NOTES" "$BODY_FILE"

echo "Release yaratilmoqda..."
RESP=$(mktemp)
CODE=$(curl -s -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Accept: application/vnd.github+json" \
  -H "Content-Type: application/json" \
  --data-binary "@$BODY_FILE" \
  "https://api.github.com/repos/$REPO/releases" \
  -o "$RESP" -w '%{http_code}')

if [ "$CODE" != "201" ]; then
  echo "Release yaratilmadi (HTTP $CODE):" >&2
  head -c 500 "$RESP" >&2; echo >&2
  exit 1
fi

RELEASE_ID=$(node -e 'console.log(JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")).id)' "$RESP")
HTML_URL=$(node -e 'console.log(JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")).html_url)' "$RESP")
echo "  ✓ yaratildi (id=$RELEASE_ID)"

# ── 2. Installerni biriktirish ───────────────────────────────────────────
echo "Installer yuklanmoqda (~16 MB)..."
UP=$(mktemp)
CODE=$(curl -s -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Accept: application/vnd.github+json" \
  -H "Content-Type: application/octet-stream" \
  --data-binary "@$ASSET" \
  "https://uploads.github.com/repos/$REPO/releases/$RELEASE_ID/assets?name=ZellySetup_$VERSION.exe" \
  -o "$UP" -w '%{http_code}')

if [ "$CODE" != "201" ]; then
  echo "Fayl yuklanmadi (HTTP $CODE):" >&2
  head -c 500 "$UP" >&2; echo >&2
  echo "Release yaratilgan, faylni qo'lda biriktiring: $HTML_URL" >&2
  exit 1
fi
echo "  ✓ yuklandi"

# ── 3. Tekshirish ────────────────────────────────────────────────────────
echo
echo "Avto-yangilanish shu javobni oladi:"
curl -s "https://api.github.com/repos/$REPO/releases/latest" \
  | grep -E '"tag_name"|"browser_download_url"'
echo
echo "Tayyor: $HTML_URL"
