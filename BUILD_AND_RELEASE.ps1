# Build and Release Helper Script for Location Sharing App
# Usage: .\BUILD_AND_RELEASE.ps1 -version "1.31.1"

param(
    [Parameter(Mandatory=$true)]
    [string]$version
)

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$desktopPath = "$env:USERPROFILE\Desktop"

Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  📦 Building Location Sharing App v$version" -ForegroundColor Cyan
Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Step 1: Update version in pubspec.yaml
Write-Host "Step 1️⃣  Updating version to $version..." -ForegroundColor Yellow

$buildNumber = [int](Get-Date -Format "HHmmss").Substring(0, 2)
$pubspecPath = "$projectRoot\pubspec.yaml"
$pubspecContent = Get-Content $pubspecPath -Raw
$newVersion = "version: $version+$buildNumber"
$pubspecContent = $pubspecContent -replace 'version: [\d.+]+', $newVersion
Set-Content -Path $pubspecPath -Value $pubspecContent

Write-Host "✅ Version updated to $version+$buildNumber" -ForegroundColor Green
Write-Host ""

# Step 2: Clean build
Write-Host "Step 2️⃣  Cleaning previous builds..." -ForegroundColor Yellow
Set-Location $projectRoot
flutter clean | Out-Null
Write-Host "✅ Build cache cleared" -ForegroundColor Green
Write-Host ""

# Step 3: Build APK
Write-Host "Step 3️⃣  Building release APK..." -ForegroundColor Yellow
$buildOutput = flutter build apk --release 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ APK built successfully" -ForegroundColor Green
} else {
    Write-Host "❌ Build failed! Check output above." -ForegroundColor Red
    Write-Host $buildOutput | Select-Object -Last 20
    exit 1
}
Write-Host ""

# Step 4: Copy to Desktop
Write-Host "Step 4️⃣  Copying APK to Desktop..." -ForegroundColor Yellow
$apkSource = "$projectRoot\build\app\outputs\flutter-apk\app-release.apk"
$apkDest = "$desktopPath\location_sharing_v$version.apk"

if (Test-Path $apkSource) {
    Copy-Item $apkSource $apkDest -Force
    $fileSize = (Get-Item $apkDest).Length / 1MB
    Write-Host "✅ APK copied to Desktop ($([Math]::Round($fileSize, 2)) MB)" -ForegroundColor Green
} else {
    Write-Host "❌ APK not found at $apkSource" -ForegroundColor Red
    exit 1
}
Write-Host ""

# Step 5: Commit changes
Write-Host "Step 5️⃣  Committing to Git..." -ForegroundColor Yellow
git add -A
git commit -m "v$version: Release build" | Out-Null
Write-Host "✅ Changes committed" -ForegroundColor Green
Write-Host ""

# Step 6: Create Git tag
Write-Host "Step 6️⃣  Creating Git tag v$version..." -ForegroundColor Yellow
git tag "v$version"
git push origin "v$version"
Write-Host "✅ Tag created and pushed" -ForegroundColor Green
Write-Host ""

# Step 7: Create GitHub release
Write-Host "Step 7️⃣  Creating GitHub Release..." -ForegroundColor Yellow
$releaseNotes = "Release v$version`n`nBuilt: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`nFile: location_sharing_v$version.apk"
gh release create "v$version" --title "Version $version" --notes $releaseNotes --latest
Write-Host "✅ GitHub release created" -ForegroundColor Green
Write-Host ""

# Step 8: Upload APK to release
Write-Host "Step 8️⃣  Uploading APK to GitHub Release..." -ForegroundColor Yellow
gh release upload "v$version" $apkDest --clobber
Write-Host "✅ APK uploaded" -ForegroundColor Green
Write-Host ""

# Summary
Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "                   ✅ BUILD COMPLETE!" -ForegroundColor Green
Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host ""
Write-Host "📦 APK Details:" -ForegroundColor Cyan
Write-Host "   Location: $apkDest" -ForegroundColor White
Write-Host "   Size: $([Math]::Round((Get-Item $apkDest).Length / 1MB, 2)) MB" -ForegroundColor White
Write-Host ""
Write-Host "🔗 GitHub Release:" -ForegroundColor Cyan
Write-Host "   https://github.com/Vasudev9999/location_sharing/releases/tag/v$version" -ForegroundColor Blue
Write-Host ""
Write-Host "📱 To install on phone:" -ForegroundColor Cyan
Write-Host "   adb install `"$apkDest`"" -ForegroundColor White
Write-Host ""
Write-Host "🎯 Next Steps:" -ForegroundColor Yellow
Write-Host "   1. Install APK on your phone via USB" -ForegroundColor White
Write-Host "   2. Open the app and it will check for updates" -ForegroundColor White
Write-Host "   3. An update notification will appear if new version exists" -ForegroundColor White
Write-Host ""
Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Green
