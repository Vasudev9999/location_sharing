# Release process (CI + GitHub Releases)

This project supports automated release builds via GitHub Actions. Use the flow below to create a signed APK and publish it as a GitHub Release. The CI workflow will build a signed release APK, compute its SHA256, and attach both the APK and a `latest.json` metadata file to the Release.

## One-time setup (developer)

1. Create a release keystore (you already did):

```powershell
keytool -genkeypair -v -keystore "C:\path\to\release-keystore.jks" -alias myreleasekey -keyalg RSA -keysize 2048 -validity 9125
```

2. Add the following GitHub repository Secrets (Repository -> Settings -> Secrets):
- `KEYSTORE_BASE64` - base64-encoded contents of `release-keystore.jks`.
- `KEYSTORE_PASSWORD` - keystore password.
- `KEY_ALIAS` - alias used when creating the keystore.
- `KEY_PASSWORD` - key password (often same as keystore password).

To create `KEYSTORE_BASE64` locally (PowerShell):

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes('D:\Kinship\release-keystore.jks')) | Out-File -Encoding ascii keystore.b64.txt
# open keystore.b64.txt and copy its contents into the KEYSTORE_BASE64 secret
```

3. Ensure `android/key.properties` and `android/keystore.jks` are ignored by Git (they're in `.gitignore`).

## Release steps (per release)

1. Update `pubspec.yaml` version to the release:

```yaml
version: 1.2.0+102
```

2. Commit the change and tag the release:

```powershell
git add pubspec.yaml
git commit -m "Bump version to 1.2.0+102"
git tag -a v1.2.0 -m "Release v1.2.0"
git push origin main --tags
```

3. Create or publish the Release on GitHub (if you pushed a tag and configured CI on release.published, you can create the Release via GitHub UI or `gh release create`).

4. Wait for the GitHub Actions workflow to finish. When complete, the Release will include two assets:
   - `app-release.apk` (signed)
   - `latest.json` (metadata with versionName, versionCode, apk_sha256)

5. The app updater fetches `latest.json`, compares versionCode and downloads the APK if newer.

## Notes
- Keep the keystore secure. If you lose it, you cannot update existing installs (users would need to uninstall and reinstall).
- CI uses the tag name (without leading `v`) for `build-name` and the GitHub run number for `versionCode`. You can change this behaviour in `.github/workflows/release.yml`.
