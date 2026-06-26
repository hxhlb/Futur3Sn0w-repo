#!/usr/bin/env python3
"""
Reads the APT Packages file and generates a rich index.html for the repo.
Usage: python3 gen_index.py <worktree_path> <base_url>
"""

import sys, os, re

WORKTREE = sys.argv[1]
BASE_URL = sys.argv[2].rstrip('/')

def parse_packages(path):
    pkgs = []
    current = {}
    with open(path, 'r', encoding='utf-8', errors='replace') as f:
        for line in f:
            line = line.rstrip('\n')
            if line == '':
                if current.get('Package'):
                    pkgs.append(current)
                current = {}
            elif line.startswith(' ') or line.startswith('\t'):
                pass  # continuation
            else:
                m = re.match(r'^([^:]+):\s*(.*)', line)
                if m:
                    current[m.group(1)] = m.group(2)
    if current.get('Package'):
        pkgs.append(current)
    return pkgs

pkgs_path = os.path.join(WORKTREE, 'Packages')
raw = parse_packages(pkgs_path)
seen = {}
for p in raw:
    seen[p.get("Package", "")] = p
packages = list(seen.values())

# Sort by name
packages.sort(key=lambda p: p.get('Name', p.get('Package', '')).lower())

def pkg_card(p):
    bundle_id = p.get('Package', '')
    name      = p.get('Name', bundle_id)
    desc      = p.get('Description', '')
    version   = p.get('Version', '')
    icon_url  = p.get('Icon', f"{BASE_URL}/icons/{bundle_id}.png")
    dep_url   = p.get('SileoDepiction', '')
    return f'''
        <div class="pkg-card">
          <img class="pkg-icon" src="{icon_url}" alt="{name} icon" onerror="this.style.display='none'">
          <div class="pkg-info">
            <div class="pkg-name">{name}</div>
            <div class="pkg-desc">{desc}</div>
            <div class="pkg-version">v{version}</div>
          </div>
        </div>'''

cards_html = '\n'.join(pkg_card(p) for p in packages)
count = len(packages)

html = f'''<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="theme-color" content="#0d0d14">
  <title>MoarTweaks &middot; Futur3Sn0w</title>
  <style>
    *, *::before, *::after {{ box-sizing: border-box; margin: 0; padding: 0; }}

    :root {{
      --bg:        #0d0d14;
      --surface:   #16161f;
      --surface2:  #1e1e2a;
      --border:    rgba(255,255,255,.08);
      --text:      #f0f0f5;
      --muted:     #9898ac;
      --accent1:   #bf85ff;
      --accent2:   #5eb7ff;
      --accent3:   #ff7eb3;
      --radius:    18px;
    }}

    body {{
      background: var(--bg);
      color: var(--text);
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      min-height: 100vh;
      padding-bottom: 60px;
    }}

    /* ── Hero ─────────────────────────────────────── */
    .hero {{
      text-align: center;
      padding: 64px 24px 40px;
      position: relative;
      overflow: hidden;
    }}
    .hero::before {{
      content: '';
      position: absolute;
      inset: 0;
      background:
        radial-gradient(ellipse 60% 40% at 25% 0%, rgba(94,183,255,.18) 0%, transparent 70%),
        radial-gradient(ellipse 50% 35% at 75% 0%, rgba(255,126,179,.15) 0%, transparent 70%),
        radial-gradient(ellipse 40% 30% at 50% 80%, rgba(191,133,255,.12) 0%, transparent 70%);
      pointer-events: none;
    }}

    .hero-logo {{
      width: 96px;
      height: 96px;
      border-radius: 26px;
      box-shadow: 0 8px 40px rgba(191,133,255,.35), 0 2px 8px rgba(0,0,0,.6);
      margin-bottom: 20px;
    }}

    .hero h1 {{
      font-size: clamp(1.8rem, 5vw, 2.8rem);
      font-weight: 700;
      letter-spacing: -.02em;
      background: linear-gradient(135deg, var(--accent2) 0%, var(--accent1) 50%, var(--accent3) 100%);
      -webkit-background-clip: text;
      -webkit-text-fill-color: transparent;
      background-clip: text;
      margin-bottom: 8px;
    }}

    .hero p {{
      color: var(--muted);
      font-size: 1rem;
      margin-bottom: 32px;
    }}

    /* ── Add buttons ──────────────────────────────── */
    .add-buttons {{
      display: flex;
      flex-wrap: wrap;
      gap: 12px;
      justify-content: center;
      margin-bottom: 16px;
    }}

    .add-btn {{
      display: inline-flex;
      align-items: center;
      gap: 9px;
      padding: 12px 22px;
      border-radius: 50px;
      font-size: .95rem;
      font-weight: 600;
      text-decoration: none;
      transition: transform .15s, box-shadow .15s;
      border: 1px solid var(--border);
    }}
    .add-btn:hover {{ transform: translateY(-2px); }}

    .add-btn svg {{ flex-shrink: 0; }}

    .btn-sileo  {{ background: linear-gradient(135deg,#1a6fff,#6b2fff); box-shadow: 0 4px 20px rgba(107,47,255,.4); color:#fff; }}
    .btn-zebra  {{ background: linear-gradient(135deg,#ff8c00,#ffd000); box-shadow: 0 4px 20px rgba(255,160,0,.35); color:#1a1a00; }}
    .btn-cydia  {{ background: linear-gradient(135deg,#00b4d8,#0077b6); box-shadow: 0 4px 20px rgba(0,180,216,.35); color:#fff; }}

    .copy-url {{
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 10px;
      margin-top: 4px;
    }}
    .url-chip {{
      background: var(--surface2);
      border: 1px solid var(--border);
      border-radius: 8px;
      padding: 7px 14px;
      font-size: .85rem;
      font-family: "SF Mono", ui-monospace, monospace;
      color: var(--accent2);
      cursor: pointer;
      transition: background .15s;
    }}
    .url-chip:hover {{ background: var(--surface); }}
    .copy-hint {{
      font-size: .8rem;
      color: var(--muted);
    }}

    /* ── Divider ──────────────────────────────────── */
    .section-header {{
      max-width: 680px;
      margin: 40px auto 16px;
      padding: 0 20px;
      display: flex;
      align-items: baseline;
      gap: 10px;
    }}
    .section-header h2 {{
      font-size: 1.15rem;
      font-weight: 600;
      color: var(--text);
    }}
    .section-header .badge {{
      font-size: .75rem;
      font-weight: 600;
      padding: 2px 8px;
      background: var(--surface2);
      border: 1px solid var(--border);
      border-radius: 20px;
      color: var(--muted);
    }}

    /* ── Package cards ────────────────────────────── */
    .pkg-grid {{
      max-width: 680px;
      margin: 0 auto;
      padding: 0 16px;
      display: flex;
      flex-direction: column;
      gap: 8px;
    }}

    .pkg-card {{
      display: flex;
      align-items: center;
      gap: 16px;
      background: var(--surface);
      border: 1px solid var(--border);
      border-radius: var(--radius);
      padding: 14px 16px;
      transition: background .15s, border-color .15s;
    }}
    .pkg-card:hover {{
      background: var(--surface2);
      border-color: rgba(255,255,255,.14);
    }}

    .pkg-icon {{
      width: 54px;
      height: 54px;
      border-radius: 13px;
      flex-shrink: 0;
      background: var(--surface2);
    }}

    .pkg-info {{ flex: 1; min-width: 0; }}

    .pkg-name {{
      font-weight: 600;
      font-size: 1rem;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }}

    .pkg-desc {{
      color: var(--muted);
      font-size: .875rem;
      margin-top: 2px;
      line-height: 1.4;
    }}

    .pkg-version {{
      display: inline-block;
      margin-top: 5px;
      font-size: .75rem;
      color: var(--accent1);
      background: rgba(191,133,255,.12);
      border-radius: 4px;
      padding: 1px 7px;
    }}

    /* ── Footer ───────────────────────────────────── */
    footer {{
      text-align: center;
      margin-top: 56px;
      color: var(--muted);
      font-size: .8rem;
    }}
    footer a {{ color: var(--accent2); text-decoration: none; }}
  </style>
</head>
<body>

  <div class="hero">
    <img class="hero-logo" src="{BASE_URL}/CydiaIcon.png" alt="MoarTweaks">
    <h1>MoarTweaks</h1>
    <p>Jailbreak tweaks by Futur3Sn0w &nbsp;&middot;&nbsp; {count} package{"s" if count != 1 else ""}</p>

    <div class="add-buttons">
      <a class="add-btn btn-sileo" href="sileo://source/{BASE_URL}/">
        <!-- Sileo icon -->
        <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor"><circle cx="12" cy="12" r="10"/><path fill="#1a6fff" d="M8 10h8M8 14h5" stroke="white" stroke-width="2" stroke-linecap="round"/></svg>
        Add to Sileo
      </a>
      <a class="add-btn btn-zebra" href="zbra://sources/add/{BASE_URL}/">
        <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor"><rect x="3" y="3" width="18" height="18" rx="4"/><path fill="#ff8c00" d="M7 8h10M7 12h7M7 16h10" stroke="#1a1a00" stroke-width="2" stroke-linecap="round"/></svg>
        Add to Zebra
      </a>
      <a class="add-btn btn-cydia" href="cydia://url/https://cydia.saurik.com/api/share#?source={BASE_URL}/">
        <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor"><circle cx="12" cy="12" r="10"/><path fill="#00b4d8" d="M9 12l2 2 4-4" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>
        Add to Cydia
      </a>
    </div>

    <div class="copy-url">
      <span class="url-chip" onclick="navigator.clipboard.writeText('{BASE_URL}/').then(()=>{{this.textContent='Copied!';setTimeout(()=>this.textContent='{BASE_URL}/',1500)}})">{BASE_URL}/</span>
      <span class="copy-hint">tap to copy</span>
    </div>
  </div>

  <div class="section-header">
    <h2>Packages</h2>
    <span class="badge">{count}</span>
  </div>

  <div class="pkg-grid">
{cards_html}
  </div>

  <footer>
    <p>Made with ♥ by <a href="https://github.com/Futur3Sn0w">Futur3Sn0w</a></p>
  </footer>

  <script>
    // Auto-detect and highlight the right "Add" button based on user agent
    const ua = navigator.userAgent;
    if (/Sileo/.test(ua)) document.querySelector('.btn-sileo').style.outline = '2px solid white';
    else if (/Zebra/.test(ua)) document.querySelector('.btn-zebra').style.outline = '2px solid #1a1a00';
  </script>

</body>
</html>'''

out = os.path.join(WORKTREE, 'index.html')
with open(out, 'w', encoding='utf-8') as f:
    f.write(html)

print(f"index.html written ({len(packages)} packages)")
