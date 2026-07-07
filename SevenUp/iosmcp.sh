#!/bin/bash
# Usage: iosmcp.sh <tool_name> ['{"json":"args"}']
# Calls an ios-mcp tool on the device. If the result contains an image,
# saves it to ~/Documents/MoarTweaks/SevenUp/mcp-shot.jpg and prints the path.
TOOL="$1"
if [ -z "$2" ]; then ARGS='{}'; else ARGS="$2"; fi
PAYLOAD=$(python3 - "$TOOL" "$ARGS" <<'PY'
import json, sys
print(json.dumps({
    "jsonrpc": "2.0", "id": 1, "method": "tools/call",
    "params": {"name": sys.argv[1], "arguments": json.loads(sys.argv[2])}
}))
PY
)
TMPF=$(mktemp /tmp/iosmcp.XXXXXX)
curl -s -m 30 -X POST http://192.168.0.190:8090/mcp \
  -H 'Content-Type: application/json' \
  -H 'Accept: application/json, text/event-stream' \
  -H 'MCP-Protocol-Version: 2025-06-18' \
  -d "$PAYLOAD" -o "$TMPF"
python3 - "$TMPF" <<'PY'
import json, sys, base64, re
raw = open(sys.argv[1]).read()
m = re.search(r'data: (\{.*\})', raw)
if m: raw = m.group(1)
try:
    resp = json.loads(raw)
except Exception:
    print(raw[:2000]); sys.exit(0)
result = resp.get("result", resp.get("error", {}))
content = result.get("content", []) if isinstance(result, dict) else []
for item in content:
    if item.get("type") == "image":
        path = "/Users/futur3sn0w/Documents/MoarTweaks/SevenUp/mcp-shot.jpg"
        with open(path, "wb") as f:
            f.write(base64.b64decode(item["data"]))
        print("IMAGE:", path)
    elif item.get("type") == "text":
        print(item.get("text", "")[:3000])
if not content:
    print(json.dumps(result)[:3000])
PY
rm -f "$TMPF"
