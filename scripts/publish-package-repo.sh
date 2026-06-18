#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
BRANCH="${PAGES_BRANCH:-gh-pages}"
WORKTREE="${PAGES_WORKTREE:-$ROOT/.gh-pages-worktree}"
ARCHITECTURES=(iphoneos-arm iphoneos-arm64 iphoneos-arm64e)

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

file_mtime() {
  stat -f%m "$1" 2>/dev/null || stat -c%Y "$1"
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

control_field() {
  local control="$1"
  local field="$2"
  printf '%s\n' "$control" | awk -F': ' -v field="$field" '$1 == field { print; exit }'
}

control_rest() {
  local control="$1"
  printf '%s\n' "$control" | awk -F': ' '
    $1 != "Package" &&
    $1 != "Name" &&
    $1 != "Version" &&
    $1 != "Architecture" &&
    $1 != "Description" &&
    $1 != "Maintainer" &&
    $1 != "Author" &&
    $1 != "Depends" &&
    $1 != "Section" &&
    $1 != "Installed-Size" &&
    $1 != "Filename" &&
    $1 != "Size" &&
    $1 != "MD5sum" &&
    $1 != "SHA1" &&
    $1 != "SHA256" {
      print
    }
  '
}

write_canonical_control() {
  local control="$1"
  local field
  for field in Package Name Version Architecture Description Maintainer Author Depends Section Installed-Size; do
    control_field "$control" "$field"
  done
  control_rest "$control"
}

generate_packages() {
  local packages_file="$1"
  shift

  : > "$packages_file"
  for deb in "$@"; do
    local copied_deb="debs/$(basename "$deb")"
    local control
    control="$(deb_control "$deb")"
    write_canonical_control "$control" >> "$packages_file"
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
    printf ' %s %16s %s\n' "$(md5_file "$file")" "$(file_size "$file")" "$file" >> "$release_file"
  done

  echo "SHA1:" >> "$release_file"
  for file in "$@"; do
    printf ' %s %16s %s\n' "$(sha1_file "$file")" "$(file_size "$file")" "$file" >> "$release_file"
  done

  echo "SHA256:" >> "$release_file"
  for file in "$@"; do
    printf ' %s %16s %s\n' "$(sha256_file "$file")" "$(file_size "$file")" "$file" >> "$release_file"
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

current_packages_file="$(mktemp "${TMPDIR:-/tmp}/moartweaks-current-packages.XXXXXX")"
candidate_debs_file="$(mktemp "${TMPDIR:-/tmp}/moartweaks-candidate-debs.XXXXXX")"
selected_debs_file="$(mktemp "${TMPDIR:-/tmp}/moartweaks-selected-debs.XXXXXX")"
trap 'rm -f "$current_packages_file" "$candidate_debs_file" "$selected_debs_file"' EXIT

while IFS= read -r control_file; do
  awk -F': ' '$1 == "Package" { print $2; exit }' "$control_file"
done < <(find "$ROOT" \
  -path "$WORKTREE" -prune -o \
  -name control -type f -print) | sort -u > "$current_packages_file"

if [ ! -s "$current_packages_file" ]; then
  echo "error: no source control files found." >&2
  exit 1
fi

: > "$candidate_debs_file"
while IFS= read -r deb; do
  control="$(deb_control "$deb")"
  package="$(control_field "$control" Package)"
  architecture="$(control_field "$control" Architecture)"
  package="${package#Package: }"
  architecture="${architecture#Architecture: }"

  if grep -Fxq "$package" "$current_packages_file"; then
    printf '%s\t%s\t%s\t%s\n' "$(file_mtime "$deb")" "$package" "$architecture" "$deb" >> "$candidate_debs_file"
  fi
done < <(find "$ROOT" \
  -path "$WORKTREE" -prune -o \
  -path '*/packages/*.deb' -type f -print)

if [ ! -s "$candidate_debs_file" ]; then
  echo "error: no .deb files found under tweak packages/ folders." >&2
  echo "Build packages first, for example: (cd Solert && make package)." >&2
  exit 1
fi

sort -t $'\t' -k2,2 -k3,3 -k1,1n "$candidate_debs_file" |
  awk -F '\t' '{ key = $2 FS $3; line[key] = $0 } END { for (key in line) print line[key] }' |
  sort -t $'\t' -k2,2 -k3,3 |
  cut -f4- > "$selected_debs_file"

source_debs=()
while IFS= read -r deb; do
  source_debs+=("$deb")
done < "$selected_debs_file"

mkdir -p "$WORKTREE/debs"
find "$WORKTREE/debs" -type f -name '*.deb' -delete
rm -rf "$WORKTREE/dists"

deb_files=()
for deb in "${source_debs[@]}"; do
  copied_deb="$WORKTREE/debs/$(basename "$deb")"
  cp "$deb" "$copied_deb"
  deb_files+=("$copied_deb")
done

cat > "$WORKTREE/.gitignore" <<'GITIGNORE'
.DS_Store
AppSwitcherController/
*/.theos/
*/packages/
GITIGNORE

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
Components: main
Description: Futur3Sn0w jailbreak tweaks.
RELEASE
printf 'Architectures: %s\n' "${ARCHITECTURES[*]}" >> "$WORKTREE/Release"

(
  cd "$WORKTREE"
  generate_packages Packages "${deb_files[@]}"
  gzip -cn9 Packages > Packages.gz
  append_release_checksums Release Packages Packages.gz

  for dist in stable ios; do
    release_files=()
    for arch in "${ARCHITECTURES[@]}"; do
      mkdir -p "dists/$dist/main/binary-$arch"
      cp Packages "dists/$dist/main/binary-$arch/Packages"
      gzip -cn9 "dists/$dist/main/binary-$arch/Packages" > "dists/$dist/main/binary-$arch/Packages.gz"
      release_files+=("main/binary-$arch/Packages" "main/binary-$arch/Packages.gz")
    done
    cat > "dists/$dist/Release" <<RELEASE
Origin: Futur3Sn0w
Label: Futur3Sn0w's Public Repo
Suite: stable
Version: 1.0
Codename: $dist
Components: main
Description: Futur3Sn0w jailbreak tweaks.
RELEASE
    printf 'Architectures: %s\n' "${ARCHITECTURES[*]}" >> "dists/$dist/Release"
    (
      cd "dists/$dist"
      append_release_checksums Release "${release_files[@]}"
    )
  done

  git add .
  git commit -m "Update package repo" || true
)

if [ "${1:-}" = "--push" ]; then
  git -C "$WORKTREE" push origin "$BRANCH"
fi

echo "Package repo worktree ready at $WORKTREE"
