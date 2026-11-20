import Foundation

/// 网页版（GitHub Pages / 纯浏览器）用的引导脚本：
/// 拖入 export.zip 或 export.xml，在本机浏览器里流式解析，绝不联网、不上传。
enum WebBootScript {

    static let script = ##"""
    <script>
    (function () {
      "use strict";

      /* ============ 样式 ============ */
      const css = `
      .gate{
        position:fixed;inset:0;z-index:9999;display:flex;align-items:center;justify-content:center;
        padding:24px;backdrop-filter:blur(26px) saturate(160%);
        background:
          radial-gradient(48% 42% at 50% 22%,rgba(10,132,255,.20),transparent 70%),
          radial-gradient(40% 36% at 78% 78%,rgba(191,90,242,.14),transparent 72%),
          rgba(7,7,10,.80);
        -webkit-backdrop-filter:blur(26px) saturate(160%);
      }
      .gate.off{display:none}
      .gateBox{
        width:100%;max-width:560px;padding:38px 36px 30px;border-radius:28px;text-align:center;
        background:linear-gradient(158deg,rgba(255,255,255,.085),rgba(255,255,255,.028));
        border:1px solid rgba(255,255,255,.1);
        box-shadow:0 30px 80px -30px rgba(0,0,0,.9),inset 0 1px 0 rgba(255,255,255,.14);
        backdrop-filter:blur(30px) saturate(175%);
      }
      .gateBox h2{
        margin:0 0 10px;font-size:25px;font-weight:700;letter-spacing:-.02em;
        background:linear-gradient(180deg,#fff 20%,#9fb0c8 118%);-webkit-background-clip:text;background-clip:text;color:transparent;
      }
      .gateBox p{margin:0 0 22px;font-size:13.5px;line-height:1.7;color:rgba(235,235,245,.62)}
      .drop{
        padding:34px 20px;border-radius:20px;border:1.5px dashed rgba(255,255,255,.18);
        background:rgba(255,255,255,.026);transition:.25s ease;cursor:pointer;
      }
      .drop.hot{border-color:rgba(10,132,255,.75);background:rgba(10,132,255,.1);transform:scale(1.012)}
      .drop b{display:block;font-size:15px;color:#fff;margin-bottom:6px;font-weight:600}
      .drop span{font-size:12.5px;color:rgba(235,235,245,.5)}
      .gateBtn{
        margin-top:18px;display:inline-block;padding:11px 26px;border-radius:100px;border:none;
        font-size:14px;font-weight:600;color:#fff;cursor:pointer;
        background:linear-gradient(135deg,#0a84ff,#5e5ce6);
        box-shadow:0 10px 26px -10px rgba(10,132,255,.9);
      }
      .gateBtn:hover{filter:brightness(1.08)}
      .gateBtn.ghost{
        background:rgba(255,255,255,.07);border:1px solid rgba(255,255,255,.14);
        box-shadow:none;margin-left:10px;
      }
      .gateBtn.ghost:hover{background:rgba(255,255,255,.12)}
      .gateNote{margin-top:20px;font-size:11.5px;line-height:1.7;color:rgba(235,235,245,.38)}
      .pgWrap{margin-top:6px}
      .pgBar{height:6px;border-radius:3px;background:rgba(255,255,255,.08);overflow:hidden}
      .pgBar i{display:block;height:100%;width:0;border-radius:3px;background:linear-gradient(90deg,#0a84ff,#5ac8fa);transition:width .2s ease}
      .pgTxt{margin-top:12px;font-size:12.5px;color:rgba(235,235,245,.6);font-variant-numeric:tabular-nums}
      .gateErr{margin-top:14px;font-size:12.5px;color:#ff453a;line-height:1.6}
      `;
      const st = document.createElement('style');
      st.textContent = css;
      document.head.appendChild(st);

      /* ============ 引导层 ============ */
      const wrap = document.querySelector('.wrap');
      const gate = document.createElement('div');
      gate.className = 'gate';
      gate.innerHTML =
        '<div class="gateBox">' +
          '<h2>把健康数据拖进来</h2>' +
          '<p>iPhone 上打开「健康」→ 右上角头像 → 拉到最底「导出所有健康数据」，' +
            '把生成的 <b>export.zip</b> 拖到这里（或直接选 export.xml）。</p>' +
          '<div class="drop" id="drop"><b>拖放 export.zip 到这里</b><span>也可以点击选择文件</span></div>' +
          '<button class="gateBtn" id="pick">选择文件</button>' +
          '<button class="gateBtn ghost" id="demo">先看个示例</button>' +
          '<div class="pgWrap" id="pgWrap" style="display:none">' +
            '<div class="pgBar"><i id="pgBar"></i></div>' +
            '<div class="pgTxt" id="pgTxt">准备中…</div>' +
          '</div>' +
          '<div class="gateErr" id="gateErr"></div>' +
          '<div class="gateNote">文件只在这个浏览器里解析，不会上传到任何服务器 · ' +
            '解析完成前请不要关闭页面</div>' +
        '</div>';
      document.body.appendChild(gate);
      if (wrap) wrap.style.display = 'none';

      const $g = function (id) { return document.getElementById(id); };
      const fileInput = document.createElement('input');
      fileInput.type = 'file';
      fileInput.accept = '.zip,.xml,application/zip,text/xml';
      fileInput.style.display = 'none';
      document.body.appendChild(fileInput);

      $g('demo').addEventListener('click', function () {
        const list = demoRun();
        gate.classList.add('off');
        if (wrap) wrap.style.display = '';
        window.__podsstatsImport(list, {
          file: '示例数据（非真实记录）', generated: new Date().toISOString(), gap: GAP, note: 'demo'
        });
      });
      $g('pick').addEventListener('click', function () { fileInput.click(); });
      $g('drop').addEventListener('click', function () { fileInput.click(); });
      fileInput.addEventListener('change', function () {
        if (fileInput.files && fileInput.files[0]) run(fileInput.files[0]);
      });
      ['dragenter', 'dragover'].forEach(function (e) {
        gate.addEventListener(e, function (ev) { ev.preventDefault(); $g('drop').classList.add('hot'); });
      });
      ['dragleave', 'drop'].forEach(function (e) {
        gate.addEventListener(e, function (ev) { ev.preventDefault(); if (e === 'dragleave' || ev.target === gate) $g('drop').classList.remove('hot'); });
      });
      gate.addEventListener('drop', function (ev) {
        ev.preventDefault();
        $g('drop').classList.remove('hot');
        const f = ev.dataTransfer && ev.dataTransfer.files && ev.dataTransfer.files[0];
        if (f) run(f);
      });

      /* ============ 示例数据（确定性生成，用于快速预览） ============ */
      function demoRun() {
        const now = new Date();
        const end0 = Math.floor(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()) / 1000);
        let seed = 20261120;
        const rnd = function () {
          seed ^= seed << 13; seed >>= 0;
          seed ^= seed >> 17;
          seed ^= seed << 5; seed >>= 0;
          return (seed % 100000) / 100000;
        };
        const out = [];
        const devices = ['AirPods Pro', 'AirPods Pro', 'AirPods Pro', 'AirPods 4 (ANC)', 'WH-1000XM5'];
        for (let d = 69; d >= 0; d--) {
          const dayBase = end0 - d * 86400;
          const wk = new Date(dayBase * 1000).getUTCDay();
          const slots = [[8, 9.4], [12.4, 13.2], [14, 18], [19.6, 23.4]];
          const miss = rnd() < 0.12;
          if (miss) continue;
          for (let k = 0; k < slots.length; k++) {
            if (rnd() < 0.24) continue;
            const a = dayBase + Math.floor(slots[k][0] * 3600 + rnd() * 900);
            const len = Math.floor((slots[k][1] - slots[k][0]) * 3600 * (0.35 + rnd() * 0.6));
            const db = 52 + rnd() * 30 + (wk === 0 || wk === 6 ? 2 : 0);
            const g = [];
            let t = a;
            const b = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
            let loud = 0, vl = 0, mx = 0, n = 0;
            while (t < a + len) {
              const seg = 60 + Math.floor(rnd() * 120);
              const e = Math.min(a + len, t + seg);
              if (rnd() > 0.1) {
                g.push([t, e]);
                const w = e - t;
                const v = Math.min(98, Math.max(38, db + (rnd() - 0.5) * 12));
                let bi = Math.floor((v - 40) / 5); if (bi < 0) bi = 0; if (bi > 11) bi = 11;
                b[bi] += w;
                if (v >= 80) loud += w;
                if (v >= 90) vl += w;
                if (v > mx) mx = v;
                n++;
              }
              t = e + Math.floor(rnd() * 40);
            }
            if (!g.length) continue;
            let dur = 0;
            for (let i = 0; i < g.length; i++) dur += g[i][1] - g[i][0];
            out.push({
              s: g[0][0], e: g[g.length - 1][1], d: Math.round(dur),
              db: Math.round(db * 10) / 10, mx: Math.round(mx * 10) / 10,
              loud: Math.round(loud), vl: Math.round(vl),
              src: devices[Math.floor(rnd() * devices.length)],
              n: n, b: b, g: g
            });
          }
        }
        return out;
      }

      /* ============ 小工具 ============ */
      const GAP = 300;                // 相邻样本间隔 ≤ 5 分钟算同一次佩戴
      const MAX_SAMPLE = 4 * 3600;    // 单条样本最多按 4 小时算
      const SPLIT = 12 * 3600;        // 超过 12 小时的会话均分

      function pickStr(line, key) {
        const t = ' ' + key + '="';
        const i = line.indexOf(t);
        if (i < 0) return null;
        const a = i + t.length;
        const b = line.indexOf('"', a);
        if (b < 0) return null;
        return line.slice(a, b);
      }

      function parseTime(s) {
        if (!s || s.length < 19) return 0;
        const c = function (i) { return s.charCodeAt(i) - 48; };
        if (c(4) !== -3) { /* '-' */ }
        const y = c(0) * 1000 + c(1) * 100 + c(2) * 10 + c(3);
        const mo = c(5) * 10 + c(6);
        const d = c(8) * 10 + c(9);
        const h = c(11) * 10 + c(12);
        const mi = c(14) * 10 + c(15);
        const se = c(17) * 10 + c(18);
        let off = 0;
        if (s.length >= 25) {
          const sign = s.charCodeAt(20) === 45 ? -1 : 1;
          const hh = c(21) * 10 + c(22);
          const mm = c(23) * 10 + c(24);
          off = sign * (hh * 3600 + mm * 60);
        }
        return Math.floor((Date.UTC(y, mo - 1, d, h, mi, se) - off * 1000) / 1000);
      }

      function devName(line) {
        const i = line.indexOf('name:');
        if (i < 0 || line.indexOf('device="') < 0) return null;
        const j = line.indexOf(',', i);
        if (j < 0) return null;
        let nm = line.slice(i + 5, j).trim();
        nm = nm.replace(/&gt;+$/, '').trim();
        if (!nm) return null;
        if (/iPhone|iPad|Apple Watch|Mac\b|健康|Health|iPod/i.test(nm)) return null;
        return nm;
      }

      /* ============ zip 读取 ============ */
      async function findExportEntry(file) {
        const size = file.size;
        const tailLen = Math.min(size, 66000);
        const tailBuf = await file.slice(size - tailLen).arrayBuffer();
        const tail = new Uint8Array(tailBuf);
        const tv = new DataView(tailBuf);
        let eocd = -1;
        for (let i = tail.length - 22; i >= 0; i--) {
          if (tail[i] === 0x50 && tail[i + 1] === 0x4b && tail[i + 2] === 0x05 && tail[i + 3] === 0x06) { eocd = i; break; }
        }
        if (eocd < 0) return null;
        const cnt = tv.getUint16(eocd + 10, true);
        const cdSize = tv.getUint32(eocd + 12, true);
        const cdOff = tv.getUint32(eocd + 16, true);
        if (!cnt || !cdSize) return null;
        const cdBuf = await file.slice(cdOff, cdOff + cdSize).arrayBuffer();
        const cd = new Uint8Array(cdBuf);
        const cv = new DataView(cdBuf);
        let p = 0;
        for (let i = 0; i < cnt; i++) {
          if (cv.getUint32(p, true) !== 0x02014b50) break;
          const method = cv.getUint16(p + 10, true);
          const csize = cv.getUint32(p + 20, true);
          const usize = cv.getUint32(p + 24, true);
          const nlen = cv.getUint16(p + 28, true);
          const elen = cv.getUint16(p + 30, true);
          const clen = cv.getUint16(p + 32, true);
          const lho = cv.getUint32(p + 42, true);
          const name = new TextDecoder().decode(cd.subarray(p + 46, p + 46 + nlen));
          if (/export\.xml$/i.test(name) && !/cda/i.test(name)) {
            const lhBuf = await file.slice(lho, lho + 30).arrayBuffer();
            const lv = new DataView(lhBuf);
            const dataStart = lho + 30 + lv.getUint16(26, true) + lv.getUint16(28, true);
            return { name: name, method: method, dataStart: dataStart, csize: csize, usize: usize };
          }
          p += 46 + nlen + elen + clen;
        }
        return null;
      }

      /* ============ 解析 export.xml ============ */
      async function scanXml(readable, totalBytes, onProgress) {
        const reader = readable.getReader();
        const dec = new TextDecoder('utf-8');
        const samples = [];
        let carry = '';
        let read = 0;
        let scanned = 0;
        let lastTick = 0;

        function eat(text) {
          const lines = text.split('\n');
          for (let i = 0; i < lines.length; i++) {
            const ln = lines[i];
            if (ln.indexOf('HeadphoneAudioExposure') < 0) continue;
            if (ln.indexOf('HKQuantityTypeIdentifierHeadphoneAudioExposure"') < 0) continue;
            const v = pickStr(ln, 'value');
            const sd = pickStr(ln, 'startDate');
            if (!v || !sd) continue;
            scanned++;
            const t = parseTime(sd);
            if (!t) continue;
            const ed = pickStr(ln, 'endDate');
            let e = ed ? parseTime(ed) : t + 60;
            if (!(e > t)) e = t + 60;
            if (e - t > MAX_SAMPLE) e = t + MAX_SAMPLE;
            const db = parseFloat(v);
            samples.push({
              t: t,
              e: e,
              db: (db > 0 && db < 200) ? db : 0,
              src: devName(ln) || pickStr(ln, 'sourceName') || ''
            });
          }
        }

        for (;;) {
          const r = await reader.read();
          if (r.done) break;
          const chunk = r.value;
          read += chunk.length;
          let text = carry + dec.decode(chunk, { stream: true });
          const cut = text.lastIndexOf('\n');
          if (cut >= 0) { carry = text.slice(cut + 1); text = text.slice(0, cut); }
          else { carry = text; text = ''; }
          if (text) eat(text);
          const now = Date.now();
          if (now - lastTick > 60) {
            lastTick = now;
            onProgress(Math.min(0.99, read / Math.max(1, totalBytes)), scanned);
            await new Promise(function (r2) { setTimeout(r2, 0); });
          }
        }
        if (carry) eat(carry);
        return { samples: samples, scanned: scanned };
      }

      /* ============ 切成「一次佩戴」 ============ */
      function buildSessions(samples) {
        samples.sort(function (a, b) { return a.t - b.t; });
        const out = [];
        let cur = null;

        function bucket(db) {
          let i = Math.floor((db - 40) / 5);
          if (i < 0) i = 0;
          if (i > 11) i = 11;
          return i;
        }

        function absorb(c, s) {
          const w = Math.max(1, s.e - s.t);
          c.n++;
          if (s.db > 0) {
            c.dbw += s.db * w;
            c.dbws += w;
            if (s.db > c.mx) c.mx = s.db;
            c.b[bucket(s.db)] += w;
            if (s.db >= 80) c.loud += w;
            if (s.db >= 90) c.vl += w;
          }
          if (s.src) c.srcs[s.src] = (c.srcs[s.src] || 0) + w;
          if (s.e > c.end) c.end = s.e;
          const last = c.spans[c.spans.length - 1];
          if (s.t - last[1] <= 1) { if (s.e > last[1]) last[1] = s.e; }
          else c.spans.push([s.t, s.e]);
        }

        for (let i = 0; i < samples.length; i++) {
          const s = samples[i];
          if (cur && s.t - cur.end <= GAP) {
            absorb(cur, s);
          } else {
            cur = {
              start: s.t, end: s.e, n: 0, dbw: 0, dbws: 0, mx: 0, loud: 0, vl: 0,
              b: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
              spans: [[s.t, s.e]], srcs: {}
            };
            absorb(cur, s);
            out.push(cur);
          }
        }

        function spanDur(spans) {
          let d = 0;
          for (let i = 0; i < spans.length; i++) d += Math.max(0, spans[i][1] - spans[i][0]);
          return d;
        }

        function topSrc(srcs) {
          let best = '', bv = -1;
          for (const k in srcs) { if (srcs[k] > bv) { bv = srcs[k]; best = k; } }
          return best;
        }

        const res = [];
        for (let i = 0; i < out.length; i++) {
          const c = out[i];
          const d = spanDur(c.spans);
          if (d < 1) continue;
          const base = {
            db: c.dbws > 0 ? Math.round(c.dbw / c.dbws * 10) / 10 : 0,
            mx: Math.round(c.mx * 10) / 10,
            loud: Math.round(c.loud),
            vl: Math.round(c.vl),
            src: topSrc(c.srcs),
            n: c.n,
            b: c.b.map(function (x) { return Math.round(x); })
          };
          if (d > SPLIT) {
            const parts = Math.ceil(d / SPLIT);
            const step = Math.floor((c.end - c.start) / parts);
            for (let k = 0; k < parts; k++) {
              const a = c.start + k * step;
              const b2 = (k === parts - 1) ? c.end : a + step;
              const sub = { s: a, e: b2, d: Math.round(d / parts), g: [] };
              c.spans.forEach(function (sp) {
                const x1 = Math.max(sp[0], a), x2 = Math.min(sp[1], b2);
                if (x2 > x1) sub.g.push([x1, x2]);
              });
              if (!sub.g.length) sub.g = [[a, b2]];
              res.push(Object.assign(sub, base));
            }
          } else {
            res.push(Object.assign({ s: c.start, e: c.end, d: Math.round(d), g: c.spans }, base));
          }
        }
        return res;
      }

      /* ============ 主流程 ============ */
      let busy = false;
      async function run(file) {
        if (busy) return;
        busy = true;
        const err = $g('gateErr');
        const pg = $g('pgWrap');
        const bar = $g('pgBar');
        const txt = $g('pgTxt');
        err.textContent = '';
        pg.style.display = '';
        const setPg = function (r, label) {
          bar.style.width = Math.max(1, Math.round(r * 100)) + '%';
          txt.textContent = label;
        };

        try {
          const isZip = /\.zip$/i.test(file.name) || file.type === 'application/zip';
          let readable = null;
          let totalBytes = file.size;
          let entry = null;

          if (isZip) {
            setPg(0.02, '正在读取压缩包目录…');
            entry = await findExportEntry(file);
            if (!entry) throw new Error('这个 zip 里没找到 export.xml。请确认是从「健康」App 导出的完整压缩包。');
            totalBytes = entry.usize || entry.csize * 4;
            const blob = file.slice(entry.dataStart, entry.dataStart + entry.csize);
            if (entry.method === 0) {
              readable = blob.stream();
            } else if (entry.method === 8) {
              if (typeof DecompressionStream === 'undefined') {
                throw new Error('当前浏览器不支持流式解压，请换用新版 Chrome / Edge / Safari 16.4+，或直接把 export.xml 选进来。');
              }
              readable = blob.stream().pipeThrough(new DecompressionStream('deflate-raw'));
            } else {
              throw new Error('这个压缩包用了不支持的压缩方式（method=' + entry.method + '）。');
            }
          } else {
            readable = file.stream();
          }

          setPg(0.05, '正在解析 export.xml（约 ' + (totalBytes / 1048576).toFixed(0) + ' MB）…');
          const parsed = await scanXml(readable, totalBytes, function (r, hit) {
            setPg(0.05 + r * 0.85, '解析中 ' + Math.round(5 + r * 85) + '% · 已找到 ' + (hit || 0).toLocaleString() + ' 条耳机记录');
          });

          if (!parsed.samples.length) {
            throw new Error('这个文件里没有任何耳机音量记录。可能耳机没连过这台设备，或者导出时没勾选「健康记录」。');
          }

          setPg(0.93, '正在切成佩戴会话（' + parsed.samples.length.toLocaleString() + ' 条样本）…');
          await new Promise(function (r) { setTimeout(r, 16); });
          const sessions = buildSessions(parsed.samples);

          if (!sessions.length) throw new Error('解析出了样本，但没能切成有效会话。');

          setPg(1, '完成 · ' + sessions.length.toLocaleString() + ' 次佩戴');

          const meta = {
            file: file.name + ' › ' + (entry ? entry.name : file.name),
            generated: new Date().toISOString(),
            gap: GAP,
            note: '浏览器本地解析'
          };
          if (!window.__podsstatsReady) {
            throw new Error('渲染引擎还没加载完，请刷新页面重试。');
          }
          gate.classList.add('off');
          if (wrap) wrap.style.display = '';
          window.__podsstatsImport(sessions, meta);
        } catch (e) {
          err.textContent = '出错了：' + (e && e.message ? e.message : e);
          pg.style.display = 'none';
          busy = false;
        }
      }

      window.__podsstatsWebRun = run;
    })();
    </script>
    """##
}
