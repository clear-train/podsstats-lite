import Foundation

/// HTML 报告的静态结构（HTML + CSS）。与 HTMLReportScript 中的脚本拼接成整页。
enum HTMLReportMarkup {

    static let head = ##"""
    <!DOCTYPE html>
    <html lang="zh-CN">
    <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <title>耳机使用统计</title>
    <style>
    :root{
      --bg:#07070a;
      --text:#f5f5f7;
      --dim:rgba(235,235,245,.58);
      --faint:rgba(235,235,245,.34);
      --stroke:rgba(255,255,255,.085);
      --stroke2:rgba(255,255,255,.16);
      --blue:#0a84ff;
      --cyan:#5ac8fa;
      --green:#30d158;
      --orange:#ff9f0a;
      --red:#ff453a;
      --purple:#bf5af2;
      --glass:linear-gradient(158deg,rgba(255,255,255,.082),rgba(255,255,255,.026));
    }
    *{box-sizing:border-box;-webkit-font-smoothing:antialiased;text-rendering:optimizeLegibility}
    html,body{margin:0;padding:0}
    body{
      background:var(--bg);
      color:var(--text);
      font-family:-apple-system,BlinkMacSystemFont,"SF Pro Display","SF Pro Text","PingFang SC","Hiragino Sans GB","Helvetica Neue",sans-serif;
      font-size:15px;line-height:1.55;
      letter-spacing:-.006em;
      overflow-x:hidden;
      min-height:100vh;
      position:relative;
    }
    /* 背景光晕 */
    body::before{
      content:'';position:fixed;inset:-30%;z-index:-2;pointer-events:none;
      background:
        radial-gradient(42% 38% at 14% 6%,rgba(10,132,255,.34),transparent 62%),
        radial-gradient(38% 34% at 86% 10%,rgba(191,90,242,.26),transparent 62%),
        radial-gradient(46% 40% at 52% 96%,rgba(48,209,88,.14),transparent 66%),
        radial-gradient(30% 26% at 78% 62%,rgba(90,200,250,.12),transparent 70%);
      filter:blur(18px);
    }
    /* 细颗粒，压住渐变的塑料感 */
    body::after{
      content:'';position:fixed;inset:0;z-index:-1;pointer-events:none;opacity:.028;
      background-image:url("data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' width='180' height='180'><filter id='n'><feTurbulence type='fractalNoise' baseFrequency='.85' numOctaves='3'/></filter><rect width='180' height='180' filter='url(%23n)'/></svg>");
    }
    .wrap{max-width:1120px;margin:0 auto;padding:64px 28px 96px}

    /* ---------- 玻璃与动效 ---------- */
    .glass{
      position:relative;
      background:var(--glass);
      border:1px solid var(--stroke);
      border-radius:24px;
      backdrop-filter:blur(30px) saturate(175%);
      -webkit-backdrop-filter:blur(30px) saturate(175%);
      box-shadow:0 24px 60px -28px rgba(0,0,0,.85),inset 0 1px 0 rgba(255,255,255,.13);
      transition:transform .5s cubic-bezier(.16,1,.3,1),border-color .4s ease,box-shadow .5s ease;
      will-change:transform;
    }
    .glass::before{
      content:'';position:absolute;inset:0;border-radius:inherit;pointer-events:none;
      background:linear-gradient(180deg,rgba(255,255,255,.105),transparent 42%);
      opacity:.55;transition:opacity .4s ease;
    }
    .glass:hover{transform:translateY(-3px);border-color:var(--stroke2);box-shadow:0 34px 72px -28px rgba(0,0,0,.9),inset 0 1px 0 rgba(255,255,255,.18)}
    .glass:hover::before{opacity:.8}

    @keyframes rise{from{opacity:0;transform:translateY(26px) scale(.986)}to{opacity:1;transform:translateY(0) scale(1)}}
    @keyframes fadeIn{from{opacity:0}to{opacity:1}}
    @keyframes growY{from{transform:scaleY(0)}to{transform:scaleY(1)}}
    @keyframes growX{from{transform:scaleX(0)}to{transform:scaleX(1)}}
    @keyframes pop{from{opacity:0;transform:scale(.55)}to{opacity:1;transform:scale(1)}}
    @keyframes sweep{from{transform:translateX(-120%)}to{transform:translateX(320%)}}
    @keyframes floatY{0%,100%{transform:translateY(0)}50%{transform:translateY(-9px)}}

    .reveal{opacity:0}
    .reveal.in{animation:rise .85s cubic-bezier(.16,1,.3,1) forwards}

    /* ---------- Hero ---------- */
    header.hero{padding:8px 4px 34px}
    .badge{
      display:inline-flex;align-items:center;gap:7px;
      font-size:12px;font-weight:500;letter-spacing:.02em;color:var(--dim);
      padding:6px 13px;border-radius:100px;
      background:rgba(255,255,255,.055);border:1px solid var(--stroke);
      backdrop-filter:blur(18px);-webkit-backdrop-filter:blur(18px);
    }
    .badge i{width:6px;height:6px;border-radius:50%;background:var(--green);box-shadow:0 0 10px var(--green);animation:floatY 3.2s ease-in-out infinite}
    h1{
      font-size:clamp(34px,5.2vw,54px);line-height:1.06;font-weight:700;letter-spacing:-.03em;
      margin:20px 0 12px;
      background:linear-gradient(180deg,#ffffff 20%,#9fb0c8 118%);
      -webkit-background-clip:text;background-clip:text;color:transparent;
    }
    .sub{color:var(--dim);font-size:14px;margin:0;max-width:660px}
    .heroNums{display:flex;gap:14px;margin-top:34px;flex-wrap:wrap}
    .heroNum{
      flex:1 1 200px;padding:22px 24px 20px;border-radius:22px;
      background:var(--glass);border:1px solid var(--stroke);
      backdrop-filter:blur(30px) saturate(175%);-webkit-backdrop-filter:blur(30px) saturate(175%);
      box-shadow:0 20px 46px -24px rgba(0,0,0,.8),inset 0 1px 0 rgba(255,255,255,.12);
      position:relative;overflow:hidden;
    }
    .heroNum::after{
      content:'';position:absolute;top:0;left:0;width:44%;height:100%;
      background:linear-gradient(100deg,transparent,rgba(255,255,255,.09),transparent);
      animation:sweep 5.5s ease-in-out infinite;pointer-events:none;
    }
    .heroNum .big{
      display:inline;font-size:clamp(30px,3.6vw,44px);font-weight:600;letter-spacing:-.028em;
      font-variant-numeric:tabular-nums;
      background:linear-gradient(180deg,#fff,#aab8cc);-webkit-background-clip:text;background-clip:text;color:transparent;
    }
    .heroNum .unit{font-size:15px;font-weight:500;color:var(--dim);margin-left:5px}
    .heroNum .lab{display:block;font-size:12.5px;color:var(--faint);margin-top:7px;letter-spacing:.03em}

    /* ---------- 范围切换 ---------- */
    .rangebar{
      display:inline-flex;gap:3px;padding:4px;border-radius:100px;margin:34px 0 24px;
      background:rgba(255,255,255,.085);border:1px solid rgba(255,255,255,.14);
      box-shadow:0 12px 30px -18px rgba(0,0,0,.9);
      backdrop-filter:blur(24px) saturate(160%);-webkit-backdrop-filter:blur(24px) saturate(160%);
    }
    .rangebar button{
      appearance:none;border:0;background:transparent;color:rgba(235,235,245,.72);
      font:inherit;font-size:13.5px;font-weight:500;padding:8px 20px;border-radius:100px;
      cursor:pointer;transition:color .3s ease,background .38s cubic-bezier(.16,1,.3,1),transform .38s cubic-bezier(.16,1,.3,1);
    }
    .rangebar button:hover{color:var(--text)}
    .rangebar button.on{
      color:#fff;background:rgba(255,255,255,.2);
      box-shadow:0 6px 18px -8px rgba(0,0,0,.9),inset 0 1px 0 rgba(255,255,255,.3);
    }

    /* ---------- KPI ---------- */
    .kpis{display:grid;grid-template-columns:repeat(3,1fr);gap:14px;margin-bottom:20px}
    .kpi{padding:20px 22px 18px;border-radius:20px;position:relative;overflow:hidden}
    .kpi .k{font-size:12.5px;color:var(--faint);letter-spacing:.03em;margin-bottom:9px;display:block}
    .kpi .v{
      font-size:27px;font-weight:600;letter-spacing:-.025em;font-variant-numeric:tabular-nums;
      background:linear-gradient(180deg,#fff,#b9c6d9);-webkit-background-clip:text;background-clip:text;color:transparent;
    }
    .kpi .v.warn{background:linear-gradient(180deg,#ffd8a8,#ff9f0a);-webkit-background-clip:text;background-clip:text}
    .kpi .v.bad{background:linear-gradient(180deg,#ffb3ae,#ff453a);-webkit-background-clip:text;background-clip:text}
    .kpi .s{font-size:12px;color:var(--faint);margin-top:7px;display:block}
    .kpi .bar{height:3px;border-radius:3px;margin-top:13px;background:rgba(255,255,255,.09);overflow:hidden}
    .kpi .bar>i{display:block;height:100%;border-radius:3px;background:linear-gradient(90deg,var(--blue),var(--cyan));transform-origin:left;animation:growX 1.1s cubic-bezier(.16,1,.3,1) both}

    /* ---------- 卡片通用 ---------- */
    .card{padding:26px 28px 28px;margin-bottom:18px}
    .card h2{font-size:16px;font-weight:600;letter-spacing:-.01em;margin:0 0 4px}
    .card .hint{font-size:12.5px;color:var(--faint);margin:0 0 20px}
    .card .hint b{color:var(--dim);font-weight:500}

    /* ---------- 结论 ---------- */
    #insights{list-style:none;margin:14px 0 0;padding:0}
    #insights li{
      position:relative;padding:11px 0 11px 24px;font-size:14px;color:rgba(245,245,247,.9);
      border-top:1px solid rgba(255,255,255,.055);
      opacity:0;animation:rise .6s cubic-bezier(.16,1,.3,1) forwards;
    }
    #insights li:first-child{border-top:0}
    #insights li::before{
      content:'';position:absolute;left:4px;top:19px;width:7px;height:7px;border-radius:50%;
      background:linear-gradient(135deg,var(--cyan),var(--blue));box-shadow:0 0 12px rgba(90,200,250,.65);
    }
    #insights li em{font-style:normal;color:#fff;font-weight:600}
    #insights li.hot::before{background:linear-gradient(135deg,#ffd166,var(--orange));box-shadow:0 0 14px rgba(255,159,10,.7)}

    /* ---------- 设备编年史 ---------- */
    #devices{display:flex;flex-direction:column;gap:9px;margin-top:6px}
    .dev{display:grid;grid-template-columns:156px 1fr 120px;align-items:center;gap:16px;
      padding:9px 4px;border-radius:12px;transition:background .35s ease}
    .dev:hover{background:rgba(255,255,255,.045)}
    .dev .nm{font-size:13px;color:var(--text);white-space:nowrap;overflow:hidden;text-overflow:ellipsis;display:flex;align-items:center;gap:7px}
    .dev .nm i{width:7px;height:7px;border-radius:50%;flex:0 0 auto;background:var(--blue);box-shadow:0 0 9px currentColor}
    .dev .track{position:relative;height:9px;border-radius:6px;background:rgba(255,255,255,.055);overflow:hidden}
    .dev .track>i{
      position:absolute;top:0;bottom:0;border-radius:6px;
      background:linear-gradient(90deg,var(--blue),var(--cyan));
      transform-origin:left;animation:growX 1.05s cubic-bezier(.16,1,.3,1) both;
    }
    .dev .amt{font-size:12.5px;color:var(--dim);text-align:right;font-variant-numeric:tabular-nums;white-space:nowrap}
    .dev .span{display:block;font-size:10.5px;color:var(--faint);margin-top:2px;letter-spacing:.01em}

    /* ---------- 日历 ---------- */
    #cal{display:flex;flex-direction:column;gap:18px;margin-top:6px;overflow-x:auto;padding-bottom:4px}
    .calYear{display:flex;flex-direction:column;gap:7px;align-items:center}
    .calYear .ylab{font-size:12px;color:var(--faint);letter-spacing:.05em}
    .calGrid{display:grid;grid-auto-flow:column;grid-template-rows:repeat(7,1fr);gap:3px;width:max-content;
      filter:drop-shadow(0 0 18px rgba(10,132,255,.12))}
    .calGrid i{
      width:11px;height:11px;border-radius:3px;display:block;
      opacity:0;animation:pop .45s cubic-bezier(.16,1,.3,1) forwards;
    }

    /* ---------- 柱状 ---------- */
    .bars{display:flex;align-items:flex-end;gap:1px;height:186px;margin-top:8px;padding:0 1px}
    .bars .bar{
      flex:1;min-width:1px;border-radius:3px 3px 1px 1px;
      background:linear-gradient(180deg,var(--cyan),rgba(10,132,255,.62));
      transform-origin:bottom;animation:growY .85s cubic-bezier(.16,1,.3,1) both;
      transition:filter .25s ease,opacity .25s ease;cursor:default;
    }
    .bars .bar.weekend{background:linear-gradient(180deg,rgba(191,90,242,.9),rgba(120,60,200,.55))}
    .bars .bar:hover{filter:brightness(1.55)}
    .bars .bar.zero{background:rgba(255,255,255,.075)}
    .axis{display:grid;gap:1px;margin-top:9px;font-size:11px;color:var(--faint)}
    .axis span{white-space:nowrap;overflow:visible;min-width:0;text-align:center}

    /* ---------- 热力 ---------- */
    .heat{margin-top:6px}
    .heat .row{display:grid;grid-template-columns:34px repeat(24,minmax(0,1fr));gap:3px;margin-bottom:3px;align-items:center}
    .heat .row .lab{font-size:11px;color:var(--faint);text-align:right;padding-right:5px}
    .heat .cell{
      aspect-ratio:1/.62;border-radius:4px;background:rgba(255,255,255,.055);
      opacity:0;animation:pop .5s cubic-bezier(.16,1,.3,1) forwards;
      transition:transform .25s ease,filter .25s ease;
    }
    .heat .cell:hover{transform:scale(1.22);filter:brightness(1.4);z-index:2}
    .heat .hrow{display:grid;grid-template-columns:34px repeat(24,minmax(0,1fr));gap:3px;margin-bottom:5px}
    .heat .hrow span{font-size:10px;color:var(--faint);text-align:center}

    /* ---------- 折线 ---------- */
    #dbtrend{position:relative;height:180px;margin-top:10px}
    #dbtrend svg{width:100%;height:100%;overflow:visible}
    #dbtrend .dot{transition:r .25s ease,filter .25s ease}
    #dbtrend .dot:hover{r:6;filter:brightness(1.5)}

    /* ---------- 分布条 ---------- */
    .dist{display:flex;flex-direction:column;gap:7px;margin-top:8px}
    .dist .line{display:grid;grid-template-columns:104px 1fr 96px;gap:14px;align-items:center;font-size:12.5px}
    .dist .line .l{color:var(--dim);text-align:right;font-variant-numeric:tabular-nums}
    .dist .line .t{height:15px;border-radius:7px;background:rgba(255,255,255,.055);overflow:hidden;position:relative}
    .dist .line .t>i{
      display:block;height:100%;border-radius:7px;transform-origin:left;
      background:linear-gradient(90deg,rgba(90,200,250,.85),var(--blue));
      animation:growX .95s cubic-bezier(.16,1,.3,1) both;
    }
    .dist .line .t>i.hot{background:linear-gradient(90deg,#ffb454,var(--orange))}
    .dist .line .t>i.bad{background:linear-gradient(90deg,#ff8b7f,var(--red))}
    .dist .line .v{color:var(--faint);font-variant-numeric:tabular-nums;font-size:12px}

    /* ---------- 表格 ---------- */
    table{width:100%;border-collapse:collapse;font-size:13px;margin-top:8px}
    thead th{
      text-align:left;font-weight:500;font-size:11.5px;color:var(--faint);letter-spacing:.05em;
      padding:0 12px 10px 0;border-bottom:1px solid rgba(255,255,255,.075)
    }
    thead th.num{text-align:right}
    tbody td{padding:9px 12px 9px 0;border-bottom:1px solid rgba(255,255,255,.038);color:rgba(245,245,247,.86)}
    tbody td.num{text-align:right;font-variant-numeric:tabular-nums}
    tbody tr{transition:background .3s ease}
    tbody tr:hover{background:rgba(255,255,255,.04)}
    td.muted{color:var(--faint);font-size:12px}
    td.hot{color:#ff8b7f}
    .empty{color:var(--faint);font-size:13px;padding:16px 0}

    footer{text-align:center;color:var(--faint);font-size:12px;margin-top:44px;line-height:1.9}
    footer b{color:var(--dim);font-weight:500}

    /* ---------- 依赖度 ---------- */
    .dep{
      display:flex;align-items:center;gap:20px;flex-wrap:wrap;
      margin:-4px 0 20px;padding:16px 22px;border-radius:20px;
      background:rgba(255,255,255,.032);border:1px solid var(--stroke);
    }
    .dep .k{font-size:12.5px;color:var(--dim);letter-spacing:.02em}
    .dep .v{font-size:27px;font-weight:700;letter-spacing:-.02em;font-variant-numeric:tabular-nums}
    .dep .v small{font-size:12.5px;font-weight:500;color:var(--dim);margin-left:7px;letter-spacing:0}
    .dep .scale{flex:1;min-width:240px;height:6px;border-radius:3px;position:relative;
      background:linear-gradient(90deg,rgba(48,209,88,.5),rgba(10,132,255,.5) 38%,rgba(255,159,10,.55) 72%,rgba(255,69,58,.6))}
    .dep .scale i{position:absolute;top:-5px;width:2px;height:16px;border-radius:1px;background:#fff;
      box-shadow:0 0 10px rgba(255,255,255,.85);transition:left .55s cubic-bezier(.16,1,.3,1)}
    .dep .note{font-size:12.5px;color:var(--faint);flex-basis:100%}

    /* ---------- 换机对比 ---------- */
    .switch{display:flex;flex-direction:column;gap:9px}
    .switch .row{display:grid;grid-template-columns:150px 1fr 74px;gap:14px;align-items:center;
      padding:11px 15px;border-radius:14px;background:rgba(255,255,255,.028);
      font-size:13px;transition:background .3s ease}
    .switch .row:hover{background:rgba(255,255,255,.055)}
    .switch .nm{font-weight:600;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
    .switch .pair{display:flex;align-items:center;gap:10px;font-size:12.5px;color:var(--dim);
      font-variant-numeric:tabular-nums;flex-wrap:wrap}
    .switch .pair b{color:var(--text);font-weight:600}
    .switch .pair .arw{color:var(--faint);font-size:11px}
    .switch .chg{text-align:right;font-weight:700;font-variant-numeric:tabular-nums;font-size:13px}
    .switch .chg.up{color:#5ac8fa}
    .switch .chg.down{color:rgba(235,235,245,.45)}

    /* ---------- 缺席 ---------- */
    .gaps{display:grid;grid-template-columns:repeat(3,1fr);gap:13px;margin-bottom:15px}
    .gaps .g{padding:15px 17px;border-radius:16px;background:rgba(255,255,255,.03);border:1px solid var(--stroke)}
    .gaps .k{font-size:12px;color:var(--dim)}
    .gaps b{display:block;font-size:23px;font-weight:700;margin-top:5px;font-variant-numeric:tabular-nums;letter-spacing:-.02em}
    .gaps .s{font-size:11.5px;color:var(--faint);margin-top:3px;display:block}
    .gaplist{display:flex;flex-direction:column;gap:7px;font-size:13px}
    .gaplist .r{display:grid;grid-template-columns:1fr 86px;gap:12px;padding:9px 14px;border-radius:12px;
      background:rgba(255,255,255,.025);color:var(--dim)}
    .gaplist .r b{color:var(--text);font-weight:600;font-variant-numeric:tabular-nums;text-align:right}

    /* ---------- 场景 ---------- */
    .scenes{display:flex;flex-direction:column;gap:10px}
    .scenes .row{display:grid;grid-template-columns:72px 1fr 132px;gap:14px;align-items:center;font-size:13px}
    .scenes .row .nm{color:var(--text)}
    .scenes .row .track{height:15px;border-radius:7px;background:rgba(255,255,255,.05);overflow:hidden}
    .scenes .row .track i{display:block;height:100%;border-radius:7px;transform-origin:left;
      animation:growX .9s cubic-bezier(.16,1,.3,1) both}
    .scenes .row .amt{text-align:right;color:var(--dim);font-size:12px;font-variant-numeric:tabular-nums}

    /* ---------- 音量 × 时段 ---------- */
    .hdb{display:flex;align-items:flex-end;gap:5px;height:150px;margin-top:12px}
    .hdb .b{flex:1;border-radius:6px 6px 2px 2px;transform-origin:bottom;
      animation:growY .85s cubic-bezier(.16,1,.3,1) both;position:relative}
    .hdbAxis{display:flex;gap:5px;margin-top:8px;font-size:10.5px;color:var(--faint)}
    .hdbAxis span{flex:1;text-align:center}

    @media (max-width:900px){.kpis{grid-template-columns:repeat(2,1fr)}.gaps{grid-template-columns:1fr}}
    @media (max-width:720px){
      .wrap{padding:40px 16px 64px}
      .card{padding:20px 18px 22px;border-radius:20px}
      .dev{grid-template-columns:96px 1fr 72px;gap:10px}
      .dist .line{grid-template-columns:78px 1fr 78px;gap:10px}
      .heat .row,.heat .hrow{grid-template-columns:26px repeat(24,minmax(0,1fr))}
    }
    @media print{.reveal{opacity:1!important;animation:none!important}}
    @media (prefers-reduced-motion:reduce){
      *{animation:none!important;transition:none!important}
      .reveal{opacity:1}
      /* 这几处的初始态是 opacity:0，靠动画转正；关掉动画时必须显式还原，否则内容整块消失 */
      #insights li,.calGrid i,.heat .cell{opacity:1}
    }
    </style>
    </head>
    <body>
    <div class="wrap">

      <header class="hero reveal">
        <div class="badge"><i></i>本地分析 · 数据没有离开这台电脑</div>
        <h1>耳机使用统计</h1>
        <p class="sub" id="metaLine">正在解析…</p>
        <div class="heroNums">
          <div class="heroNum glass"><b class="big" id="heroHours">0</b><i class="unit">小时</i><span class="lab">累计佩戴</span></div>
          <div class="heroNum glass"><b class="big" id="heroSessions">0</b><i class="unit">次</i><span class="lab">佩戴次数</span></div>
          <div class="heroNum glass"><b class="big" id="heroDays">0</b><i class="unit">天</i><span class="lab">使用天数</span></div>
        </div>
      </header>

      <div class="rangebar reveal" id="rangebar">
        <button data-range="7">7 天</button>
        <button data-range="30">30 天</button>
        <button data-range="90">90 天</button>
        <button data-range="0" class="on">全部</button>
      </div>

      <section class="kpis reveal" id="kpis"></section>
      <div class="dep reveal" id="dep"></div>

      <section class="card glass reveal">
        <h2>一眼结论</h2>
        <ul id="insights"><li class="empty">暂无数据</li></ul>
      </section>

      <section class="card glass reveal">
        <h2>耳机编年史</h2>
        <p class="hint">按首次使用时间排列 · 条长代表用得多少 · <b>鼠标悬停看详细</b></p>
        <div id="devices"></div>
      </section>

      <section class="card glass reveal">
        <h2>换机前后对比</h2>
        <p class="hint">以每副耳机首次使用那天为分界 · 比较之前与之后 <b>180 天</b>的日均佩戴时长</p>
        <div id="switch" class="switch"></div>
      </section>

      <section class="card glass reveal">
        <h2>佩戴日历</h2>
        <p class="hint">每格一天，颜色越亮戴得越久 · 一眼看出哪段时期荒废了</p>
        <div id="cal"></div>
      </section>

      <section class="card glass reveal">
        <h2>缺席分析</h2>
        <p class="hint">完全没戴耳机的那几天 · 以及最长的一段彻底空窗</p>
        <div id="gap"></div>
      </section>

      <section class="card glass reveal">
        <h2 id="dailyTitle">每日佩戴时长</h2>
        <p class="hint" id="dailyHint">按天拆分，紫色是周末</p>
        <div id="daily" class="bars"></div>
        <div id="axis" class="axis"></div>
      </section>

      <section class="card glass reveal">
        <h2>长期趋势</h2>
        <p class="hint">淡色是每日时长，亮线是 <b>30 天移动平均</b> · 滤掉日波动才看得出真实走向</p>
        <div id="trend"></div>
      </section>

      <section class="card glass reveal">
        <h2>一周里的使用时段</h2>
        <p class="hint">纵向是一周七天，横向是 24 小时 · 越亮说明那个时段戴得越久</p>
        <div id="heat" class="heat"></div>
      </section>

      <section class="card glass reveal">
        <h2>音量 × 时段</h2>
        <p class="hint">24 小时各自的平均音量 · 看哪个时段你听得最响</p>
        <div id="hourdb" class="hdb"></div>
        <div id="hourdbAxis" class="hdbAxis"></div>
      </section>

      <section class="card glass reveal">
        <h2>音量变化趋势</h2>
        <p class="hint">每月平均音量 · 看这些年有没有越听越响 · <b>虚线是 80 dB 参考线</b></p>
        <div id="dbtrend"></div>
      </section>

      <section class="card glass reveal">
        <h2>音量分布</h2>
        <p class="hint">按样本级实际音量累计 · 橙色 ≥80 dB，红色 ≥90 dB</p>
        <div id="volume" class="dist"></div>
      </section>

      <section class="card glass reveal">
        <h2>作息节奏</h2>
        <p class="hint"><b style="color:#0a84ff">蓝点</b>是每天第一次戴上，<b style="color:#bf5af2">紫点</b>是最后一次摘下 · 耳机在替你记录作息</p>
        <div id="clock"></div>
      </section>

      <section class="card glass reveal">
        <h2>使用场景</h2>
        <p class="hint">按每次佩戴的开始时刻自动归类 · 看看声音都花在哪些时候</p>
        <div id="scenes" class="scenes"></div>
      </section>

      <section class="card glass reveal">
        <h2>单次佩戴时长</h2>
        <p class="hint">一次戴多久的习惯分布 · 短碎片还是长时间沉浸</p>
        <div id="durhist" class="dist"></div>
      </section>

      <section class="card glass reveal">
        <h2>最长的佩戴记录</h2>
        <p class="hint">按单次时长排序 · 峰值标红的是音量超过 90 dB</p>
        <div id="table"></div>
      </section>

      <footer>
        <b id="footMeta"></b><br>
        数据来源：Apple 健康「耳机音量」记录 · 全程离线计算，不含任何网络请求
      </footer>
    </div>
    """##
}
