# Automated Build & Push to GitHub
# This script builds the app and automatically releases it on GitHub
# The app will detect the update and show the dialog

# Usage: .\AUTO_BUILD.ps1
# Or with custom version: .\AUTO_BUILD.ps1 -version "1.32.0"

param(
    [string]$version = ""
)

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$desktopPath = "$env:USERPROFILE\Desktop"

# If no version provided, auto-increment from latest tag
if ([string]::IsNullOrEmpty($version)) {
    $latestTag = git describe --tags --abbrev=0 2>$null
    if ($latestTag) {
        # Parse version like v1.31.0
        $latestVersion = $latestTag -replace '^v', ''
        $parts = $latestVersion.Split('.')
        if ($parts.Count -eq 3) {
            $parts[2] = [int]$parts[2] + 1
            $version = $parts -join '.'
        }
    } else {
        $version = "1.31.1"
    }
}

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║          🚀 AUTOMATED BUILD & PUSH v$version" -ForegroundColor Cyan
Write-Host "║   Building → Tagging → Releasing → App Detects Update" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Step 1: Update pubspec.yaml
Write-Host "📝 Step 1: Updating version to $version..." -ForegroundColor Yellow

$pubspecPath = "$projectRoot\pubspec.yaml"
$buildNumber = (Get-Random -Minimum 30 -Maximum 99)
$pubspecContent = Get-Content $pubspecPath -Raw
$newVersion = "version: $version+$buildNumber"
$pubspecContent = $pubspecContent -replace 'version: [\d.+]+', $newVersion
Set-Content -Path $pubspecPath -Value $pubspecContent
Write-Host "   ✓ Updated to $version+$buildNumber" -ForegroundColor Green

# Step 2: Build
Write-Host ""
Write-Host "🔨 Step 2: Building release APK..." -ForegroundColor Yellow
Set-Location $projectRoot

# Clean old builds
flutter clean *>$null

# Build APK
$buildOutput = flutter build apk --release 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "   ✗ Build failed!" -ForegroundColor Red
    Write-Host ""
    Write-Host $buildOutput | Select-Object -Last 30
    exit 1
}
Write-Host "   ✓ APK built successfully" -ForegroundColor Green

# Step 3: Copy APK
Write-Host ""
Write-Host "📱 Step 3: Copying APK to Desktop..." -ForegroundColor Yellow

$apkSource = "$projectRoot\build\app\outputs\flutter-apk\app-release.apk"
$apkDest = "$desktopPath\location_sharing_v$version.apk"

if (Test-Path $apkSource) {
    Copy-Item $apkSource $apkDest -Force
    $sizeMB = [Math]::Round((Get-Item $apkDest).Length / 1MB, 2)
    Write-Host "   ✓ Copied to Desktop ($sizeMB MB)" -ForegroundColor Green
} else {
    Write-Host "   ✗ APK not found!" -ForegroundColor Red
    exit 1
}

# Step 4: Git commit
Write-Host ""
Write-Host "📦 Step 4: Committing to Git..." -ForegroundColor Yellow

git add pubspec.yaml
git commit -m "Build v$version" >$null 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "   ✓ Changes committed" -ForegroundColor Green
} else {
    Write-Host "   ⚠ Nothing to commit (no changes)" -ForegroundColor Yellow
}

# Step 5: Create tag
Write-Host ""
Write-Host "🏷️  Step 5: Creating Git tag v$version..." -ForegroundColor Yellow

# Check if tag already exists
$existingTag = git tag -l "v$version" 2>$null
if ($existingTag) {
    Write-Host "   ⚠ Tag already exists, deleting..." -ForegroundColor Yellow
    git tag -d "v$version" >$null 2>&1
    git push origin --delete "v$version" >$null 2>&1
}

git tag "v$version"
git push origin "v$version" >$null 2>&1
Write-Host "   ✓ Tag created and pushed" -ForegroundColor Green

# Step 6: Create GitHub Release
Write-Host ""
Write-Host "🔗 Step 6: Creating GitHub Release..." -ForegroundColor Yellow

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$releaseNotes = @"
## Version $version

**Built**: $timestamp
**Size**: $sizeMB MB
**Package**: location_sharing_v$version.apk

### Installation
1. Download the APK from this release
2. Install on phone: \`adb install location_sharing_v$version.apk\`
3. Open the app and it will automatically detect this update!

### Update Detection
- App checks for new versions automatically on startup
- Update dialog appears if new version is available
- Download & install directly from the app
"@

# Check if release exists
$existingRelease = gh release view "v$version" 2>$null
if ($existingRelease) {
    Write-Host "   ⚠ Release already exists, updating..." -ForegroundColor Yellow
    gh release delete "v$version" --yes >$null 2>&1
}

gh release create "v$version" --title "Version $version" --notes $releaseNotes --latest >$null 2>&1
Write-Host "   ✓ GitHub Release created" -ForegroundColor Green

# Step 7: Upload APK
Write-Host ""
Write-Host "📤 Step 7: Uploading APK to release..." -ForegroundColor Yellow

gh release upload "v$version" "$apkDest" --clobber >$null 2>&1
Write-Host "   ✓ APK uploaded to release" -ForegroundColor Green

# Success!
Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║                    ✅ BUILD COMPLETE!" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""

Write-Host "📊 Summary:" -ForegroundColor Cyan
Write-Host "   Version: v$version" -ForegroundColor White
Write-Host "   APK Size: $sizeMB MB" -ForegroundColor White
Write-Host "   Location: $apkDest" -ForegroundColor White
Write-Host ""

Write-Host "🎯 Next Steps:" -ForegroundColor Yellow
Write-Host ""
Write-Host "   1️⃣  Install on your phone:" -ForegroundColor White
Write-Host "       adb install `"$apkDest`"" -ForegroundColor Magenta
Write-Host ""
Write-Host "   2️⃣  Open the app" -ForegroundColor White
Write-Host "       → App checks GitHub for latest release" -ForegroundColor Gray
Write-Host "       → Finds v$version" -ForegroundColor Gray
Write-Host "       → Update dialog appears! ✨" -ForegroundColor Gray
Write-Host ""
Write-Host "   3️⃣  Click 'Download & Install'" -ForegroundColor White
Write-Host "       → APK downloads from GitHub" -ForegroundColor Gray
Write-Host "       → System installer opens" -ForegroundColor Gray
Write-Host "       → App updates automatically" -ForegroundColor Gray
Write-Host ""

Write-Host "🔗 GitHub Release:" -ForegroundColor Cyan
Write-Host "   https://github.com/Vasudev9999/location_sharing/releases/tag/v$version" -ForegroundColor Blue
Write-Host ""

Write-Host "⏱️  Total time: ~2-3 minutes" -ForegroundColor Yellow
Write-Host ""
Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
