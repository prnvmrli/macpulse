#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PBXPROJ="$ROOT/MacPulse.xcodeproj/project.pbxproj"
CITATION="$ROOT/CITATION.cff"
CHANGELOG="$ROOT/CHANGELOG.md"

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <version> [build_number]"
  echo "Example: $0 2.2.0"
  echo "Example: $0 2.2.0 220"
  exit 1
fi

NEW_VERSION="${1#v}" # Strip leading 'v' if present
if ! [[ "$NEW_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+.*$ ]]; then
  echo "Error: Version must follow Semantic Versioning (e.g. 2.2.0, 2.2.0-beta.1)" >&2
  exit 1
fi

if [[ $# -ge 2 ]]; then
  NEW_BUILD="$2"
else
  # Derive build number from version: 2.2.0 -> 220
  MAJOR=$(echo "$NEW_VERSION" | cut -d. -f1)
  MINOR=$(echo "$NEW_VERSION" | cut -d. -f2)
  PATCH=$(echo "$NEW_VERSION" | cut -d. -f3 | sed 's/[^0-9].*//')
  NEW_BUILD="${MAJOR}${MINOR}${PATCH}"
fi

TODAY="$(date +%Y-%m-%d)"

echo "==> Bumping version to $NEW_VERSION (build $NEW_BUILD)..."

# 1. Update project.pbxproj
if [[ -f "$PBXPROJ" ]]; then
  perl -i -pe "s/MARKETING_VERSION = [^;]+;/MARKETING_VERSION = $NEW_VERSION;/g" "$PBXPROJ"
  perl -i -pe "s/CURRENT_PROJECT_VERSION = [^;]+;/CURRENT_PROJECT_VERSION = $NEW_BUILD;/g" "$PBXPROJ"
  echo "Updated $PBXPROJ"
fi

# 2. Update CITATION.cff
if [[ -f "$CITATION" ]]; then
  perl -i -pe "s/^version: .*/version: $NEW_VERSION/g" "$CITATION"
  perl -i -pe "s/^date-released: .*/date-released: $TODAY/g" "$CITATION"
  echo "Updated $CITATION"
fi

# 3. Check and update CHANGELOG.md
if [[ -f "$CHANGELOG" ]]; then
  if ! grep -Fq "## $NEW_VERSION" "$CHANGELOG"; then
    perl -i -pe "s/^# Changelog/# Changelog\n\n## $NEW_VERSION\n\n- Release $NEW_VERSION/g" "$CHANGELOG"
    echo "Added section '## $NEW_VERSION' to $CHANGELOG"
  else
    echo "Section '## $NEW_VERSION' already present in $CHANGELOG"
  fi
fi

echo ""
echo "Version bump complete!"
echo "Review changes with: git diff"
echo "To commit and tag:"
echo "  git commit -am 'chore(release): bump version to $NEW_VERSION'"
echo "  git tag v$NEW_VERSION"
echo "  git push origin main --tags"
