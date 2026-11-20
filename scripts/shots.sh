#!/usr/bin/env bash
# 用无头 Chrome 重出网页版截图。只影响截图，不改源码。
set -euo pipefail
cd "$(dirname "$0")/.."

CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
[ -x "$CHROME" ] || { echo "没找到 Chrome，跳过截图"; exit 0; }

TMP=$(mktemp -d)

# 1) 引导层首屏：直接截原文件
"$CHROME" --headless --disable-gpu --hide-scrollbars --virtual-time-budget=8000 \
  --window-size=1200,860 --screenshot=docs/web-gate.png "file://$PWD/docs/index.html" 2>/dev/null

# 2) 示例数据页：注入「关掉动画、直接点示例」的补丁副本
python3 - "$TMP" <<'PY'
import sys, pathlib
tmp = sys.argv[1]
h = pathlib.Path('docs/index.html').read_text()
inject = """
<style>*{animation-duration:.01s!important;animation-delay:0s!important;transition:none!important}.reveal{opacity:1!important;transform:none!important}</style>
<script>document.getElementById('demo').click();</script>
</body>"""
pathlib.Path(tmp, 'demo.html').write_text(h.replace('</body>', inject, 1))
PY
"$CHROME" --headless --disable-gpu --hide-scrollbars --virtual-time-budget=14000 \
  --window-size=1200,1500 --screenshot=docs/web-demo.png "file://$TMP/demo.html" 2>/dev/null

rm -rf "$TMP"
echo "已更新 docs/web-gate.png 和 docs/web-demo.png"
