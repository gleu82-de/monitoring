#!/bin/bash
set -euo pipefail

GITHUB_USER="didiator"
GITHUB_REPO="monitoring"
GITHUB_TOKEN=$(grep 'token = ' ~/.gitconfig | awk '{print $3}')

if [ -z "$GITHUB_TOKEN" ]; then
    echo "❌ GITHUB_TOKEN not found in ~/.gitconfig!"
    exit 1
fi

CURRENT=$(cat VERSION 2>/dev/null || echo "0.0.0")
MAJOR=$(echo "$CURRENT" | cut -d. -f1)
MINOR=$(echo "$CURRENT" | cut -d. -f2)
PATCH=$(echo "$CURRENT" | cut -d. -f3)
NEXT_VERSION="$MAJOR.$MINOR.$((PATCH + 1))"

set +e
read -t 10 -p "Version [Enter=v$NEXT_VERSION]: " INPUT
set -e
INPUT="${INPUT:-}"

VERSION="${INPUT:-$NEXT_VERSION}"
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "❌ Invalid version: $VERSION"
    exit 1
fi

TAG="v$VERSION"
echo "$VERSION" > VERSION

echo ""
echo "=== Deployment: $TAG ==="
echo ""

if [ -n "$(git status --short)" ]; then
    CHANGED=$(git status --short | head -5 | awk '{print $2}' | tr '\n' ' ')
    DEFAULT_MSG="Update: $CHANGED"
    
    set +e
    read -t 60 -p "Comment [Enter=auto]: " COMMENT
    set -e
    COMMENT="${COMMENT:-}"
    
    if [ -n "$COMMENT" ]; then
        COMMIT_MSG="$DEFAULT_MSG - $COMMENT"
    else
        COMMIT_MSG="$DEFAULT_MSG"
    fi
    
    git add -A
    git commit -m "$COMMIT_MSG"
    echo "✅ Committed: $COMMIT_MSG"
else
    echo "✅ No changes"
fi

if git rev-parse "$TAG" >/dev/null 2>&1; then
    echo "❌ Tag $TAG exists!"
    exit 1
fi

git tag "$TAG"
echo "✅ Tagged: $TAG"

git push origin main
git push origin "$TAG"
echo "✅ Pushed"

# Release
TITLE="$TAG - Monitoring Updates"
BODY="Automated deployment $TAG"

echo ""
RESPONSE=$(curl -s -X POST \
  -H "Accept: application/vnd.github.v3+json" \
  -H "Authorization: token $GITHUB_TOKEN" \
  "https://api.github.com/repos/$GITHUB_USER/$GITHUB_REPO/releases" \
  -d "{\"tag_name\":\"$TAG\",\"name\":\"$TITLE\",\"body\":\"$BODY\",\"draft\":false,\"prerelease\":false}")

URL=$(echo "$RESPONSE" | grep -o '"html_url": *"[^"]*"' | head -1 | sed 's/"html_url": *"\(.*\)"/\1/')

if [ -n "$URL" ]; then
    echo "✅ Release: $URL"
else
    echo "❌ Release failed"
    echo "Response: $RESPONSE"
    exit 1
fi

echo ""
echo "⏳ Monitoring GitHub Actions (max 120s)..."
echo ""

set +e
for i in {1..24}; do
    sleep 5
    
    STATUS=$(curl -s \
      -H "Accept: application/vnd.github.v3+json" \
      -H "Authorization: token $GITHUB_TOKEN" \
      "https://api.github.com/repos/$GITHUB_USER/$GITHUB_REPO/actions/runs?per_page=1" \
      | grep -o '"status": *"[^"]*"' | head -1 | sed 's/"status": *"\(.*\)"/\1/')
    
    CONCLUSION=$(curl -s \
      -H "Accept: application/vnd.github.v3+json" \
      -H "Authorization: token $GITHUB_TOKEN" \
      "https://api.github.com/repos/$GITHUB_USER/$GITHUB_REPO/actions/runs?per_page=1" \
      | grep -o '"conclusion": *"[^"]*"' | head -1 | sed 's/"conclusion": *"\(.*\)"/\1/')
    
    if [ "$STATUS" = "completed" ]; then
        if [ "$CONCLUSION" = "success" ]; then
            echo ""
            echo "✅ GitHub Actions: Success ($((i*5))s)"
            break
        else
            echo ""
            echo "❌ GitHub Actions: $CONCLUSION"
            exit 1
        fi
    fi
done
set -e

echo ""
echo "⏳ Verifying PROD..."
sleep 5

PROD_VER=$(ssh dgl@PROD "cat ~/monitoring/VERSION 2>/dev/null" || echo "?")
if [ "$PROD_VER" = "$VERSION" ]; then
    echo "✅ PROD: v$PROD_VER"
else
    echo "⚠️  PROD: v$PROD_VER (expected v$VERSION)"
fi

echo ""
echo "========================================="
echo "✅ Deployment Complete: $TAG"
echo "========================================="
