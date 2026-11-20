import Foundation

/// HTML 报告的脚本部分：所有统计与绘图都在浏览器里完成，数据以 JSON 内嵌。
enum HTMLReportScript {

    static let script = ##"""
    <script>
    (function () {
      "use strict";
      const DATA = __PAYLOAD__;
      const BOOT = "__BOOT__";
      let S = DATA.sessions || [];
      const WEEK = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
      const $ = (id) => document.getElementById(id);

      // ---------- 基础工具 ----------
      function pad(n) { return n < 10 ? '0' + n : '' + n; }
      function pct(r) {
        const v = r * 100;
        if (v > 0 && v < 0.1) return '<0.1%';
        return v.toFixed(1) + '%';
      }
      function dayKey(d) { return d.getFullYear() + '-' + pad(d.getMonth() + 1) + '-' + pad(d.getDate()); }
      function monthKey(d) { return d.getFullYear() + '-' + pad(d.getMonth() + 1); }
      function shortDur(sec) {
        const m = Math.round(sec / 60);
        if (m < 60) return m + 'm';
        const h = Math.floor(m / 60), r = m % 60;
        return r ? h + 'h' + r : h + 'h';
      }
      function fmtDur(sec) {
        sec = Math.round(sec || 0);
        if (sec <= 0) return '0 分钟';
        if (sec < 60) return sec + ' 秒';
        const tm = Math.round(sec / 60);
        const h = Math.floor(tm / 60), m = tm % 60;
        if (h === 0) return m + ' 分钟';
        if (m === 0) return h + ' 小时';
        return h + ' 小时 ' + m + ' 分';
      }
      function fmtHM(sec) {
        const tm = Math.round((sec || 0) / 60);
        return Math.floor(tm / 60) + ':' + pad(tm % 60);
      }
      function esc(s) {
        return String(s == null ? '' : s).replace(/&/g, '&amp;').replace(/</g, '&lt;')
          .replace(/>/g, '&gt;').replace(/"/g, '&quot;');
      }
      function spansOf(s) { return (s.g && s.g.length) ? s.g : [[s.s, s.e]]; }
      function walkSpans(list, step) {
        for (let i = 0; i < list.length; i++) {
          const sp = spansOf(list[i]);
          for (let j = 0; j < sp.length; j++) {
            let cur = sp[j][0];
            const end = sp[j][1];
            let guard = 0;
            while (cur < end && guard++ < 100000) {
              const next = step(cur, end);
              if (!(next > cur)) break;
              cur = next;
            }
          }
        }
      }
      function num(v) { return Math.round(v || 0).toLocaleString('en-US'); }

      // 数字滚动
      function animateNum(el, to, suffix, digits) {
        if (!el) return;
        const fmt = (v) => digits ? v.toFixed(digits) : num(v);
        const seq = (el.__n || 0) + 1;
        el.__n = seq;
        const from = 0, dur = 1100, t0 = performance.now();
        function tick(t) {
          if (el.__n !== seq) return;
          const p = Math.min(1, (t - t0) / dur);
          const e = 1 - Math.pow(1 - p, 3);
          el.textContent = fmt(from + (to - from) * e) + (suffix || '');
          if (p < 1) requestAnimationFrame(tick);
        }
        requestAnimationFrame(tick);
        // 兜底：标签页切到后台时 rAF 会暂停，1.5 秒后无论如何落到终值
        setTimeout(function () {
          if (el.__n !== seq) return;
          el.__n = seq + 1;
          el.textContent = fmt(to) + (suffix || '');
        }, 1500);
      }

      // 滚动出场
      const io = ('IntersectionObserver' in window) ? new IntersectionObserver(function (es) {
        es.forEach(function (en) {
          if (en.isIntersecting) { en.target.classList.add('in'); io.unobserve(en.target); }
        });
      }, { threshold: 0.06, rootMargin: '0px 0px -8% 0px' }) : null;
      function observeAll() {
        document.querySelectorAll('.reveal:not(.in)').forEach(function (n, i) {
          n.style.animationDelay = Math.min(i * 60, 300) + 'ms';
          if (io) io.observe(n); else n.classList.add('in');
        });
      }

      // ---------- 统计 ----------
      function compute(list) {
        const byDay = new Map(), byMonth = new Map(), dev = new Map();
        const hour = new Array(24).fill(0);
        const wdHour = Array.from({ length: 7 }, () => new Array(24).fill(0));
        const wd = new Array(7).fill(0);
        const dbHist = new Array(12).fill(0);
        const durBins = new Array(7).fill(0);
        let total = 0, n = 0, peak = 0, dbNum = 0, dbDen = 0, loud = 0, vl = 0;
        let longest = 0, sampleN = 0, first = Infinity, last = -Infinity;
        let streakCur = 0, streakMax = 0;

        for (let i = 0; i < list.length; i++) {
          const s = list[i];
          total += s.d; n++; sampleN += s.n;
          if (s.mx > peak) peak = s.mx;
          if (s.db > 0) { dbNum += s.db * s.d; dbDen += s.d; }
          loud += s.loud; vl += s.vl;
          if (s.d > longest) longest = s.d;
          if (s.s < first) first = s.s;
          if (s.e > last) last = s.e;

          for (let k = 0; k < 12; k++) dbHist[k] += (s.b && s.b[k]) || 0;

          const m = s.d / 60;
          durBins[m < 5 ? 0 : m < 15 ? 1 : m < 30 ? 2 : m < 60 ? 3 : m < 120 ? 4 : m < 180 ? 5 : 6]++;

          let dv = dev.get(s.src);
          if (!dv) { dv = { name: s.src, sec: 0, n: 0, first: s.s, last: s.e }; dev.set(s.src, dv); }
          dv.sec += s.d; dv.n++;
          if (s.s < dv.first) dv.first = s.s;
          if (s.e > dv.last) dv.last = s.e;

          const mk = monthKey(new Date(s.s * 1000));
          let mo = byMonth.get(mk);
          if (!mo) { mo = { key: mk, dbW: 0, secW: 0, sec: 0, n: 0, date: new Date(s.s * 1000) }; byMonth.set(mk, mo); }
          mo.sec += s.d; mo.n++;
          if (s.db > 0) { mo.dbW += s.db * s.d; mo.secW += s.d; }
        }

        // 时段级（按真实区间切分）
        walkSpans(list, function (cur, spanEnd) {
          const d = new Date(cur * 1000);
          const hourEnd = new Date(d.getFullYear(), d.getMonth(), d.getDate(), d.getHours() + 1).getTime() / 1000;
          const dayEnd = new Date(d.getFullYear(), d.getMonth(), d.getDate() + 1).getTime() / 1000;
          const pieceEnd = Math.min(spanEnd, hourEnd, dayEnd);
          const sec = pieceEnd - cur;
          hour[d.getHours()] += sec;
          wdHour[d.getDay()][d.getHours()] += sec;
          wd[d.getDay()] += sec;
          const k = dayKey(d);
          let rec = byDay.get(k);
          if (!rec) { rec = { sec: 0 }; byDay.set(k, rec); }
          rec.sec += sec;
          return pieceEnd;
        });

        // 连续天数
        const keys = Array.from(byDay.keys()).filter(function (k) { return byDay.get(k).sec >= 60; }).sort();
        let prev = null;
        for (let i = 0; i < keys.length; i++) {
          const t = new Date(keys[i] + 'T00:00:00').getTime();
          if (prev !== null && Math.round((t - prev) / 86400000) === 1) streakCur++; else streakCur = 1;
          if (streakCur > streakMax) streakMax = streakCur;
          prev = t;
        }
        const todayKey = dayKey(new Date(last * 1000));
        let tail = 0;
        for (let i = keys.length - 1; i >= 0; i--) {
          const t = new Date(keys[i] + 'T00:00:00').getTime();
          const gap = Math.round((new Date(todayKey + 'T00:00:00').getTime() - t) / 86400000);
          if (gap === tail) tail++; else break;
        }

        const spanDays = (first === Infinity) ? 0
          : Math.round((new Date(dayKey(new Date(last * 1000)) + 'T00:00:00') -
                        new Date(dayKey(new Date(first * 1000)) + 'T00:00:00')) / 86400000) + 1;

        return {
          total: total, count: n, peak: peak, loud: loud, vl: vl,
          avgDb: dbDen > 0 ? dbNum / dbDen : 0,
          longest: longest, sampleN: sampleN,
          first: first === Infinity ? 0 : first, last: last === -Infinity ? 0 : last,
          activeDays: keys.length, spanDays: spanDays,
          byDay: byDay, byMonth: byMonth, dev: dev,
          hour: hour, wdHour: wdHour, wd: wd,
          dbHist: dbHist, durBins: durBins,
          streakMax: streakMax, streakNow: tail
        };
      }

      // ---------- 范围 ----------
      let RANGE = 0;
      function filtered() {
        if (!RANGE || !S.length) return S;
        const end = S[S.length - 1].e;
        const cut = end - RANGE * 86400;
        return S.filter(function (s) { return s.e >= cut; });
      }

      // ---------- 渲染 ----------
      function renderHero(st, list) {
        const days = st.activeDays || 1;
        animateNum($('heroHours'), Math.floor(st.total / 3600));
        animateNum($('heroSessions'), st.count);
        animateNum($('heroDays'), st.activeDays);
        const m = DATA.meta || {};
        const dayTxt = (function (t) {
          const a = new Date(st.first * 1000), b = new Date(st.last * 1000);
          const multi = st.spanDays > 366;
          const f = (d) => (multi ? d.getFullYear() + '-' : '') + pad(d.getMonth() + 1) + '-' + pad(d.getDate());
          return f(a) + ' → ' + f(b) + '（' + num(st.spanDays) + ' 天）';
        })();
        $('metaLine').innerHTML =
          '数据源 <b>' + esc((m.file || '').split('/').pop()) + '</b> · 间隔 ≤ ' + (m.gap || 300) + ' 秒算一次佩戴 · ' + dayTxt +
          (RANGE ? ' · 视角：最近 ' + RANGE + ' 天' : '');
        $('footMeta').textContent = '共 ' + num(S.length) + ' 次佩戴记录 · ' + num(st.sampleN) + ' 条音量采样';
      }

      function renderKpi(st) {
        const days = Math.max(1, st.spanDays);
        const activeDays = Math.max(1, st.activeDays);
        const items = [
          { k: '活跃日日均', v: fmtDur(st.total / activeDays), s: '只在戴耳机的日子算', p: Math.min(1, (st.total / activeDays) / 14400) },
          { k: '总日均', v: fmtDur(st.total / days), s: '按 ' + days + ' 天窗口平摊', p: Math.min(1, (st.total / days) / 14400) },
          { k: '平均单次', v: fmtDur(st.total / Math.max(1, st.count)), s: '共 ' + num(st.count) + ' 次', p: Math.min(1, (st.total / Math.max(1, st.count)) / 7200) },
          { k: '平均音量', v: st.avgDb ? Math.round(st.avgDb) + ' dB' : '—', s: st.peak ? '峰值 ' + Math.round(st.peak) + ' dB' : '', p: Math.min(1, st.avgDb / 100), tone: st.avgDb >= 80 ? 'warn' : '' },
          { k: '≥80 dB 时长', v: fmtDur(st.loud), s: st.total ? pct(st.loud / st.total) + ' 的佩戴时间' : '', p: st.total ? Math.min(1, st.loud / st.total * 4) : 0, tone: st.loud > 3600 ? 'warn' : '' },
          { k: '一次最长', v: fmtDur(st.longest), s: '连续佩戴不摘', p: Math.min(1, st.longest / 14400) }
        ];
        $('kpis').innerHTML = items.map(function (it) {
          return '<div class="kpi glass"><span class="k">' + it.k + '</span>' +
            '<span class="v ' + (it.tone || '') + '">' + it.v + '</span>' +
            '<span class="s">' + esc(it.s) + '</span>' +
            '<div class="bar"><i style="width:' + Math.round(it.p * 100) + '%"></i></div></div>';
        }).join('');
      }

      function renderInsights(st, list) {
        const out = [];
        if (!list.length) { $('insights').innerHTML = '<li class="empty">这段时间没有佩戴记录</li>'; return; }
        const days = Math.max(1, st.spanDays);

        out.push('这段时间累计戴耳机 <em>' + fmtDur(st.total) + '</em>，平均每天 <em>' + fmtDur(st.total / days) + '</em>。');

        // 高峰时段
        let hi = 0; st.hour.forEach(function (v, i) { if (v > st.hour[hi]) hi = i; });
        if (st.total > 0) {
          out.push('最常戴的时段是 <em>' + pad(hi) + ':00–' + pad((hi + 1) % 24) + ':00</em>，累计 ' + fmtDur(st.hour[hi]) + '，占全部的 <em>' + Math.round(st.hour[hi] / st.total * 100) + '%</em>。');
        }

        // 最勤星期
        let wi = 0; st.wd.forEach(function (v, i) { if (v > st.wd[wi]) wi = i; });
        const weekend = st.wd[0] + st.wd[6], workday = st.wd[1] + st.wd[2] + st.wd[3] + st.wd[4] + st.wd[5];
        const wdDays = Math.max(1, days * 5 / 7), weDays = Math.max(1, days * 2 / 7);
        (function () {
          const wdAvg = workday / wdDays, weAvg = weekend / weDays;
          const diff = Math.abs(wdAvg - weAvg) / Math.max(wdAvg, weAvg, 1);
          let tail;
          if (!workday || !weekend) tail = '';
          else if (diff < 0.12) tail = '，工作日和周末的日均几乎一样（各约 ' + fmtDur((wdAvg + weAvg) / 2) + '），习惯很稳定。';
          else if (weAvg > wdAvg) tail = '，周末日均 ' + fmtDur(weAvg) + '，比工作日的 ' + fmtDur(wdAvg) + ' 更多。';
          else tail = '，工作日日均 ' + fmtDur(wdAvg) + '，比周末的 ' + fmtDur(weAvg) + ' 更多。';
          out.push('<em>' + WEEK[wi] + '</em>用得最多（' + fmtDur(st.wd[wi]) + '）' + tail);
        })();

        // 音量
        if (st.avgDb) {
          if (st.avgDb < 70) out.push('平均音量 <em>' + Math.round(st.avgDb) + ' dB</em>，属于很克制的范围，耳朵会感谢你。');
          else if (st.avgDb < 80) out.push('平均音量 <em>' + Math.round(st.avgDb) + ' dB</em>，还算健康，注意别在嘈杂环境里一路往上调。');
          else out.push('平均音量 <em>' + Math.round(st.avgDb) + ' dB</em>，已经超过 WHO 建议的长期上限，建议在「设置 → 声音与触感 → 耳机安全」里开「降低高音量」。');
        }
        if (st.total > 0 && st.loud > 0) {
          out.push('超过 80 dB 的时间共 <em>' + fmtDur(st.loud) + '</em>，只占全部的 ' + pct(st.loud / st.total) + '。');
        }
        if (st.vl > 0) {
          out.push('有 <em>' + fmtDur(st.vl) + '</em> 时间音量超过 90 dB' + (st.vl > 3600 ? '，这个量级长期听会伤听力' : '，偶尔为之问题不大') + '。');
        }

        // 熬夜
        if (st.late && st.late.size > 0 && st.activeDays > 30) {
          const lateRatio = st.late.size / Math.max(1, st.activeDays);
          if (lateRatio > 0.05) {
            out.push('有 <em>' + esc(pct(lateRatio)) + '</em> 的天在凌晨 0–4 点还戴着耳机（' + st.late.size + ' 天）' +
              (lateRatio > 0.3 ? '，这部分时间最容易被忽略，也是听力负担最重的时候。' : '。'));
          }
        }

        // 最长一次
        const longest = list.reduce(function (a, b) { return b.d > a.d ? b : a; }, list[0]);
        if (longest && longest.d > 600) {
          const d = new Date(longest.s * 1000);
          const multi = st.spanDays > 366;
          const txt = (multi ? d.getFullYear() + '-' : '') + pad(d.getMonth() + 1) + '-' + pad(d.getDate()) + ' ' + WEEK[d.getDay()] +
            ' ' + pad(d.getHours()) + ':' + pad(d.getMinutes());
          out.push('最长的一次是 <em>' + txt + '</em>，连续戴了 <em>' + fmtDur(longest.d) + '</em>' + (longest.src ? '（' + esc(longest.src) + '）' : '') + '。');
        }

        // 连续
        out.push('历史最长连续 <em>' + st.streakMax + ' 天</em>每天都戴' + (st.streakNow > 1 ? '，目前已经连续 <em>' + st.streakNow + ' 天</em>' : '') + '。');

        // 设备
        if (st.dev.size > 1) {
          const arr = Array.from(st.dev.values()).sort(function (a, b) { return b.sec - a.sec; });
          const top = arr[0];
          out.push('主力是 <em>' + esc(top.name) + '</em>，贡献了 <em>' + Math.round(top.sec / st.total * 100) + '%</em> 的佩戴时长' +
            (arr.length > 1 ? '，一共用过 ' + arr.length + ' 副' : '') + '。');
        }

        // 碎片化程度
        const medMin = (function () {
          const arr = list.map(function (s) { return s.d; }).sort(function (a, b) { return a - b; });
          return arr[Math.floor(arr.length / 2)] / 60;
        })();
        out.push('单次佩戴的中位数是 <em>' + Math.round(medMin) + ' 分钟</em>，' +
          (medMin < 20 ? '偏碎片化，多半是通勤路上或随手听两首。' : medMin < 45 ? '属于中等强度，一次能听完一张专辑。' : '是长时间沉浸型，一次就是一整张歌单起步。'));

        $('insights').innerHTML = out.map(function (t, i) {
          return '<li style="animation-delay:' + (i * 70) + 'ms">' + t + '</li>';
        }).join('');
      }

      function renderDevices(st) {
        const arr = Array.from(st.dev.values()).sort(function (a, b) { return a.first - b.first; });
        if (!arr.length) { $('devices').innerHTML = '<div class="empty">无数据</div>'; return; }
        const maxSec = Math.max.apply(null, arr.map(function (d) { return d.sec; }).concat([1]));
        const colors = ['#0a84ff', '#5ac8fa', '#bf5af2', '#30d158', '#ff9f0a', '#ff453a', '#64d2ff'];
        $('devices').innerHTML = arr.map(function (d, i) {
          const w = Math.max(2, d.sec / maxSec * 100);
          const c = colors[i % colors.length];
          const a = new Date(d.first * 1000), b = new Date(d.last * 1000);
          const span = a.getFullYear() + '.' + pad(a.getMonth() + 1) + ' – ' + b.getFullYear() + '.' + pad(b.getMonth() + 1);
          const tip = d.name + '　共 ' + fmtDur(d.sec) + '　' + d.n + ' 次　' + span;
          return '<div class="dev" title="' + esc(tip) + '">' +
            '<div class="nm"><i style="background:' + c + ';color:' + c + '"></i>' + esc(d.name || '未知设备') + '</div>' +
            '<div class="track"><i style="width:' + w.toFixed(1) + '%;background:linear-gradient(90deg,' + c + ',rgba(255,255,255,.65));animation-delay:' + (i * 70) + 'ms"></i></div>' +
            '<div class="amt">' + fmtDur(d.sec) + '<div class="span">' + span + '</div></div></div>';
        }).join('');
      }

      function renderCalendar(st) {
        const host = $('cal');
        if (!st.byDay.size) { host.innerHTML = '<div class="empty">无数据</div>'; return; }
        const keys = Array.from(st.byDay.keys()).sort();
        const y0 = +keys[0].slice(0, 4), y1 = +keys[keys.length - 1].slice(0, 4);
        const maxSec = Math.max.apply(null, Array.from(st.byDay.values()).map(function (v) { return v.sec; }).concat([1]));
        let html = '';
        for (let y = y0; y <= y1; y++) {
          // 首年/末年只画真实数据覆盖的月份，别留半年空白
          const start = (y === y0) ? new Date(keys[0] + 'T00:00:00') : new Date(y, 0, 1);
          const end = (y === y1) ? new Date(keys[keys.length - 1] + 'T00:00:00') : new Date(y, 11, 31);
          // 从当年 1 月 1 日所在周的周一开始
          const offset = (start.getDay() + 6) % 7;
          const cells = [];
          for (let i = 0; i < offset; i++) cells.push(null);
          for (let d = new Date(start); d <= end; d.setDate(d.getDate() + 1)) cells.push(new Date(d));
          const weeks = Math.ceil(cells.length / 7);
          let yearSec = 0;
          let inner = '';
          cells.forEach(function (d, i) {
            if (!d) { inner += '<i style="background:transparent;animation:none"></i>'; return; }
            const rec = st.byDay.get(dayKey(d));
            const sec = rec ? rec.sec : 0;
            yearSec += sec;
            // 五档离散色，比连续渐变更容易一眼分出「这天戴得多不多」
            const r = sec / maxSec;
            let bg;
            if (sec < 60) bg = 'rgba(255,255,255,.042)';
            else if (r < 0.18) bg = 'rgba(10,132,255,.24)';
            else if (r < 0.4) bg = 'rgba(10,132,255,.44)';
            else if (r < 0.62) bg = 'rgba(10,132,255,.66)';
            else if (r < 0.84) bg = 'rgba(10,132,255,.86)';
            else bg = 'rgba(90,200,250,1)';
            const label = dayKey(d) + '　' + (sec > 0 ? fmtDur(sec) : '没戴');
            const delay = ((i % 7) * 8 + Math.floor(i / 7) * 2);
            inner += '<i title="' + esc(label) + '" style="background:' + bg + ';animation-delay:' + delay + 'ms;box-shadow:' +
              (sec >= maxSec * 0.6 ? '0 0 8px rgba(10,132,255,.55)' : 'none') + '"></i>';
          });
          html += '<div class="calYear"><div class="ylab">' + y + '　共 ' + fmtDur(yearSec) + '</div>' +
            '<div class="calGrid" style="grid-template-columns:repeat(' + weeks + ',11px)">' + inner + '</div></div>';
        }
        host.innerHTML = html;
      }

      function renderDaily(st) {
        const keys = Array.from(st.byDay.keys()).sort();
        const host = $('daily'), axis = $('axis');
        if (!keys.length) { host.innerHTML = ''; axis.innerHTML = ''; return; }
        const first = new Date(keys[0] + 'T00:00:00');
        const last = new Date(keys[keys.length - 1] + 'T00:00:00');
        const series = [];
        for (let d = new Date(first); d <= last; d.setDate(d.getDate() + 1)) {
          const rec = st.byDay.get(dayKey(d));
          series.push({ date: new Date(d), sec: rec ? rec.sec : 0 });
        }
        // 跨度太长时按月聚合，按「当月日均」定高
        let bars = series, isMonth = false;
        if (series.length > 120) {
          isMonth = true;
          const map = new Map();
          series.forEach(function (s) {
            const k = monthKey(s.date);
            let r = map.get(k);
            if (!r) { r = { sec: 0, days: 0, date: new Date(s.date.getFullYear(), s.date.getMonth(), 1) }; map.set(k, r); }
            r.sec += s.sec; r.days++;
          });
          bars = Array.from(map.values());
          bars.forEach(function (b) { b.val = b.days ? b.sec / b.days : 0; });
        } else {
          series.forEach(function (b) { b.val = b.sec; });
        }
        $('dailyTitle').textContent = isMonth ? '每月平均佩戴时长' : '每日佩戴时长';
        $('dailyHint').innerHTML = isMonth
          ? '跨度太长，按<b>月</b>聚合 · 柱高是该月<b>日均</b>佩戴时长'
          : '按天拆分，<b style="color:#bf5af2">紫色</b>是周末';

        const maxVal = Math.max.apply(null, bars.map(function (b) { return b.val; }).concat([1]));
        host.innerHTML = bars.map(function (b, i) {
          const pct = Math.max(b.val > 0 ? 2 : 0.8, b.val / maxVal * 100);
          const weekend = !isMonth && [0, 6].includes(b.date.getDay());
          const cls = 'bar' + (weekend ? ' weekend' : '') + (b.val > 0 ? '' : ' zero');
          const lab = isMonth
            ? b.date.getFullYear() + '/' + pad(b.date.getMonth() + 1) + '　日均 ' + fmtDur(b.val) + '　当月共 ' + fmtDur(b.sec)
            : pad(b.date.getMonth() + 1) + '/' + pad(b.date.getDate()) + ' ' + WEEK[b.date.getDay()] + '　' + fmtDur(b.val);
          return '<div class="' + cls + '" style="height:' + pct.toFixed(1) + '%;animation-delay:' +
            Math.min(i * 4, 400) + 'ms" title="' + esc(lab) + '"></div>';
        }).join('');

        const step = Math.max(1, Math.ceil(bars.length / 8));
        axis.style.gridTemplateColumns = 'repeat(' + bars.length + ',minmax(0,1fr))';
        if (isMonth && bars.length > 24) {
          axis.innerHTML = bars.map(function (b, i) {
            const isNewYear = i === 0 || b.date.getFullYear() !== bars[i - 1].date.getFullYear();
            return isNewYear ? '<span style="overflow:visible">' + b.date.getFullYear() + '</span>' : '<span></span>';
          }).join('');
        } else {
          axis.innerHTML = bars.map(function (b, i) {
            if (i % step !== 0) return '<span></span>';
            return '<span>' + (isMonth ? (b.date.getMonth() + 1) + '月'
              : pad(b.date.getMonth() + 1) + '/' + pad(b.date.getDate())) + '</span>';
          }).join('');
        }
      }

      function renderHeat(st) {
        let max = 0, lo = Infinity;
        st.wdHour.forEach(function (r) {
          r.forEach(function (v) {
            if (v > max) max = v;
            if (v > 60 && v < lo) lo = v;
          });
        });
        if (!isFinite(lo)) lo = 0;
        let html = '<div class="hrow"><span></span>';
        for (let h = 0; h < 24; h++) html += '<span>' + (h % 3 === 0 ? h : '') + '</span>';
        html += '</div>';
        for (let w = 0; w < 7; w++) {
          html += '<div class="row"><div class="lab">' + WEEK[w].slice(1) + '</div>';
          for (let h = 0; h < 24; h++) {
            const v = st.wdHour[w][h];
            // 用 min–max 归一化而不是 v/max：真实数据各时段都很均匀，直接除以最大值会全糊成一片
            const t = (v > 0 && max > lo) ? Math.pow((v - lo) / (max - lo), 0.75) : (v > 0 ? 0.55 : 0);
            const bg = v <= 0 ? 'rgba(255,255,255,.045)'
              : 'rgba(' + Math.round(8 + t * 78) + ',' + Math.round(100 + t * 108) + ',' + Math.round(200 + t * 55) + ',' + (0.16 + t * 0.84).toFixed(3) + ')';
            const tip = WEEK[w] + ' ' + pad(h) + ':00–' + pad(h + 1) + ':00　' + (v > 0 ? fmtDur(v) : '没戴');
            html += '<div class="cell" title="' + esc(tip) + '" style="background:' + bg +
              ';animation-delay:' + (w * 12 + h * 11) + 'ms"></div>';
          }
          html += '</div>';
        }
        $('heat').innerHTML = html;
      }

      function renderDbTrend(st) {
        const host = $('dbtrend');
        const months = Array.from(st.byMonth.values())
          .filter(function (m) { return m.secW > 30; })
          .sort(function (a, b) { return a.date - b.date; });
        if (months.length < 2) { host.innerHTML = '<div class="empty">这段时间还不够画出趋势</div>'; return; }
        const pts = months.map(function (m) { return { date: m.date, db: m.dbW / m.secW, sec: m.sec }; });
        const W = 1000, H = 180, PL = 34, PR = 10, PT = 14, PB = 26;
        const dbs = pts.map(function (p) { return p.db; });
        const lo = Math.max(40, Math.min.apply(null, dbs) - 5);
        const hi = Math.min(105, Math.max.apply(null, dbs) + 5);
        const x = function (i) { return PL + (i / (pts.length - 1)) * (W - PL - PR); };
        const y = function (v) { return PT + (1 - (v - lo) / (hi - lo)) * (H - PT - PB); };

        let line = '', area = '';
        pts.forEach(function (p, i) {
          line += (i ? ' L' : 'M') + x(i).toFixed(1) + ' ' + y(p.db).toFixed(1);
        });
        area = line + ' L' + x(pts.length - 1).toFixed(1) + ' ' + (H - PB) + ' L' + x(0).toFixed(1) + ' ' + (H - PB) + ' Z';

        let dots = '';
        pts.forEach(function (p, i) {
          const hot = p.db >= 80;
          const c = hot ? '#ff453a' : (p.db >= 70 ? '#ff9f0a' : '#5ac8fa');
          dots += '<circle class="dot" cx="' + x(i).toFixed(1) + '" cy="' + y(p.db).toFixed(1) + '" r="' +
            (pts.length > 60 ? 2.2 : 3.6) + '" fill="' + c + '" opacity="' + (pts.length > 60 ? 0.55 : 0.95) + '">' +
            '<title>' + p.date.getFullYear() + '-' + pad(p.date.getMonth() + 1) + '　平均 ' +
            p.db.toFixed(1) + ' dB　共 ' + fmtDur(p.sec) + '</title></circle>';
        });

        // 参考线
        let ref = '';
        if (lo < 80 && hi > 80) {
          ref = '<line x1="' + PL + '" y1="' + y(80) + '" x2="' + (W - PR) + '" y2="' + y(80) +
            '" stroke="rgba(255,69,58,.55)" stroke-width="1" stroke-dasharray="5 5"/>' +
            '<text x="' + (W - PR) + '" y="' + (y(80) - 7) + '" fill="rgba(255,138,128,.85)" font-size="11" text-anchor="end">80 dB</text>';
        }
        // 轴
        let labels = '';
        pts.forEach(function (p, i) {
          // 每年 1 月一个标签 + 首尾，间隔固定 12 个月，读起来比等分步长自然
          const isEdge = i === 0 || i === pts.length - 1;
          if (!isEdge && p.date.getMonth() !== 0) return;
          if (!isEdge && pts.length - 1 - i < 3) return;
          const y4 = String(p.date.getFullYear()).slice(2) + '.' + pad(p.date.getMonth() + 1);
          labels += '<text x="' + x(i).toFixed(1) + '" y="' + (H - 6) + '" fill="rgba(235,235,245,.34)" font-size="11" text-anchor="middle">' +
            y4 + '</text>';
        });
        [lo, (lo + hi) / 2, hi].forEach(function (v) {
          labels += '<text x="' + (PL - 8) + '" y="' + (y(v) + 4) + '" fill="rgba(235,235,245,.3)" font-size="10" text-anchor="end">' +
            Math.round(v) + '</text>';
        });

        host.innerHTML = '<svg viewBox="0 0 ' + W + ' ' + H + '" preserveAspectRatio="none">' +
          '<defs><linearGradient id="ag" x1="0" y1="0" x2="0" y2="1">' +
          '<stop offset="0%" stop-color="rgba(90,200,250,.42)"/><stop offset="100%" stop-color="rgba(90,200,250,0)"/>' +
          '</linearGradient></defs>' +
          '<path d="' + area + '" fill="url(#ag)"/>' +
          '<path d="' + line + '" fill="none" stroke="#5ac8fa" stroke-width="2" stroke-linejoin="round" stroke-linecap="round"/>' +
          ref + dots + labels + '</svg>';
      }

      function renderVolume(st) {
        const total = st.dbHist.reduce(function (a, b) { return a + b; }, 0);
        if (!total) { $('volume').innerHTML = '<div class="empty">无数据</div>'; return; }
        const max = Math.max.apply(null, st.dbHist.concat([1]));
        let html = '';
        for (let i = 0; i < 12; i++) {
          const lo = 40 + i * 5, hi = lo + 5;
          const sec = st.dbHist[i];
          const hot = lo >= 90 ? 'bad' : (lo >= 80 ? 'hot' : '');
          html += '<div class="line"><div class="l">' + lo + '–' + hi + ' dB</div>' +
            // 极小占比也要看得见：给个下限，不然 ≥80 dB 的红条会彻底消失
            '<div class="t"><i class="' + hot + '" style="width:' + (sec > 0 ? Math.max(sec / max * 100, 0.7) : 0).toFixed(2) + '%"></i></div>' +
            '<div class="v">' + (sec > 0 ? fmtDur(sec) : '—') +
            (total && sec > 0 ? ' · ' + esc(pct(sec / total)) : '') + '</div></div>';
        }
        $('volume').innerHTML = html;
      }

      function renderDurHist(st, list) {
        const labels = ['< 5 分钟', '5–15 分钟', '15–30 分钟', '30–60 分钟', '1–2 小时', '2–3 小时', '> 3 小时'];
        const max = Math.max.apply(null, st.durBins.concat([1]));
        const total = st.durBins.reduce(function (a, b) { return a + b; }, 0);
        $('durhist').innerHTML = st.durBins.map(function (v, i) {
          return '<div class="line"><div class="l">' + labels[i] + '</div>' +
            '<div class="t"><i style="width:' + (v / max * 100).toFixed(1) + '%"></i></div>' +
            '<div class="v">' + v + ' 次' + (total && v > 0 ? ' · ' + esc(pct(v / total)) : '') + '</div></div>';
        }).join('');
      }

      function renderTable(list, st) {
        const top = list.slice().sort(function (a, b) { return b.d - a.d; }).slice(0, 30);
        if (!top.length) { $('table').innerHTML = '<div class="empty">无记录</div>'; return; }
        let html = '<table><thead><tr><th>时间</th><th class="num">时长</th><th class="num">平均</th>' +
          '<th class="num">峰值</th><th>设备</th></tr></thead><tbody>';
        top.forEach(function (s) {
          const a = new Date(s.s * 1000), b = new Date(s.e * 1000);
          const dt = a.getFullYear() + '-' + pad(a.getMonth() + 1) + '-' + pad(a.getDate()) + ' ' + WEEK[a.getDay()] +
            ' ' + pad(a.getHours()) + ':' + pad(a.getMinutes()) + '–' + pad(b.getHours()) + ':' + pad(b.getMinutes());
          html += '<tr><td>' + dt + '</td><td class="num">' + fmtDur(s.d) + '</td>' +
            '<td class="num">' + (s.db > 0 ? Math.round(s.db) + ' dB' : '—') + '</td>' +
            '<td class="num' + (s.mx >= 90 ? ' hot' : '') + '">' + (s.mx > 0 ? Math.round(s.mx) : '—') + '</td>' +
            '<td class="muted">' + esc(s.src) + '</td></tr>';
        });
        $('table').innerHTML = html + '</tbody></table>';
      }


      // ---------- 依赖度 ----------
      function renderDep(st) {
        const host = $('dep');
        if (!st.total || !st.spanDays) { host.innerHTML = ''; return; }
        const perDay = st.total / st.spanDays;
        const WAKE = 16 * 3600;
        const ratio = perDay / WAKE;
        const level = ratio < 0.03 ? '轻度' : ratio < 0.08 ? '中等' : ratio < 0.16 ? '偏重' : '重度';
        const note = ratio < 0.03
          ? '偶尔听一听，耳机更像工具而不是习惯。'
          : ratio < 0.08 ? '每天有一小段时间泡在声音里，属于很常见的水平。'
          : ratio < 0.16 ? '清醒时间的很大一块都有背景音，多少有点依赖了。'
          : '几乎全天不摘耳机，记得给耳朵留点纯安静的时间。';
        host.innerHTML =
          '<span class="k">耳机依赖度</span>' +
          '<span class="v">' + (ratio * 100).toFixed(1) + '%<small>的清醒时间</small></span>' +
          '<div class="scale"><i style="left:' + Math.min(99, ratio / 0.4 * 100).toFixed(1) + '%"></i></div>' +
          '<span class="note">按清醒 16 小时算 · 平均每天 ' + fmtDur(perDay) + ' · 属于<b>「' + level + '」</b>：' + note + '</span>';
      }

      // ---------- 换机前后对比 ----------
      function renderSwitch(st, list) {
        const host = $('switch');
        const arr = Array.from(st.dev.values())
          .filter(function (d) { return d.sec > 1800; })
          .sort(function (a, b) { return a.first - b.first; });
        if (arr.length < 2) { host.innerHTML = '<div class="empty">只用过一副耳机，没有换代可比</div>'; return; }
        const WIN = 180 * 86400;
        const rows = arr.map(function (d) {
          const t0 = d.first;
          let before = 0, after = 0, bDays = 0, aDays = 0;
          list.forEach(function (x) {
            if (x.e < t0 && x.e >= t0 - WIN) { before += x.d; bDays++; }
            else if (x.s >= t0 && x.s < t0 + WIN) { after += x.d; aDays++; }
          });
          return { name: d.name, t0: t0, bAvg: before / 180, aAvg: after / 180, n: d.sec };
        }).filter(function (r) { return r.bAvg > 0 || r.aAvg > 0; });
        if (!rows.length) { host.innerHTML = '<div class="empty">没有可对比的换代点</div>'; return; }
        host.innerHTML = rows.map(function (r) {
          const d = new Date(r.t0 * 1000);
          const when = d.getFullYear() + '.' + pad(d.getMonth() + 1);
          let chg = '<span class="chg">—</span>';
          if (r.bAvg > 30) {
            const p = (r.aAvg - r.bAvg) / r.bAvg * 100;
            chg = '<span class="chg ' + (p >= 0 ? 'up' : 'down') + '">' +
              (p >= 0 ? '+' : '') + Math.round(p) + '%</span>';
          }
          return '<div class="row" title="' + esc(r.name) + ' 从 ' + when + ' 开始使用">' +
            '<div class="nm">' + esc(r.name || '未知设备') + '</div>' +
            '<div class="pair">' + when + ' 起 <span class="arw">·</span> 换前 ' +
            (r.bAvg > 0 ? '<b>' + fmtDur(r.bAvg) + '</b>/天' : '<b>—</b>') +
            ' <span class="arw">→</span> 换后 ' + (r.aAvg > 0 ? '<b>' + fmtDur(r.aAvg) + '</b>/天' : '<b>—</b>') + '</div>' +
            chg + '</div>';
        }).join('');
      }

      // ---------- 缺席 ----------
      function renderGap(st) {
        const host = $('gap');
        const keys = Array.from(st.byDay.keys()).sort();
        if (keys.length < 2) { host.innerHTML = '<div class="empty">数据太少</div>'; return; }
        const d0 = new Date(keys[0] + 'T00:00:00');
        const d1 = new Date(keys[keys.length - 1] + 'T00:00:00');
        const gaps = [];
        let curStart = null, curLen = 0;
        for (let d = new Date(d0); d <= d1; d.setDate(d.getDate() + 1)) {
          if (!st.byDay.has(dayKey(d))) {
            if (!curStart) curStart = new Date(d);
            curLen++;
          } else if (curStart) {
            if (curLen >= 3) gaps.push({ start: curStart, len: curLen });
            curStart = null; curLen = 0;
          }
        }
        if (curStart && curLen >= 3) gaps.push({ start: curStart, len: curLen });
        gaps.sort(function (a, b) { return b.len - a.len; });

        const zeroDays = Math.max(0, st.spanDays - st.activeDays);
        const longest = gaps.length ? gaps[0] : null;
        const now = new Date(); now.setHours(0, 0, 0, 0);
        const sinceLast = Math.max(0, Math.round((now - d1) / 86400000));

        let html = '<div class="gaps">' +
          '<div class="g"><span class="k">完全没戴的天数</span><b>' + num(zeroDays) + ' 天</b>' +
          '<span class="s">占 ' + esc(pct(zeroDays / Math.max(1, st.spanDays))) + '，其余 ' + num(st.activeDays) + ' 天都有记录</span></div>' +
          '<div class="g"><span class="k">最长的一段空窗</span><b>' + (longest ? longest.len + ' 天' : '—') + '</b>' +
          '<span class="s">' + (longest ? dayKey(longest.start) + ' 起' : '没有超过 3 天的间断') + '</span></div>' +
          '<div class="g"><span class="k">距离上一次佩戴</span><b>' + (sinceLast === 0 ? '今天' : sinceLast + ' 天') + '</b>' +
          '<span class="s">' + dayKey(d1) + ' 是最后一条记录</span></div>' +
          '</div>';

        if (gaps.length > 1) {
          html += '<div class="gaplist">' + gaps.slice(0, 5).map(function (g) {
            const s2 = new Date(g.start.getTime() + (g.len - 1) * 86400000);
            const f = function (d) { return d.getFullYear() + '.' + pad(d.getMonth() + 1) + '.' + pad(d.getDate()); };
            return '<div class="r"><span>' + f(g.start) + ' – ' + f(s2) + '</span><b>' + g.len + ' 天</b></div>';
          }).join('') + '</div>';
        }
        host.innerHTML = html;
      }

      // ---------- 长期趋势（30 天移动平均）----------
      function renderTrend(st) {
        const host = $('trend');
        const keys = Array.from(st.byDay.keys()).sort();
        if (keys.length < 10) { host.innerHTML = '<div class="empty">至少要有 10 天数据才画得出趋势</div>'; return; }
        const d0 = new Date(keys[0] + 'T00:00:00'), d1 = new Date(keys[keys.length - 1] + 'T00:00:00');
        const dates = [], seq = [];
        for (let d = new Date(d0); d <= d1; d.setDate(d.getDate() + 1)) {
          const rec = st.byDay.get(dayKey(d));
          dates.push(new Date(d)); seq.push(rec ? rec.sec : 0);
        }
        const MA = 30, ma = [];
        let acc = 0;
        for (let i = 0; i < seq.length; i++) {
          acc += seq[i];
          if (i >= MA) acc -= seq[i - MA];
          ma.push(i >= MA - 1 ? acc / MA : null);
        }
        const W = 1000, H = 210, PL = 40, PR = 12, PT = 16, PB = 24;
        const maxV = Math.max.apply(null, ma.filter(function (v) { return v !== null; }).concat([600]));
        const x = function (i) { return PL + (i / Math.max(1, seq.length - 1)) * (W - PL - PR); };
        const y = function (v) { return PT + (1 - v / maxV) * (H - PT - PB); };

        let area = 'M' + x(0).toFixed(1) + ' ' + (H - PB).toFixed(1);
        seq.forEach(function (v, i) { area += ' L' + x(i).toFixed(1) + ' ' + y(v).toFixed(1); });
        area += ' L' + x(seq.length - 1).toFixed(1) + ' ' + (H - PB).toFixed(1) + ' Z';

        let line = '';
        ma.forEach(function (v, i) {
          if (v === null) return;
          line += (line ? ' L' : 'M') + x(i).toFixed(1) + ' ' + y(v).toFixed(1);
        });

        let labels = '';
        const seen = {};
        dates.forEach(function (d, i) {
          if (d.getMonth() !== 0 && i !== 0) return;
          const yr = d.getFullYear();
          if (seen[yr]) return;
          seen[yr] = 1;
          labels += '<text x="' + x(i).toFixed(1) + '" y="' + (H - 6) + '" fill="rgba(235,235,245,.32)" font-size="11" text-anchor="middle">' + yr + '</text>';
        });
        [0, maxV / 2, maxV].forEach(function (v) {
          labels += '<text x="' + (PL - 8) + '" y="' + (y(v) + 4) + '" fill="rgba(235,235,245,.28)" font-size="10" text-anchor="end">' + shortDur(v) + '</text>';
        });

        const cur = ma.filter(function (v) { return v !== null; });
        const lastV = cur.length ? cur[cur.length - 1] : 0;
        host.innerHTML = '<div class="sub2" style="font-size:12.5px;color:var(--dim);margin:-2px 0 6px">' +
          '最近 30 天日均 <b style="color:#5ac8fa">' + fmtDur(lastV) + '</b></div>' +
          '<svg viewBox="0 0 ' + W + ' ' + H + '" preserveAspectRatio="none">' +
          '<defs><linearGradient id="tg" x1="0" y1="0" x2="0" y2="1">' +
          '<stop offset="0%" stop-color="rgba(255,255,255,.13)"/><stop offset="100%" stop-color="rgba(255,255,255,0)"/>' +
          '</linearGradient></defs>' +
          '<path d="' + area + '" fill="url(#tg)"/>' +
          '<path d="' + line + '" fill="none" stroke="#5ac8fa" stroke-width="2.2" stroke-linejoin="round" stroke-linecap="round"/>' +
          labels + '</svg>';
      }

      // ---------- 音量 × 时段 ----------
      function renderHourDb(list) {
        const host = $('hourdb'), ax = $('hourdbAxis');
        const num = new Array(24).fill(0), den = new Array(24).fill(0);
        list.forEach(function (s) {
          if (!(s.db > 0)) return;
          spansOf(s).forEach(function (sp) {
            let t = sp[0];
            let guard = 0;
            while (t < sp[1] && guard++ < 400) {
              const dt = new Date(t * 1000);
              const h = dt.getHours();
              dt.setMinutes(0, 0, 0);
              const next = dt.getTime() / 1000 + 3600;
              const seg = Math.min(sp[1], next) - t;
              if (seg <= 0) break;
              num[h] += seg * s.db; den[h] += seg;
              t = Math.min(sp[1], next);
            }
          });
        });
        const vals = num.map(function (n, i) { return den[i] > 0 ? n / den[i] : 0; });
        const valid = vals.filter(function (v) { return v > 0; });
        if (!valid.length) { host.innerHTML = ''; ax.innerHTML = ''; return; }
        const lo = Math.min.apply(null, valid), hi = Math.max.apply(null, valid);
        const span = Math.max(1, hi - lo);
        host.innerHTML = vals.map(function (v, i) {
          if (v <= 0) return '<div class="b" style="height:2%;background:rgba(255,255,255,.05)"></div>';
          const t = (v - lo) / span;
          const hgt = 22 + t * 78;
          const c = v >= 78 ? '#ff453a' : v >= 70 ? '#ff9f0a' : '#5ac8fa';
          const bg = 'linear-gradient(180deg,' + c + ',rgba(255,255,255,.14))';
          return '<div class="b" title="' + pad(i) + ':00–' + pad(i + 1) + ':00　平均 ' + v.toFixed(1) + ' dB　共 ' +
            fmtDur(den[i]) + '" style="height:' + hgt.toFixed(1) + '%;background:' + bg + ';animation-delay:' + (i * 14) + 'ms"></div>';
        }).join('');
        ax.innerHTML = vals.map(function (v, i) {
          return '<span>' + (i % 3 === 0 ? i : '') + '</span>';
        }).join('');
      }

      // ---------- 作息节奏 ----------
      function lateOf(list) {
        const late = new Set();
        list.forEach(function (s2) {
          spansOf(s2).forEach(function (sp) {
            const a = new Date(sp[0] * 1000);
            const d = new Date(a.getFullYear(), a.getMonth(), a.getDate());
            let guard = 0;
            while (d.getTime() / 1000 <= sp[1] && guard++ < 8) {
              const lo = d.getTime() / 1000, hi = lo + 4 * 3600;
              if (Math.min(sp[1], hi) - Math.max(sp[0], lo) > 60) late.add(dayKey(d));
              d.setDate(d.getDate() + 1);
            }
          });
        });
        return late;
      }

      function renderClock(list, st) {
        const host = $('clock');
        const first = new Map(), last = new Map();
        list.forEach(function (s) {
          const a = new Date(s.s * 1000), b = new Date(s.e * 1000);
          const ka = dayKey(a), kb = dayKey(b);
          const ma = a.getHours() * 60 + a.getMinutes();
          const mb = b.getHours() * 60 + b.getMinutes();
          if (!first.has(ka) || ma < first.get(ka)) first.set(ka, ma);
          if (!last.has(kb) || mb > last.get(kb)) last.set(kb, mb);
        });
        const keys = Array.from(first.keys()).sort();
        if (keys.length < 10) { host.innerHTML = '<div class="empty">数据太少</div>'; return; }

        const W = 1000, H = 210, PL = 46, PR = 12, PT = 12, PB = 24;
        const LO = 4 * 60, HI = 26 * 60;  // 04:00 → 次日 02:00，跨午夜的熬夜也能画进去
        const norm = function (m) { return m < LO ? m + 1440 : m; };
        const x = function (i) { return PL + (i / Math.max(1, keys.length - 1)) * (W - PL - PR); };
        const y = function (m) { return PT + (1 - (norm(m) - LO) / (HI - LO)) * (H - PT - PB); };

        let dotsF = '', dotsL = '', mono = '', monoL = '';
        keys.forEach(function (k, i) {
          const ma = first.get(k), mb = last.get(k);
          if (ma !== undefined) dotsF += '<circle cx="' + x(i).toFixed(1) + '" cy="' + y(ma).toFixed(1) + '" r="1.5" fill="#0a84ff" opacity=".55"/>';
          if (mb !== undefined) dotsL += '<circle cx="' + x(i).toFixed(1) + '" cy="' + y(mb).toFixed(1) + '" r="1.5" fill="#bf5af2" opacity=".45"/>';
        });
        // 月度均值线
        const monF = new Map(), monL = new Map();
        keys.forEach(function (k) {
          const ym = k.slice(0, 7);
          if (!monF.has(ym)) { monF.set(ym, [0, 0]); monL.set(ym, [0, 0]); }
          const f = monF.get(ym), l = monL.get(ym);
          if (first.has(k)) { f[0] += first.get(k); f[1]++; }
          if (last.has(k)) { l[0] += last.get(k); l[1]++; }
        });
        const idxOf = {};
        keys.forEach(function (k, i) { const ym = k.slice(0, 7); if (!(ym in idxOf)) idxOf[ym] = i; });
        Object.keys(monF).sort().forEach(function (ym) {
          const f = monF.get(ym), l = monL.get(ym);
          const i = idxOf[ym];
          if (f[1]) mono += (mono ? ' L' : 'M') + x(i).toFixed(1) + ' ' + y(f[0] / f[1]).toFixed(1);
          if (l[1]) monoL += (monoL ? ' L' : 'M') + x(i).toFixed(1) + ' ' + y(l[0] / l[1]).toFixed(1);
        });

        let grid = '';
        [6, 9, 12, 15, 18, 21, 24].forEach(function (h) {
          const yy = y(h * 60);
          grid += '<line x1="' + PL + '" y1="' + yy.toFixed(1) + '" x2="' + (W - PR) + '" y2="' + yy.toFixed(1) +
            '" stroke="rgba(255,255,255,.055)" stroke-width="1"/>' +
            '<text x="' + (PL - 8) + '" y="' + (yy + 4).toFixed(1) + '" fill="rgba(235,235,245,.3)" font-size="10" text-anchor="end">' +
            pad(h % 24) + ':00</text>';
        });
        let xlab = '';
        const seenY = {};
        keys.forEach(function (k, i) {
          const yr = k.slice(0, 4);
          if (k.slice(5, 7) !== '01' || seenY[yr]) return;
          seenY[yr] = 1;
          xlab += '<text x="' + x(i).toFixed(1) + '" y="' + (H - 6) + '" fill="rgba(235,235,245,.3)" font-size="11" text-anchor="middle">' + yr + '</text>';
        });

        host.innerHTML = '<svg viewBox="0 0 ' + W + ' ' + H + '" preserveAspectRatio="none">' +
          grid + dotsL + dotsF +
          '<path d="' + monoL + '" fill="none" stroke="#bf5af2" stroke-width="2.4" stroke-linejoin="round" stroke-linecap="round" opacity=".95"/>' +
          '<path d="' + mono + '" fill="none" stroke="#0a84ff" stroke-width="2.4" stroke-linejoin="round" stroke-linecap="round" opacity=".95"/>' +
          xlab + '</svg>' +
          (function () {
            const mf = modeHour(first), ml = modeHour(last);
            const tot = Math.max(st.activeDays || 0, first.size || 1);
            const late = st.late || new Set();
            return '<div style="display:flex;gap:22px;font-size:12px;color:var(--faint);margin-top:6px;padding-left:46px;flex-wrap:wrap">' +
              '<span>最常开始于 <b style="color:#0a84ff">' + pad(mf.hour) + ':00–' + pad((mf.hour + 1) % 24) + ':00</b>' +
              '（' + mf.n + '/' + tot + ' 天）</span>' +
              '<span>最常结束于 <b style="color:#bf5af2">' + pad(ml.hour) + ':00–' + pad((ml.hour + 1) % 24) + ':00</b>' +
              '（' + ml.n + '/' + tot + ' 天）</span>' +
              '<span>凌晨 0–4 点还在戴 <b style="color:#ff9f0a">' + esc(pct(late.size / tot)) + '</b> 的天' +
              '（' + late.size + '/' + tot + ' 天）</span></div>';
          })();
      }

      function modeHour(m) {
        const c = new Array(24).fill(0);
        m.forEach(function (v) { c[Math.floor(v / 60) % 24]++; });
        let bi = 0;
        for (let i = 1; i < 24; i++) if (c[i] > c[bi]) bi = i;
        return { hour: bi, n: c[bi], total: m.size || m.length };
      }
      function medianDur(f, l) {
        const arr = [];
        f.forEach(function (v, k) {
          if (!l.has(k)) return;
          let d = (l.get(k) - v + 1440) % 1440;
          if (d <= 0) d += 1440;
          arr.push(d);
        });
        if (!arr.length) return 0;
        arr.sort(function (a, b) { return a - b; });
        return arr[Math.floor(arr.length / 2)] * 60;
      }
      function fmtClock(mins) {
        const t = ((Math.round(mins) % 1440) + 1440) % 1440;
        return pad(Math.floor(t / 60)) + ':' + pad(t % 60);
      }

      // ---------- 使用场景 ----------
      function renderScenes(list) {
        const host = $('scenes');
        const SEG = [
          { name: '早通勤', from: 5, to: 9, c: '#0a84ff' },
          { name: '上午', from: 9, to: 12, c: '#5ac8fa' },
          { name: '午休', from: 12, to: 14, c: '#30d158' },
          { name: '下午', from: 14, to: 18, c: '#64d2ff' },
          { name: '晚间', from: 18, to: 22, c: '#bf5af2' },
          { name: '深夜', from: 22, to: 5, c: '#ff9f0a' }
        ];
        const acc = SEG.map(function () { return { sec: 0, n: 0 }; });
        let total = 0;
        list.forEach(function (s) {
          const h = new Date(s.s * 1000).getHours();
          let k = 0;
          SEG.forEach(function (g, i) {
            if (g.from < g.to) { if (h >= g.from && h < g.to) k = i; }
            else if (h >= g.from || h < g.to) k = i;
          });
          acc[k].sec += s.d; acc[k].n++; total += s.d;
        });
        if (!total) { host.innerHTML = '<div class="empty">无数据</div>'; return; }
        const maxSec = Math.max.apply(null, acc.map(function (a) { return a.sec; }).concat([1]));
        host.innerHTML = SEG.map(function (g, i) {
          const a = acc[i];
          return '<div class="row" title="' + g.name + '　' + a.n + ' 次　' + fmtDur(a.sec) + '">' +
            '<div class="nm">' + g.name + '</div>' +
            '<div class="track"><i style="width:' + Math.max(a.sec > 0 ? 2 : 0, a.sec / maxSec * 100).toFixed(1) +
            '%;background:linear-gradient(90deg,' + g.c + ',rgba(255,255,255,.55));animation-delay:' + (i * 60) + 'ms"></i></div>' +
            '<div class="amt">' + fmtDur(a.sec) + ' · ' + esc(pct(a.sec / total)) + ' · ' + a.n + ' 次</div></div>';
        }).join('');
      }

      // ---------- 主流程 ----------
      function render() {
        const list = filtered();
        const st = compute(list);
        st.late = lateOf(list);
        renderHero(st, list);
        renderKpi(st);
        renderInsights(st, list);
        renderDep(st);
        renderDevices(st);
        renderSwitch(st, list);
        renderCalendar(st);
        renderGap(st);
        renderDaily(st);
        renderTrend(st);
        renderHeat(st);
        renderHourDb(list);
        renderDbTrend(st);
        renderVolume(st);
        renderClock(list, st);
        renderScenes(list);
        renderDurHist(list ? st : st, list);
        renderTable(list, st);
        // 重新触发一次出场动画
        document.querySelectorAll('.card.reveal').forEach(function (n) {
          n.classList.remove('in');
          void n.offsetWidth;
          n.classList.add('in');
        });
      }

      document.querySelectorAll('.rangebar button').forEach(function (btn) {
        btn.addEventListener('click', function () {
          document.querySelectorAll('.rangebar button').forEach(function (b) { b.classList.remove('on'); });
          btn.classList.add('on');
          RANGE = +btn.dataset.range || 0;
          document.querySelector('.wrap').style.opacity = '0.55';
          setTimeout(function () {
            render();
            document.querySelector('.wrap').style.opacity = '1';
          }, 90);
        });
      });
      document.querySelector('.wrap').style.transition = 'opacity .28s ease';

      function start() {
        observeAll();
        render();
        // 兜底：无论是否滚动，1.6 秒后所有区块都必须可见（打印、无滚动容器、IO 失效时也不会空白）
        setTimeout(function () {
          document.querySelectorAll('.reveal').forEach(function (n) { n.classList.add('in'); });
        }, 1600);
      }
      window.addEventListener('resize', function () { /* 布局自适应，无需重算 */ });

      // 供外部（网页版导入器）调用：替换数据集后重新渲染
      window.__podsstatsImport = function (list, meta) {
        S = (list && list.length) ? list : [];
        if (meta) {
          DATA.meta = meta;
        }
        if (!S.length) {
          $('metaLine').textContent = '这个文件里没有耳机音频记录。';
          return;
        }
        start();
      };
      window.__podsstatsReady = true;

      if (BOOT === 'auto') {
        if (!S.length) {
          $('metaLine').textContent = '这个文件里没有耳机音频记录。';
          return;
        }
        start();
      }
    })();
    </script>
    </body>
    </html>
    """##
}
