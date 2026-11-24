#!/usr/bin/env bash
# Echo Orchard — local keystore generator (macOS / Linux / Git Bash)
#
# Generates a JKS release keystore from values YOU type in, then prints the
# base64 the GitHub Actions workflow needs. It collects NOTHING automatically:
# no system, user, IP, or location data is read or auto-filled. Every field
# below is whatever you enter.
#
# Requires: keytool (bundled with any JDK; e.g. Temurin 17).
#
# Usage:
#   bash scripts/generate_keystore.sh

set -euo pipefail

echo "Echo Orchard release keystore generator"
echo "Enter your company details (used only for the certificate)."
echo

# --- Company details (at least 5 fields) -----------------------------------
read -r -p "1. Company / Organization name (CN, O): " COMPANY
read -r -p "2. Organizational unit (OU, e.g. Mobile): " ORG_UNIT
read -r -p "3. City / Locality (L): " CITY
read -r -p "4. State / Province (ST): " STATE
read -r -p "5. Two-letter country code (C, e.g. US): " COUNTRY

# --- Key settings -----------------------------------------------------------
read -r -p "6. Key alias (e.g. echoorchard): " ALIAS
read -r -p "7. Validity in days (recommended 10000): " VALIDITY
read -r -s -p "8. Keystore (store) password: " STORE_PASS; echo
read -r -s -p "9. Key password: " KEY_PASS; echo

if [ -z "$COMPANY" ] || [ -z "$ALIAS" ] || [ -z "$STORE_PASS" ]; then
  echo "ERROR: company name, alias, and store password are required." >&2
  exit 1
fi
[ -z "$VALIDITY" ] && VALIDITY=10000

KEYSTORE_FILE="echoorchard-release.jks"
DNAME="CN=$COMPANY, OU=$ORG_UNIT, O=$COMPANY, L=$CITY, ST=$STATE, C=$COUNTRY"

if [ -f "$KEYSTORE_FILE" ]; then
  echo "ERROR: $KEYSTORE_FILE already exists. Move or delete it first." >&2
  exit 1
fi

echo
echo "Generating $KEYSTORE_FILE ..."
keytool -genkeypair -v \
  -keystore "$KEYSTORE_FILE" \
  -storetype JKS \
  -keyalg RSA -keysize 2048 \
  -validity "$VALIDITY" \
  -alias "$ALIAS" \
  -storepass "$STORE_PASS" \
  -keypass "$KEY_PASS" \
  -dname "$DNAME"

BASE64_FILE="$KEYSTORE_FILE.base64.txt"
base64 < "$KEYSTORE_FILE" | tr -d '\n' > "$BASE64_FILE"

echo
echo "Done."
echo "Keystore : $KEYSTORE_FILE"
echo "Base64   : $BASE64_FILE"
echo
echo "Add these GitHub repository secrets"
echo "  (Settings -> Secrets and variables -> Actions -> New repository secret):"
echo "  EchoOrchardKeystoreBase64 = contents of $BASE64_FILE"
echo "  EchoOrchardStorePassword  = the store password you just entered"
echo "  EchoOrchardKeyPassword    = the key password you just entered"
echo "  EchoOrchardKeyAlias       = $ALIAS"
echo
echo "Keep $KEYSTORE_FILE somewhere safe and OFFLINE. It is git-ignored."
echo "Losing it means you can never update the app on Play again."
