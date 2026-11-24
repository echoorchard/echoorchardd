# Echo Orchard — local keystore generator (Windows / PowerShell)
#
# Generates a JKS release keystore from values YOU type in, then prints the
# base64 the GitHub Actions workflow needs. It collects NOTHING automatically:
# no system, user, IP, or location data is read or auto-filled. Every field
# below is whatever you enter.
#
# Requires: keytool (bundled with any JDK; e.g. Temurin 17).
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File scripts\generate_keystore.ps1

$ErrorActionPreference = "Stop"

Write-Host "Echo Orchard release keystore generator" -ForegroundColor Green
Write-Host "Enter your company details (used only for the certificate)." -ForegroundColor Cyan
Write-Host ""

# --- Company details (at least 5 fields) -----------------------------------
$company  = Read-Host "1. Company / Organization name (CN, O)"
$orgUnit  = Read-Host "2. Organizational unit (OU, e.g. Mobile)"
$city     = Read-Host "3. City / Locality (L)"
$state    = Read-Host "4. State / Province (ST)"
$country  = Read-Host "5. Two-letter country code (C, e.g. US)"

# --- Key settings -----------------------------------------------------------
$alias    = Read-Host "6. Key alias (e.g. echoorchard)"
$validity = Read-Host "7. Validity in days (recommended 10000)"

$storePassSecure = Read-Host "8. Keystore (store) password" -AsSecureString
$keyPassSecure   = Read-Host "9. Key password" -AsSecureString

$storePass = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($storePassSecure))
$keyPass = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($keyPassSecure))

if ([string]::IsNullOrWhiteSpace($company) -or
    [string]::IsNullOrWhiteSpace($alias)   -or
    [string]::IsNullOrWhiteSpace($storePass)) {
    throw "Company name, alias, and store password are required."
}
if ([string]::IsNullOrWhiteSpace($validity)) { $validity = "10000" }

$keystoreFile = "echoorchard-release.jks"
$dname = "CN=$company, OU=$orgUnit, O=$company, L=$city, ST=$state, C=$country"

if (Test-Path $keystoreFile) {
    throw "$keystoreFile already exists. Move or delete it first."
}

Write-Host ""
Write-Host "Generating $keystoreFile ..." -ForegroundColor Cyan

& keytool -genkeypair -v `
    -keystore $keystoreFile `
    -storetype JKS `
    -keyalg RSA -keysize 2048 `
    -validity $validity `
    -alias $alias `
    -storepass $storePass `
    -keypass $keyPass `
    -dname $dname

if ($LASTEXITCODE -ne 0) { throw "keytool failed (exit $LASTEXITCODE)." }

# --- Base64 for GitHub Secrets ---------------------------------------------
$base64File = "$keystoreFile.base64.txt"
[Convert]::ToBase64String([IO.File]::ReadAllBytes($keystoreFile)) |
    Out-File -FilePath $base64File -Encoding ascii -NoNewline

Write-Host ""
Write-Host "Done." -ForegroundColor Green
Write-Host "Keystore : $keystoreFile" -ForegroundColor Green
Write-Host "Base64   : $base64File" -ForegroundColor Green
Write-Host ""
Write-Host "Add these GitHub repository secrets" -ForegroundColor Yellow
Write-Host "  (Settings -> Secrets and variables -> Actions -> New repository secret):"
Write-Host "  EchoOrchardKeystoreBase64 = contents of $base64File"
Write-Host "  EchoOrchardStorePassword  = the store password you just entered"
Write-Host "  EchoOrchardKeyPassword    = the key password you just entered"
Write-Host "  EchoOrchardKeyAlias       = $alias"
Write-Host ""
Write-Host "Keep $keystoreFile somewhere safe and OFFLINE. It is git-ignored." -ForegroundColor Yellow
Write-Host "Losing it means you can never update the app on Play again." -ForegroundColor Yellow
