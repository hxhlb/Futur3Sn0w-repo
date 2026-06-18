#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
BRANCH="${PAGES_BRANCH:-gh-pages}"
WORKTREE="${PAGES_WORKTREE:-$ROOT/.gh-pages-worktree}"

file_size() {
  stat -f%z "$1" 2>/dev/null || stat -c%s "$1"
}

md5_file() {
  md5 -q "$1" 2>/dev/null || md5sum "$1" | awk '{print $1}'
}

sha1_file() {
  shasum -a 1 "$1" | awk '{print $1}'
}

sha256_file() {
  shasum -a 256 "$1" | awk '{print $1}'
}

control_member() {
  ar t "$1" | awk '/^control\.tar\./ { print; exit }'
}

control_tar_flags() {
  case "$1" in
    *.gz) echo "-xzO" ;;
    *.xz) echo "-xJO" ;;
    *.bz2) echo "-xjO" ;;
    *.lzma) echo "--lzma -xO" ;;
    *) echo "-xO" ;;
  esac
}

deb_control() {
  local deb="$1"
  local member
  member="$(control_member "$deb")"
  if [ -z "$member" ]; then
    echo "error: could not find control archive in $deb" >&2
    return 1
  fi

  # shellcheck disable=SC2046
  ar p "$deb" "$member" | tar $(control_tar_flags "$member") ./control 2>/dev/null ||
    ar p "$deb" "$member" | tar $(control_tar_flags "$member") control
}

generate_packages() {
  local packages_file="$1"
  shift

  : > "$packages_file"
  for deb in "$@"; do
    local copied_deb="debs/$(basename "$deb")"
    deb_control "$deb" >> "$packages_file"
    {
      echo "Filename: $copied_deb"
      echo "Size: $(file_size "$deb")"
      echo "MD5sum: $(md5_file "$deb")"
      echo "SHA1: $(sha1_file "$deb")"
      echo "SHA256: $(sha256_file "$deb")"
      echo
    } >> "$packages_file"
  done
}

append_release_checksums() {
  local release_file="$1"
  shift

  echo "MD5Sum:" >> "$release_file"
  for file in "$@"; do
    printf ' %s %16s %s\n' "$(md5_file "$file")" "$(file_size "$file")" "$(basename "$file")" >> "$release_file"
  done

  echo "SHA1:" >> "$release_file"
  for file in "$@"; do
    printf ' %s %16s %s\n' "$(sha1_file "$file")" "$(file_size "$file")" "$(basename "$file")" >> "$release_file"
  done

  echo "SHA256:" >> "$release_file"
  for file in "$@"; do
    printf ' %s %16s %s\n' "$(sha256_file "$file")" "$(file_size "$file")" "$(basename "$file")" >> "$release_file"
  done
}

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

deb_files=()
while IFS= read -r deb; do
  copied_deb="$WORKTREE/debs/$(basename "$deb")"
  cp "$deb" "$copied_deb"
  deb_files+=("$copied_deb")
done < <(find "$ROOT" \
  -path "$WORKTREE" -prune -o \
  -path '*/packages/*.deb' -type f -print)

if [ "${#deb_files[@]}" -eq 0 ]; then
  echo "warning: no .deb files found under tweak packages/ folders." >&2
fi

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
  generate_packages Packages "${deb_files[@]}"
  gzip -cn9 Packages > Packages.gz
  append_release_checksums Release Packages Packages.gz
  git add .
  git commit -m "Update package repo" || true
)

if [ "${1:-}" = "--push" ]; then
  git -C "$WORKTREE" push origin "$BRANCH"
fi

echo "Package repo worktree ready at $WORKTREE"
