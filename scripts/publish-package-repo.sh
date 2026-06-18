#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
BRANCH="${PAGES_BRANCH:-gh-pages}"
WORKTREE="${PAGES_WORKTREE:-$ROOT/.gh-pages-worktree}"

if ! command -v dpkg-scanpackages >/dev/null 2>&1; then
  echo "error: dpkg-scanpackages was not found on PATH." >&2
  echo "Install dpkg-dev, or run this from a shell where your jailbreak packaging tools are available." >&2
  exit 1
fi

if [ -e "$WORKTREE" ] && ! git -C "$WORKTREE" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "error: $WORKTREE exists but is not a git worktree." >&2
  exit 1
fi

if [ ! -e "$WORKTREE" ]; then
  if git show-ref --verify --quiet "refs/heads/$BRANCH"; then
    git worktree add "$WORKTREE" "$BRANCH"
  else
    git worktree add --detach "$WORKTREE" HEAD
    git -C "$WORKTREE" checkout --orphan "$BRANCH"
    git -C "$WORKTREE" rm -rf . >/dev/null 2>&1 || true
  fi
fi

mkdir -p "$WORKTREE/debs"
find "$WORKTREE/debs" -type f -name '*.deb' -delete

while IFS= read -r deb; do
  cp "$deb" "$WORKTREE/debs/"
done < <(find "$ROOT" \
  -path "$WORKTREE" -prune -o \
  -path '*/packages/*.deb' -type f -print)

cat > "$WORKTREE/index.html" <<'HTML'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Futur3Sn0w's Public Repo</title>
</head>
<body>
  <h1>Futur3Sn0w's Public Repo</h1>
  <p>Add this page's URL to your jailbreak package manager.</p>
  <code id="repo-url">https://futur3sn0w.github.io/repo/</code>
  <script>
    document.getElementById("repo-url").textContent = window.location.href;
  </script>
</body>
</html>
HTML

cat > "$WORKTREE/Release" <<'RELEASE'
Origin: Futur3Sn0w
Label: Futur3Sn0w's Public Repo
Suite: stable
Version: 1.0
Codename: ios
Architectures: iphoneos-arm
Components: main
Description: Futur3Sn0w jailbreak tweaks.
RELEASE

(
  cd "$WORKTREE"
  dpkg-scanpackages -m debs /dev/null > Packages
  gzip -cn9 Packages > Packages.gz
  git add .
  git commit -m "Update package repo" || true
)

if [ "${1:-}" = "--push" ]; then
  git -C "$WORKTREE" push origin "$BRANCH"
fi

echo "Package repo worktree ready at $WORKTREE"
