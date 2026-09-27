# Versioning and Release Guide

MacPulse adheres to [Semantic Versioning 2.0.0](https://semver.org/) (`MAJOR.MINOR.PATCH`) alongside an internal monotonic or version-derived integer build number (`CURRENT_PROJECT_VERSION`).

---

## 1. Versioning Policy

| Component | Format | When to Increment | Example |
| :--- | :--- | :--- | :--- |
| **MAJOR** | `X.0.0` | Breaking architectural changes, incompatible system rewrites, or discontinued macOS platform support. | `2.1.2` → `3.0.0` |
| **MINOR** | `x.Y.0` | Significant new user-facing features, major UI/UX redesigns, or non-breaking performance overhauls. | `2.1.2` → **`2.2.0`** *(Recommended for recent work)* |
| **PATCH** | `x.y.Z` | Bug fixes, maintenance, small styling adjustments, or documentation updates. | `2.1.2` → `2.1.3` |

---

## 2. Where Version Numbers Live

When cutting a new release, the version number must be updated across all of the following locations:

### 2.1 Xcode Project (`MacPulse.xcodeproj/project.pbxproj`)
Every target build configuration (Debug and Release for `MacPulse`, `MacPulseWidget`, and tests) contains:
- `MARKETING_VERSION = X.Y.Z;` (The user-facing bundle version, e.g. `2.2.0`)
- `CURRENT_PROJECT_VERSION = XYZ;` (The internal build integer, e.g. `220` or a monotonically incrementing counter)

These populate `CFBundleShortVersionString` and `CFBundleVersion` in `MacPulse/Info.plist` and `MacPulseWidget/Info.plist`.

### 2.2 Changelog (`CHANGELOG.md`)
Add a new release heading directly below `# Changelog`:
```markdown
## X.Y.Z

- Summary of changes, features, and fixes...
```

### 2.3 Citation Metadata (`CITATION.cff`)
Update the citation file used by researchers and open-source references:
```yaml
version: X.Y.Z
date-released: YYYY-MM-DD
```

### 2.4 Git Tag (`vX.Y.Z`)
Releases in Git and GitHub Actions are pinned to tags prefixed with `v`:
```bash
git tag vX.Y.Z
```

---

## 3. Step-by-Step Release Procedure

### Step 1: Pre-flight Checks
Ensure local tests, source syntax validation, and code signatures pass:
```bash
./scripts/validate-source.sh
swift test
./scripts/release-preflight.sh
```

### Step 2: Bump Version Files
You can use the helper script:
```bash
./scripts/bump-version.sh 2.2.0
```
Or update the files manually:
1. Replace `MARKETING_VERSION = <old>` and `CURRENT_PROJECT_VERSION = <old>` in `MacPulse.xcodeproj/project.pbxproj`.
2. Add a `## 2.2.0` entry to `CHANGELOG.md`.
3. Update `version` and `date-released` in `CITATION.cff`.

### Step 3: Commit and Push Changes
Commit the updated project files to `main`:
```bash
git add MacPulse.xcodeproj/project.pbxproj CHANGELOG.md CITATION.cff
git commit -m "chore(release): bump version to 2.2.0"
git push origin main
```

### Step 4: Tag the Release
Create an annotated tag and push it to trigger the automated build:
```bash
git tag v2.2.0
git push origin v2.2.0
```

---

## 4. GitHub Actions Release Automation

Once tag `v*` is pushed to GitHub, [`.github/workflows/release.yml`](../.github/workflows/release.yml) automatically runs on a macOS runner:

1. **Portable Test & Source Validation**: Executes `swift test` and `./scripts/validate-source.sh`.
2. **Universal Build**: Compiles both `arm64` (Apple Silicon) and `x86_64` (Intel) slices via `./scripts/build-local.sh`.
3. **Entitlement & Signature Verification**: Assesses ad-hoc code signature and sandbox entitlements with `./scripts/verify-release.sh`.
4. **DMG Generation**: Creates a drag-to-install disk image (`dist/MacPulse-<version>.dmg`) with SHA-256 checksums.
5. **Publishing**: Generates release notes and publishes a new release on GitHub with all binaries attached.

### Manual Workflow Dispatch
You can also trigger a release manually without immediately pushing a Git tag:
1. Go to the repository on GitHub.
2. Navigate to **Actions** → **Release**.
3. Click **Run workflow**, optionally specifying:
   - Target version tag (e.g. `v2.2.0`)
   - Draft flag
   - Pre-release flag
