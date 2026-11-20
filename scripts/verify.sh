#!/usr/bin/env bash
# 自检脚本：用固定 seed 的模拟数据跑一遍，断言统计口径没被改坏。
set -euo pipefail
cd "$(dirname "$0")/.."

BIN=.build/release/podsstat
MOCK=samples/mock_export.xml
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

echo "▸ 生成模拟数据"
"$BIN" --mock "$MOCK" --days 45 >/dev/null

echo "▸ 导出 JSON / CSV / HTML"
"$BIN" "$MOCK" --tz +08:00 --json "$TMP/s.json" --csv "$TMP/s.csv" --html "$TMP/s.html" --quiet >/dev/null

echo "▸ 校验"
python3 - "$TMP" <<'PY'
import csv, json, sys, os

tmp = sys.argv[1]
d = json.load(open(os.path.join(tmp, 's.json')))
s = d['summary']
sessions = d['sessions']

def fail(msg):
    print('  ✗', msg)
    sys.exit(1)

def ok(msg):
    print('  ✓', msg)

# 1. 会话总时长与 summary 一致
total = sum(x['duration'] for x in sessions)
if abs(total - s['totalDuration']) > 1.0:
    fail('会话时长之和 %.1f 与 summary %.1f 不一致' % (total, s['totalDuration']))
ok('会话时长之和 == summary（%.1f 秒）' % total)

# 2. 每日时长之和 == 会话时长之和
day_sum = sum(x['duration'] for x in d['days'])
if abs(day_sum - total) > 1.0:
    fail('每日时长之和 %.1f != %.1f' % (day_sum, total))
ok('每日时长之和一致')

# 3. 每小时分桶之和 == 会话时长之和（±1 秒/会话 的取整误差）
hour_sum = sum(x['duration'] for x in d['hours'])
if abs(hour_sum - total) > max(2.0, len(sessions) * 1.0):
    fail('小时分桶之和 %.1f != %.1f' % (hour_sum, total))
ok('7×24 分桶之和一致')

# 4. 音量直方图之和 <= 会话时长（无音量样本的会话不计入）
bin_sum = sum(x['duration'] for x in d['dbHistogram'])
if bin_sum > total + 1.0:
    fail('直方图之和 %.1f 超过总时长 %.1f' % (bin_sum, total))
if bin_sum < total * 0.9:
    fail('直方图覆盖过低：%.1f / %.1f' % (bin_sum, total))
ok('音量直方图覆盖 %.1f%%' % (bin_sum / total * 100))

# 5. 会话按时间排序且互不重叠
prev_end = None
for x in sessions:
    if prev_end and x['start'] < prev_end:
        fail('会话重叠或未排序：%s' % x['start'])
    prev_end = x['end']
ok('会话有序且不重叠')

# 6. ≥80dB 时长不超过总时长
if s['loudDuration'] > total + 1:
    fail('≥80dB 时长 %.1f 超过总时长 %.1f' % (s['loudDuration'], total))
if s['veryLoudDuration'] > s['loudDuration'] + 1:
    fail('≥90dB 时长大于 ≥80dB 时长')
ok('听力负担口径自洽（≥80: %.0f 秒，≥90: %.0f 秒）' % (s['loudDuration'], s['veryLoudDuration']))

# 7. CSV 行数 == 会话数 + 表头
rows = list(csv.reader(open(os.path.join(tmp, 's.csv'))))
if len(rows) - 1 != len(sessions):
    fail('CSV 行数 %d != 会话数 %d' % (len(rows) - 1, len(sessions)))
ok('CSV 行数与会话数一致（%d 行）' % (len(rows) - 1))

# 8. HTML 里内嵌了 payload
html = open(os.path.join(tmp, 's.html')).read()
if 'const DATA = ' not in html or '"sessions"' not in html:
    fail('HTML 里没有内嵌数据')
if len(html) < 8000:
    fail('HTML 过小，可能没渲染出来')
ok('HTML 报告 %.0f KB，含内嵌数据' % (len(html) / 1024))

print('  ✓ 全部通过：%d 次佩戴 / %s' % (len(sessions), s['totalDuration']))
PY

echo "▸ 边界用例"
# 空文件
echo '<?xml version="1.0"?><HealthData></HealthData>' > "$TMP/empty.xml"
if "$BIN" "$TMP/empty.xml" --quiet 2>/dev/null; then
    echo "  ✗ 空文件应当报错退出"; exit 1
else
    echo "  ✓ 空文件正确报错"
fi

# 不存在
if "$BIN" "$TMP/nope.xml" --quiet 2>/dev/null; then
    echo "  ✗ 不存在的文件应当报错退出"; exit 1
else
    echo "  ✓ 不存在的文件正确报错"
fi

# gap 变小 → 会话数不变或更多
A=$("$BIN" "$MOCK" --gap 60 --quiet --json "$TMP/a.json" >/dev/null; python3 -c "import json;print(len(json.load(open('$TMP/a.json'))['sessions']))")
B=$("$BIN" "$MOCK" --gap 1800 --quiet --json "$TMP/b.json" >/dev/null; python3 -c "import json;print(len(json.load(open('$TMP/b.json'))['sessions']))")
if [ "$A" -lt "$B" ]; then
    echo "  ✗ gap 变大反而切出更多会话（60s: $A, 1800s: $B）"; exit 1
fi
echo "  ✓ gap 单调性正常（60s → $A 次，1800s → $B 次）"

echo "全部通过。"
