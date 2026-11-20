#!/usr/bin/env bash
# 一键刷新网页版并提示后续 git 操作
set -euo pipefail
cd "$(dirname "$0")/.."

echo "▸ 构建 release…"
swift build -c release >/dev/null

echo "▸ 生成 docs/index.html…"
./.build/release/podsstat --web docs/index.html

echo
echo "▸ 变更："
git status --short || true

echo
echo "下一步："
echo "  git add -A && git commit -m 'update web report'"
echo "  git push"
echo
echo "仓库设置 → Pages → Source 选 “Deploy from a branch”，分支 main，目录 /docs"
echo "（或直接启用仓库里的 .github/workflows/pages.yml，它会自动构建并发布）"
