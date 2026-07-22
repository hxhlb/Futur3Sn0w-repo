#!/usr/bin/env python3
"""
Inject Icon: and SileoDepiction: fields from source control files into
the generated APT Packages index. Run from inside the gh-pages worktree.

Usage: python3 inject-fields.py <repo_root> <packages_file>
"""

import sys, os

ROOT         = sys.argv[1]
PACKAGES     = sys.argv[2] if len(sys.argv) > 2 else "Packages"

PACKAGE_SOURCES = os.environ.get(
    "MOARTWEAKS_PACKAGE_SOURCES",
    os.path.join(ROOT, "repo", "package-sources.tsv"),
)

# ── Build map: bundle_id → {Icon, SileoDepiction} from the package manifest ──
extras = {}

if os.path.exists(PACKAGE_SOURCES):
    with open(PACKAGE_SOURCES, errors="replace") as f:
        header = f.readline().rstrip("\n").split("\t")
        columns = {name: idx for idx, name in enumerate(header)}
        for line in f:
            if not line.strip() or line.startswith("#"):
                continue
            row = line.rstrip("\n").split("\t")
            pkg_id = row[columns["Package"]].strip() if "Package" in columns and len(row) > columns["Package"] else None
            icon = row[columns["Icon"]].strip() if "Icon" in columns and len(row) > columns["Icon"] else None
            depiction = row[columns["SileoDepiction"]].strip() if "SileoDepiction" in columns and len(row) > columns["SileoDepiction"] else None
            if pkg_id and (icon or depiction):
                extras[pkg_id] = {}
                if icon:      extras[pkg_id]["Icon"]           = f"Icon: {icon}"
                if depiction: extras[pkg_id]["SileoDepiction"] = f"SileoDepiction: {depiction}"
else:
    # Fallback for old monorepo checkouts.
    for dirpath, dirs, files in os.walk(ROOT):
        # Skip worktrees, .git, .theos, packages dirs
        dirs[:] = [d for d in dirs if d not in {'.git', '.theos', 'packages'}
                   and not d.endswith('-worktree') and '.gh-pages' not in d]
        if 'control' not in files:
            continue
        ctrl = os.path.join(dirpath, 'control')
        pkg_id = icon = depiction = None
        with open(ctrl, errors='replace') as f:
            for line in f:
                line = line.rstrip()
                if line.startswith('Package:'):
                    pkg_id = line.split(':', 1)[1].strip()
                elif line.startswith('Icon:'):
                    icon = line
                elif line.startswith('SileoDepiction:'):
                    depiction = line
        if pkg_id and (icon or depiction):
            extras[pkg_id] = {}
            if icon:       extras[pkg_id]['Icon']            = icon
            if depiction:  extras[pkg_id]['SileoDepiction']  = depiction

print(f"Found extra fields for {len(extras)} packages", file=sys.stderr)

# ── Read Packages, patch each stanza ─────────────────────────────────────────
with open(PACKAGES, 'r', errors='replace') as f:
    content = f.read()

def patch_stanza(stanza):
    pkg_id = None
    for line in stanza.splitlines():
        if line.startswith('Package:'):
            pkg_id = line.split(':', 1)[1].strip()
            break
    if not pkg_id or pkg_id not in extras:
        return stanza

    fields = extras[pkg_id]
    new_lines = []
    for line in stanza.splitlines():
        # Drop any stale Icon/SileoDepiction already in the deb control
        if line.startswith('Icon:') or line.startswith('SileoDepiction:'):
            continue
        new_lines.append(line)
        if line.startswith('Package:'):
            if 'Icon' in fields:
                new_lines.append(fields['Icon'])
            if 'SileoDepiction' in fields:
                new_lines.append(fields['SileoDepiction'])
    return '\n'.join(new_lines)

stanzas = content.split('\n\n')
patched = '\n\n'.join(patch_stanza(s) for s in stanzas)

with open(PACKAGES, 'w') as f:
    f.write(patched)

print(f"Packages patched → {PACKAGES}", file=sys.stderr)
