/// The admin dashboard's project switcher (the logo menu in the top-left
/// corner) and the Fishing Waters project it switches to. The luma project is
/// the original dashboard in api.dart; this file only adds the switcher
/// around it and the second project's markup, styles and script.
///
/// Fishing Waters data comes from /admin/fishing-waters/* (see
/// fishing_waters.dart), polled while that project is on screen.
class AdminProjects {
  static const _lumaLogo =
      '<img class="proj-logo" src="data:image/png;base64,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" '
      'width="30" height="30" alt="">';

  static const _fwLogo = '<svg class="proj-logo" viewBox="0 0 40 40" '
      'width="30" height="30" aria-hidden="true">'
      '<rect width="40" height="40" rx="9" fill="#12546b"/>'
      '<path d="M8.5 17C11.6 12.4 18.6 11.4 23.6 15L29.6 11 28.2 17 29.6 23 '
      '23.6 19C18.6 22.6 11.6 21.6 8.5 17Z" fill="#f4c56a"/>'
      '<circle cx="13.4" cy="16.3" r="1.2" fill="#12546b"/>'
      '<path d="M6 27.5c2.4 0 2.4-2 4.8-2s2.4 2 4.8 2 2.4-2 4.8-2 2.4 2 4.8 2 '
      '2.4-2 4.8-2 2.4 2 4.8 2" fill="none" stroke="#8fe1ef" stroke-width="2" '
      'stroke-linecap="round"/>'
      '<path d="M6 32.5c2.4 0 2.4-2 4.8-2s2.4 2 4.8 2 2.4-2 4.8-2 2.4 2 4.8 2 '
      '2.4-2 4.8-2 2.4 2 4.8 2" fill="none" stroke="#4fb3cc" stroke-width="2" '
      'stroke-linecap="round" opacity=".7"/></svg>';

  static const _check = '<svg class="ico proj-check" viewBox="0 0 24 24" '
      'aria-hidden="true"><path d="M5 12.5l4.5 4.5L19 7.5"/></svg>';

  static String _ico(String paths) =>
      '<svg class="ico" viewBox="0 0 24 24" aria-hidden="true">$paths</svg>';

  static final _icons = {
    'users': _ico('<circle cx="9" cy="8" r="3.2"/><path d="M3.5 19c.6-3.2 '
        '2.8-5 5.5-5s4.9 1.8 5.5 5"/><path d="M15.5 5.2a3 3 0 0 1 0 5.6"/>'
        '<path d="M17.5 14.3c1.7.6 2.8 2.2 3 4.7"/>'),
    'weather': _ico('<path d="M7 17.5h9.5a4 4 0 0 0 .4-8 5.5 5.5 0 0 0-10.6 '
        '1.4A3.4 3.4 0 0 0 7 17.5z"/><path d="M9 20.5l-.7 1.5M13 20.5l-.7 '
        '1.5"/>'),
    'products': _ico(
        '<path d="M4 9.5h16v3H4z"/><path d="M5.5 12.5V20h13v-7.5"/>'
        '<path d="M12 9.5V20"/><path d="M12 9.5C10.5 6 7 5.4 7 7.6 7 9 9.5 9.5 '
        '12 9.5zM12 9.5c1.5-3.5 5-4.1 5-1.9 0 1.4-2.5 1.9-5 1.9z"/>'),
  };

  /// Replaces the dashboard's plain `<h1>`: the logo, title and caret are one
  /// button that opens the project menu.
  static const switcherHtml = '<h1 class="proj-h1">'
      '<button type="button" class="proj-btn" id="projBtn" '
      'aria-haspopup="menu" aria-expanded="false" aria-controls="projMenu">'
      '<span class="proj-mark" data-for="luma">$_lumaLogo</span>'
      '<span class="proj-mark" data-for="fw" hidden>$_fwLogo</span>'
      '<span class="proj-title" data-for="luma">luma<span class="dot">.</span> admin</span>'
      '<span class="proj-title" data-for="fw" hidden>Fishing Waters</span>'
      '<svg class="ico proj-caret" viewBox="0 0 24 24" aria-hidden="true">'
      '<path d="M7 10l5 5 5-5"/></svg>'
      '<span class="sr-only">Switch project</span>'
      '</button></h1>'
      '<div class="proj-menu" id="projMenu" role="menu" aria-label="Projects" hidden>'
      '<div class="proj-menu-label">Projects</div>'
      '<button type="button" class="proj-item" role="menuitemradio" '
      'aria-checked="true" data-project="luma">$_lumaLogo'
      '<span class="proj-item-text"><b>luma</b><small>Sync server &amp; app</small></span>'
      '$_check</button>'
      '<button type="button" class="proj-item" role="menuitemradio" '
      'aria-checked="false" data-project="fw">$_fwLogo'
      '<span class="proj-item-text"><b>Fishing Waters</b><small>Roblox game</small></span>'
      '$_check</button>'
      '</div>';

  static String get fishingWatersHtml =>
      '<div class="project fw" id="project-fw" hidden>'
      '<div class="fw-setup card" id="fwSetup" hidden>'
      '<h2>Connect the game</h2>'
      '<ol>'
      '<li>Set <code>LUMA_FISHING_WATERS_KEY</code> in the server\'s '
      '<code>.env</code> to a long random string and restart the server.</li>'
      '<li>In the Roblox Creator Dashboard, add the same value as a secret '
      'named <code>LumaDashboardKey</code> for the experience, allowed for '
      '<code>sync.luma-app.cc</code>.</li>'
      '<li>Turn on <b>Allow HTTP Requests</b> in Game Settings → Security and '
      'publish. Live servers appear here within 15 seconds.</li>'
      '</ol></div>'
      '<div class="stats">'
      '<div class="stat"><div class="n" id="fwStatPlayers">–</div><div class="l">Players online</div></div>'
      '<div class="stat"><div class="n" id="fwStatServers">–</div><div class="l">Live servers</div></div>'
      '<div class="stat"><div class="n" id="fwStatGrants">–</div><div class="l">Gamepass grants</div></div>'
      '<div class="stat"><div class="n" id="fwStatWeather">–</div><div class="l">Weather</div></div>'
      '</div>'
      '<div class="fw-bar">'
      '<div class="tabs" role="tablist" aria-label="Fishing Waters">'
      '<button class="tab-btn fw-tab" role="tab" data-fwtab="online">${_icons['users']}Online</button>'
      '<button class="tab-btn fw-tab" role="tab" data-fwtab="weather">${_icons['weather']}Weather</button>'
      '<button class="tab-btn fw-tab" role="tab" data-fwtab="products">${_icons['products']}Products</button>'
      '</div>'
      '<div class="fw-live" id="fwLive" aria-live="polite"><span class="fw-pulse"></span>'
      '<span id="fwLiveText">Connecting…</span></div>'
      '</div>'
      // Online
      '<div class="tab-panel fw-panel" id="fw-panel-online" role="tabpanel">'
      '<div class="card table-card">'
      '<div class="fw-card-head"><h2>Players in game</h2>'
      '<input type="search" id="fwSearch" class="fw-search" placeholder="Search players…" '
      'aria-label="Search players" autocomplete="off"></div>'
      '<div class="fw-scroll"><table class="fw-table"><thead><tr><th>Player</th><th>User ID</th>'
      '<th>Server</th><th>In game</th><th>Gamepasses</th><th></th></tr></thead>'
      '<tbody id="fwPlayers"><tr><td colspan="6" class="muted">Loading…</td></tr></tbody></table></div>'
      '</div>'
      '<div class="card table-card">'
      '<h2>Live servers</h2>'
      '<div class="fw-scroll"><table class="fw-table"><thead><tr><th>Server</th><th>Players</th>'
      '<th>Weather</th><th>Up for</th><th>Last report</th></tr></thead>'
      '<tbody id="fwServers"><tr><td colspan="5" class="muted">Loading…</td></tr></tbody></table></div>'
      '</div>'
      '</div>'
      // Weather
      '<div class="tab-panel fw-panel" id="fw-panel-weather" role="tabpanel">'
      '<div class="fw-weather">'
      '<div class="card fw-radar-card">'
      '<div class="fw-card-head"><h2>Radar</h2>'
      '<div class="fw-seg-group" id="fwRange" role="group" aria-label="Radar range">'
      '<button type="button" class="fw-seg" data-range="harbour" aria-pressed="true">Harbour</button>'
      '<button type="button" class="fw-seg" data-range="world" aria-pressed="false">World</button>'
      '</div></div>'
      '<div class="fw-server-pick" id="fwServerPick" role="group" aria-label="Server"></div>'
      '<div class="fw-radar-box"><canvas id="fwRadar" role="img" aria-label="Weather radar"></canvas>'
      '<div class="fw-radar-empty" id="fwRadarEmpty" hidden>No live server to show.</div></div>'
      '<div class="fw-legend">'
      '<span><i style="background:#35b45a"></i>Light</span>'
      '<span><i style="background:#c4d93a"></i>Moderate</span>'
      '<span><i style="background:#f2b84b"></i>Heavy</span>'
      '<span><i style="background:#ec5f5f"></i>Intense</span>'
      '<span><i class="dot-player"></i>Player</span>'
      '</div>'
      '</div>'
      '<div class="fw-weather-side">'
      '<div class="card">'
      '<h2>Conditions</h2>'
      '<div class="fw-now" id="fwNow"><div class="muted">Waiting for a live server…</div></div>'
      '</div>'
      '<div class="card">'
      '<h2>Set weather</h2>'
      '<div class="fw-kinds" id="fwKinds" role="radiogroup" aria-label="Weather"></div>'
      '<p class="fw-note" id="fwWeatherNote">Applies to every live server within '
      '15 seconds. <b>Auto</b> follows the built-in forecast.</p>'
      '</div>'
      '<div class="card">'
      '<h2>Forecast</h2>'
      '<div id="fwForecast"><div class="muted">No forecast yet.</div></div>'
      '</div>'
      '</div>'
      '</div>'
      '</div>'
      // Products
      '<div class="tab-panel fw-panel" id="fw-panel-products" role="tabpanel">'
      '<div class="fw-passes" id="fwPasses"></div>'
      '<div class="card">'
      '<h2>Grant a gamepass</h2>'
      '<form class="fw-grant" id="fwGrantForm" novalidate>'
      '<div class="fw-field"><label for="fwGrantUser">Roblox user</label>'
      '<input id="fwGrantUser" name="user" list="fwOnlineNames" required '
      'placeholder="Username or user ID" autocomplete="off" spellcheck="false">'
      '<datalist id="fwOnlineNames"></datalist></div>'
      '<div class="fw-field"><label for="fwGrantPass">Gamepass</label>'
      '<select id="fwGrantPass" name="pass"></select></div>'
      '<button type="submit" class="btn btn-primary" id="fwGrantBtn">Grant</button>'
      '</form>'
      '<div class="fw-msg" id="fwGrantMsg" role="status" aria-live="polite"></div>'
      '<p class="fw-note">A grant unlocks the gamepass\'s in-game benefit in every '
      'server, straight away for players who are online. It doesn\'t add Roblox '
      'Marketplace ownership, so it won\'t show in their inventory.</p>'
      '</div>'
      '<div class="card table-card">'
      '<h2>Granted</h2>'
      '<div class="fw-scroll"><table class="fw-table"><thead><tr><th>Player</th><th>Gamepass</th>'
      '<th>Granted</th><th>Status</th><th></th></tr></thead>'
      '<tbody id="fwGrants"><tr><td colspan="5" class="muted">Loading…</td></tr></tbody></table></div>'
      '</div>'
      '</div>'
      '</div>';

  static const css = r'''
.sr-only{position:absolute;width:1px;height:1px;padding:0;margin:-1px;overflow:hidden;clip:rect(0,0,0,0);white-space:nowrap;border:0}
header.top{align-items:center;position:relative}
.proj-h1{margin:0;font-size:inherit}
.proj-btn{display:inline-flex;align-items:center;gap:10px;min-height:44px;padding:6px 10px 6px 6px;margin-left:-6px;border-radius:12px;border:1px solid transparent;background:transparent;color:#ece8f7;font:inherit;font-size:19px;font-weight:700;letter-spacing:-.01em;cursor:pointer;transition:background .15s,border-color .15s}
.proj-btn:hover,.proj-btn[aria-expanded=true]{background:#161225;border-color:#262038}
.proj-btn:focus-visible{outline:2px solid #8a7ee0;outline-offset:2px}
.proj-mark{display:inline-flex}
.proj-mark[hidden],.proj-title[hidden]{display:none}
.proj-logo{width:30px;height:30px;border-radius:8px;flex:none;display:block}
.proj-caret{width:16px;height:16px;color:#8d86a8;transition:transform .2s}
.proj-btn[aria-expanded=true] .proj-caret{transform:rotate(180deg)}
.proj-menu{position:absolute;left:-6px;top:calc(100% + 6px);z-index:80;width:280px;background:#191428;border:1px solid #322a4d;border-radius:14px;padding:6px;box-shadow:0 18px 44px rgba(0,0,0,.6);transform-origin:top left;animation:projIn .16s ease-out}
.proj-menu[hidden]{display:none}
@keyframes projIn{from{opacity:0;transform:translateY(-4px) scale(.98)}to{opacity:1;transform:none}}
.proj-menu-label{font-size:11px;font-weight:600;letter-spacing:.08em;text-transform:uppercase;color:#7f7898;padding:8px 10px 6px}
.proj-item{display:flex;align-items:center;gap:12px;width:100%;min-height:52px;padding:8px 10px;border:0;border-radius:10px;background:transparent;color:#ece8f7;font:inherit;text-align:left;cursor:pointer;transition:background .12s}
.proj-item:hover{background:#241d3d}
.proj-item:focus-visible{outline:2px solid #8a7ee0;outline-offset:-2px}
.proj-item[aria-checked=true]{background:#1f1935}
.proj-item-text{display:flex;flex-direction:column;flex:1;min-width:0}
.proj-item-text b{font-size:14px;font-weight:600}
.proj-item-text small{font-size:12px;color:#8d86a8}
.proj-check{width:16px;height:16px;color:#b9b0f5;opacity:0}
.proj-item[aria-checked=true] .proj-check{opacity:1}
.project[hidden]{display:none}
/* Fishing Waters turns the whole page ocean blue. Gradients can't be
   transitioned, so the ocean sits on a fixed layer behind everything and
   fades in; the surfaces of the project itself are blue from the start. */
body::before{content:"";position:fixed;inset:0;z-index:-1;pointer-events:none;opacity:0;transition:opacity .6s ease;
  background:radial-gradient(120% 70% at 50% -10%,#0f4a63 0%,#0a2b3b 45%,rgba(6,19,26,0) 80%),linear-gradient(180deg,#071c27 0%,#06131a 60%,#050f15 100%)}
body.theme-fw::before{opacity:1}
body.theme-fw .btn-ghost{background:#0c2430;color:#bfe0ea;border-color:#1f4252}
body.theme-fw .btn-ghost:hover{border-color:#2f6377;color:#ecf8fb}
body.theme-fw .proj-btn:hover,body.theme-fw .proj-btn[aria-expanded=true]{background:#0c2430;border-color:#1f4252}
body.theme-fw .proj-menu{background:#0b1f2a;border-color:#1f4252}
body.theme-fw .proj-item:hover{background:#12313f}
body.theme-fw .proj-item[aria-checked=true]{background:#0f2a36}
body.theme-fw .proj-menu-label,body.theme-fw .proj-item-text small,body.theme-fw .proj-caret{color:#86a3b0}
.project:not([hidden]){animation:projFade .35s ease-out}
@keyframes projFade{from{opacity:0;transform:translateY(6px)}to{opacity:1;transform:none}}
.fw .card{background:rgba(9,29,39,.82);border-color:#173543}
.fw .stat{background:linear-gradient(180deg,rgba(14,42,56,.9),rgba(9,29,39,.9));border-color:#1b3a48}
.fw .stat .l,.fw h2,.fw th{color:#86a3b0}
.fw .tabs{background:rgba(9,29,39,.85);border-color:#1b3a48}
.fw .tab-btn{color:#8fb0bd}
.fw .tab-btn:hover{color:#ecf8fb}
.fw th{border-bottom-color:#1b3a48}
.fw td{border-bottom-color:#132c38}
.fw tbody tr:hover td{background:#0d2633}
.fw .muted{color:#8fb0bd}
.fw .tab-btn.active{background:#4cc3d9;color:#06171d}
.fw .tab-btn .ico{width:15px;height:15px}
.fw .btn-primary{background:#4cc3d9;border-color:#4cc3d9;color:#06171d}
.fw .btn-primary:hover{background:#6fd2e3;border-color:#6fd2e3}
.fw .btn-primary:disabled{opacity:.55;cursor:progress}
.fw .tab-btn:focus-visible,.fw .fw-seg:focus-visible,.fw .fw-kind:focus-visible,.fw input:focus-visible,.fw select:focus-visible{outline:2px solid #4cc3d9;outline-offset:2px}
.fw-setup{border-color:#2a4a55;background:linear-gradient(180deg,#0f1d24,#121a22)}
.fw-setup ol{margin:0;padding-left:20px;color:#b9c7cf;line-height:1.7}
.fw-setup code{background:#0a1418;border:1px solid #23404a;border-radius:5px;padding:1px 6px;font-size:12.5px;color:#9fe3ef}
.fw-bar{display:flex;align-items:center;gap:12px 18px;flex-wrap:wrap;margin-bottom:24px}
.fw-bar .tabs{margin-bottom:0}
.fw-live{display:inline-flex;align-items:center;gap:8px;font-size:12px;color:#86a3b0;font-variant-numeric:tabular-nums}
.fw-pulse{width:8px;height:8px;border-radius:50%;background:#5f7d8a}
.fw-live.on .fw-pulse{background:#4cd98a;box-shadow:0 0 0 0 rgba(76,217,138,.5);animation:fwPulse 2s infinite}
.fw-live.off .fw-pulse{background:#e07e7e}
@keyframes fwPulse{70%{box-shadow:0 0 0 7px rgba(76,217,138,0)}100%{box-shadow:0 0 0 0 rgba(76,217,138,0)}}
.fw-card-head{display:flex;align-items:center;justify-content:space-between;gap:12px;flex-wrap:wrap;margin-bottom:14px}
.fw-card-head h2{margin:0}
.fw-search{min-height:36px;width:220px;max-width:100%;padding:7px 12px;border-radius:9px;background:#08161e;border:1px solid #1d3d4c;color:#ece8f7;font:inherit;font-size:13px}
.fw-scroll{overflow-x:auto}
.fw-table{width:100%;border-collapse:collapse}
.fw-table td{vertical-align:middle}
.fw-table .num{font-variant-numeric:tabular-nums;color:#b0cbd5}
.fw-player{display:flex;align-items:center;gap:10px;min-width:0}
.fw-av{position:relative;width:34px;height:34px;border-radius:50%;flex:none;background:#1f2f38;color:#9fe3ef;display:inline-flex;align-items:center;justify-content:center;font-size:13px;font-weight:700;overflow:hidden}
.fw-av img{position:absolute;inset:0;width:100%;height:100%;object-fit:cover}
.fw-names{display:flex;flex-direction:column;min-width:0;line-height:1.3}
.fw-names b{font-weight:600;color:#ece8f7;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.fw-names small{color:#86a3b0;font-size:12px}
.fw-chip{display:inline-flex;align-items:center;gap:5px;padding:2px 9px;border-radius:999px;font-size:11.5px;font-weight:600;background:rgba(76,195,217,.12);border:1px solid rgba(76,195,217,.3);color:#9fe3ef;margin:2px 4px 2px 0;white-space:nowrap}
.fw-chip.kind-Storm{background:rgba(236,95,95,.12);border-color:rgba(236,95,95,.3);color:#f2a3a3}
.fw-chip.kind-Rain,.fw-chip.kind-LightRain{background:rgba(120,150,240,.12);border-color:rgba(120,150,240,.3);color:#b4c4f7}
.fw-chip.kind-Clear{background:rgba(242,201,76,.10);border-color:rgba(242,201,76,.28);color:#f2d68a}
.fw-chip.muted-chip{background:#102733;border-color:#214555;color:#9bb6c2}
.fw-job{font-family:ui-monospace,SFMono-Regular,Consolas,monospace;font-size:12px;color:#c3dbe3}
.fw-empty{padding:28px 12px;text-align:center;color:#86a3b0}
.fw-empty b{display:block;color:#ece8f7;font-size:14px;margin-bottom:4px}
.fw-weather{display:grid;grid-template-columns:minmax(0,1.35fr) minmax(0,1fr);gap:18px;align-items:start}
.fw-weather-side{display:flex;flex-direction:column;gap:18px}
.fw-weather-side .card,.fw-weather .card{margin-bottom:0}
.fw-seg-group{display:inline-flex;gap:3px;background:#08161e;border:1px solid #1b3a48;border-radius:10px;padding:3px}
.fw-seg{min-height:32px;padding:5px 12px;border:0;border-radius:7px;background:transparent;color:#8fb0bd;font:inherit;font-size:12.5px;font-weight:500;cursor:pointer;transition:background .15s,color .15s}
.fw-seg:hover{color:#ece8f7}
.fw-seg[aria-pressed=true]{background:#1d3a44;color:#bff0f8}
.fw-server-pick{display:flex;gap:6px;flex-wrap:wrap;margin-bottom:12px}
.fw-server-pick:empty{display:none}
.fw-radar-box{position:relative;width:100%;max-width:620px;margin:0 auto;aspect-ratio:1}
.fw-radar-box canvas{width:100%;height:100%;display:block}
.fw-radar-empty{position:absolute;inset:0;display:flex;align-items:center;justify-content:center;color:#86a3b0;font-size:13px}
.fw-radar-empty[hidden]{display:none}
.fw-legend{display:flex;flex-wrap:wrap;gap:8px 16px;justify-content:center;margin-top:14px;font-size:12px;color:#9bb6c2}
.fw-legend span{display:inline-flex;align-items:center;gap:6px}
.fw-legend i{width:12px;height:12px;border-radius:3px;display:inline-block}
.fw-legend i.dot-player{border-radius:50%;background:#fff;box-shadow:0 0 0 3px rgba(76,195,217,.45);width:8px;height:8px}
.fw-now-head{display:flex;align-items:center;gap:14px;margin-bottom:16px}
.fw-now-ico{width:52px;height:52px;border-radius:14px;display:flex;align-items:center;justify-content:center;background:#132a33;color:#9fe3ef;flex:none}
.fw-now-ico .ico{width:28px;height:28px}
.fw-now-kind{font-size:22px;font-weight:700;letter-spacing:-.015em}
.fw-now-sub{font-size:12.5px;color:#86a3b0}
.fw-meters{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:10px}
.fw-meter{background:#0a1b24;border:1px solid #183442;border-radius:10px;padding:10px 12px}
.fw-meter .k{font-size:11px;letter-spacing:.05em;text-transform:uppercase;color:#86a3b0}
.fw-meter .v{font-size:17px;font-weight:650;font-variant-numeric:tabular-nums;margin-top:2px}
.fw-meter .bar{height:4px;border-radius:2px;background:#183442;margin-top:8px;overflow:hidden}
.fw-meter .bar i{display:block;height:100%;background:#4cc3d9;border-radius:2px;transition:width .4s ease-out}
.fw-kinds{display:grid;grid-template-columns:repeat(auto-fill,minmax(96px,1fr));gap:8px}
.fw-kind{display:flex;flex-direction:column;align-items:center;justify-content:center;gap:6px;min-height:76px;padding:10px 6px;border-radius:12px;border:1px solid #1d3d4c;background:#0a1b24;color:#c3dbe3;font:inherit;font-size:12.5px;font-weight:600;cursor:pointer;transition:border-color .15s,background .15s,color .15s,transform .1s}
.fw-kind .ico{width:22px;height:22px}
.fw-kind:hover{border-color:#3a5f6b;color:#ece8f7}
.fw-kind:active{transform:scale(.97)}
.fw-kind[aria-checked=true]{border-color:#4cc3d9;background:#0f2a32;color:#bff0f8;box-shadow:inset 0 0 0 1px #4cc3d9}
.fw-kind:disabled{opacity:.55;cursor:progress}
.fw-note{font-size:12.5px;color:#86a3b0;line-height:1.55;margin:12px 0 0}
.fw-note b{color:#c3dbe3}
.fw-note.lock{color:#f2d68a}
.fw-timeline{display:flex;height:12px;border-radius:6px;overflow:hidden;position:relative;margin:4px 0 8px;background:#102733}
.fw-timeline span{height:100%;border-right:1px solid #06131a}
.fw-timeline .now{position:absolute;top:-3px;bottom:-3px;width:3px;margin-left:-1.5px;background:#fff;border-radius:2px;box-shadow:0 0 0 2px #06131a}
.fw-timeline.paused{opacity:.4}
.fw-tl-scale{display:flex;justify-content:space-between;font-size:11px;color:#5f7d8a;margin-bottom:12px;font-variant-numeric:tabular-nums}
.fw-upcoming{list-style:none;margin:0;padding:0;display:flex;flex-direction:column;gap:6px}
.fw-upcoming li{display:flex;align-items:center;gap:10px;padding:8px 10px;border-radius:9px;background:#0a1b24;border:1px solid #163240;font-size:13px}
.fw-upcoming li .ico{width:18px;height:18px;color:#9fe3ef}
.fw-upcoming li .when{margin-left:auto;color:#86a3b0;font-size:12px;font-variant-numeric:tabular-nums}
.fw-upcoming li.current{border-color:#2a4a55;background:#0f2028}
.fw-passes{display:grid;grid-template-columns:repeat(auto-fill,minmax(240px,1fr));gap:12px;margin-bottom:18px}
.fw-pass{display:flex;align-items:center;gap:14px;background:linear-gradient(180deg,#14202a,#121822);border:1px solid #213640;border-radius:14px;padding:16px}
.fw-pass-ico{width:44px;height:44px;border-radius:12px;background:rgba(76,195,217,.14);border:1px solid rgba(76,195,217,.3);color:#9fe3ef;display:flex;align-items:center;justify-content:center;flex:none}
.fw-pass-ico .ico{width:22px;height:22px}
.fw-pass b{display:block;font-size:14.5px}
.fw-pass small{display:block;color:#86a3b0;font-size:12px;font-variant-numeric:tabular-nums}
.fw-pass a{color:#9fe3ef;font-size:12px;text-decoration:none}
.fw-pass a:hover{text-decoration:underline}
.fw-pass .count{margin-left:auto;text-align:right}
.fw-pass .count b{font-size:20px;font-variant-numeric:tabular-nums}
.fw-grant{display:flex;gap:12px;flex-wrap:wrap;align-items:flex-end}
.fw-field{display:flex;flex-direction:column;gap:6px;flex:1;min-width:200px}
.fw-field label{font-size:12px;font-weight:600;color:#9bb6c2}
.fw-field input,.fw-field select{min-height:44px;padding:9px 12px;border-radius:10px;background:#08161e;border:1px solid #1d3d4c;color:#ece8f7;font:inherit;font-size:14px}
.fw-field input[aria-invalid=true]{border-color:#e07e7e}
.fw-grant .btn{min-height:44px;padding-left:22px;padding-right:22px}
.fw-msg{font-size:13px;margin-top:10px;min-height:20px}
.fw-msg.err{color:#f0a0a0}
.fw-msg.ok{color:#7ee0a5}
.fw-status{display:inline-flex;align-items:center;gap:6px;font-size:12.5px;color:#86a3b0}
.fw-status::before{content:"";width:7px;height:7px;border-radius:50%;background:#3b5866}
.fw-status.on{color:#7ee0a5}
.fw-status.on::before{background:#4cd98a}
.fw-row-btn{min-height:32px}
@media (max-width:960px){.fw-weather{grid-template-columns:1fr}}
@media (max-width:640px){.proj-menu{width:calc(100vw - 32px)}.fw-search{width:100%}.fw-meters{grid-template-columns:1fr 1fr}}
@media (prefers-reduced-motion:reduce){body::before{transition:none}.project:not([hidden]){animation:none}.proj-menu{animation:none}.fw-live.on .fw-pulse{animation:none}.proj-caret,.fw-meter .bar i{transition:none}}
''';

  /// Opens/closes the logo menu and swaps which project is on screen. The
  /// URL hash keeps the choice across reloads and form redirects: luma's own
  /// tab script owns plain hashes like `#users`, Fishing Waters uses `#fw-…`.
  static const switcherScript = r'''
(function () {
  var btn = document.getElementById('projBtn');
  var menu = document.getElementById('projMenu');
  if (!btn || !menu) return;
  var items = Array.prototype.slice.call(menu.querySelectorAll('.proj-item'));
  var views = { luma: document.getElementById('project-luma'), fw: document.getElementById('project-fw') };
  var titles = { luma: 'luma admin', fw: 'Fishing Waters · admin' };
  var current = null;
  var lastHash = { luma: '#users', fw: '#fw-online' };

  function show(project, updateHash) {
    if (!views[project]) project = 'luma';
    if (current && updateHash) lastHash[current] = location.hash || lastHash[current];
    current = project;
    Object.keys(views).forEach(function (k) { if (views[k]) views[k].hidden = k !== project; });
    document.querySelectorAll('.proj-mark,.proj-title').forEach(function (el) {
      el.hidden = el.dataset.for !== project;
    });
    items.forEach(function (it) { it.setAttribute('aria-checked', String(it.dataset.project === project)); });
    document.title = titles[project];
    document.body.classList.toggle('theme-fw', project === 'fw');
    if (updateHash) history.replaceState(null, '', lastHash[project]);
    document.dispatchEvent(new CustomEvent('adminproject', { detail: project }));
  }

  function open() {
    menu.hidden = false;
    btn.setAttribute('aria-expanded', 'true');
    var checked = items.filter(function (it) { return it.getAttribute('aria-checked') === 'true'; })[0];
    (checked || items[0]).focus();
  }
  function close(focusButton) {
    if (menu.hidden) return;
    menu.hidden = true;
    btn.setAttribute('aria-expanded', 'false');
    if (focusButton) btn.focus();
  }

  btn.addEventListener('click', function () { menu.hidden ? open() : close(false); });
  btn.addEventListener('keydown', function (e) {
    if (e.key === 'ArrowDown') { e.preventDefault(); open(); }
  });
  items.forEach(function (it) {
    it.addEventListener('click', function () {
      close(true);
      if (it.dataset.project !== current) show(it.dataset.project, true);
    });
  });
  menu.addEventListener('keydown', function (e) {
    var i = items.indexOf(document.activeElement);
    if (e.key === 'ArrowDown' || e.key === 'ArrowUp') {
      e.preventDefault();
      var next = (i + (e.key === 'ArrowDown' ? 1 : -1) + items.length) % items.length;
      items[next].focus();
    } else if (e.key === 'Home' || e.key === 'End') {
      e.preventDefault();
      items[e.key === 'Home' ? 0 : items.length - 1].focus();
    } else if (e.key === 'Escape') {
      e.preventDefault();
      close(true);
    } else if (e.key === 'Tab') {
      close(false);
    }
  });
  document.addEventListener('click', function (e) {
    if (!menu.hidden && !menu.contains(e.target) && !btn.contains(e.target)) close(false);
  });

  show(location.hash.indexOf('#fw') === 0 ? 'fw' : 'luma', false);
})();
''';

  static const fishingWatersScript = r'''
(function () {
  var root = document.getElementById('project-fw');
  if (!root) return;
  function $(id) { return document.getElementById(id); }
  var state = null, fetchedAt = 0, timer = null, tickTimer = null, failed = false;
  var tab = 'online', selectedJob = null, range = 'harbour', filter = '';
  var reduceMotion = window.matchMedia && matchMedia('(prefers-reduced-motion: reduce)').matches;

  function ico(paths) { return '<svg class="ico" viewBox="0 0 24 24" aria-hidden="true">' + paths + '</svg>'; }
  var ICONS = {
    Auto: ico('<path d="M20 11a8 8 0 0 0-14.6-4.5M4 4v3.5h3.5"/><path d="M4 13a8 8 0 0 0 14.6 4.5M20 20v-3.5h-3.5"/>'),
    Clear: ico('<circle cx="12" cy="12" r="4"/><path d="M12 2.5v2M12 19.5v2M2.5 12h2M19.5 12h2M5.3 5.3l1.4 1.4M17.3 17.3l1.4 1.4M5.3 18.7l1.4-1.4M17.3 6.7l1.4-1.4"/>'),
    LightRain: ico('<path d="M7 15.5h9.5a4 4 0 0 0 .4-8 5.5 5.5 0 0 0-10.6 1.4A3.4 3.4 0 0 0 7 15.5z"/><path d="M10 19l-.5 1.5M14 19l-.5 1.5"/>'),
    Rain: ico('<path d="M7 14.5h9.5a4 4 0 0 0 .4-8 5.5 5.5 0 0 0-10.6 1.4A3.4 3.4 0 0 0 7 14.5z"/><path d="M8.5 17.5l-1 2.5M12.5 17.5l-1 2.5M16.5 17.5l-1 2.5"/>'),
    Storm: ico('<path d="M7 14.5h9.5a4 4 0 0 0 .4-8 5.5 5.5 0 0 0-10.6 1.4A3.4 3.4 0 0 0 7 14.5z"/><path d="M12.5 13.5l-2.5 4h3.5l-2 4"/>'),
    Pass: ico('<path d="M4 9.5h16v3H4z"/><path d="M5.5 12.5V20h13v-7.5"/><path d="M12 9.5V20"/><path d="M12 9.5C10.5 6 7 5.4 7 7.6 7 9 9.5 9.5 12 9.5zM12 9.5c1.5-3.5 5-4.1 5-1.9 0 1.4-2.5 1.9-5 1.9z"/>')
  };
  var KIND_COLOR = { Clear: '#e8c35a', LightRain: '#7f9cf0', Rain: '#5872d9', Storm: '#d9536a' };

  function esc(s) {
    return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }
  function label(kind) {
    if (!kind) return 'Auto';
    return kind === 'LightRain' ? 'Light rain' : String(kind).replace(/([a-z])([A-Z])/g, '$1 $2');
  }
  function dur(sec) {
    sec = Math.max(0, Math.round(sec));
    var h = Math.floor(sec / 3600), m = Math.floor(sec % 3600 / 60), s = sec % 60;
    if (h) return h + 'h ' + m + 'm';
    if (m) return m + 'm ' + (m < 10 ? s + 's' : '');
    return s + 's';
  }
  // Server clock "now", advanced by the time since the last fetch.
  function now() { return state ? state.now + (Date.now() - fetchedAt) : Date.now(); }
  function ago(ms) { return dur((now() - ms) / 1000).trim() + ' ago'; }
  function initials(p) { return esc((p.displayName || p.name || '?').charAt(0).toUpperCase()); }
  function avatar(p) {
    return '<span class="fw-av">' + initials(p) +
      '<img src="/admin/fishing-waters/avatar/' + Number(p.userId) + '" alt="" loading="lazy" width="34" height="34"></span>';
  }
  function who(p) {
    return '<div class="fw-player">' + avatar(p) + '<div class="fw-names"><b>' +
      esc(p.displayName || p.name) + '</b><small>@' + esc(p.name) + '</small></div></div>';
  }
  function shortJob(id) { return String(id).slice(0, 8); }
  function passName(key) {
    var p = (state.passes || []).filter(function (x) { return x.key === key; })[0];
    return p ? p.name : key;
  }
  // A broken avatar URL falls back to the initial underneath it.
  root.addEventListener('error', function (e) {
    if (e.target.tagName === 'IMG' && e.target.parentNode.classList.contains('fw-av')) e.target.remove();
  }, true);

  // ---- data --------------------------------------------------------------
  function load() {
    return fetch('/admin/fishing-waters/state', { credentials: 'same-origin', headers: { Accept: 'application/json' } })
      .then(function (r) {
        if (r.redirected || r.status === 401) { location.href = '/admin/login'; throw new Error('signed out'); }
        if (!r.ok) throw new Error('HTTP ' + r.status);
        return r.json();
      })
      .then(function (json) { state = json; fetchedAt = Date.now(); failed = false; render(); })
      .catch(function () { failed = true; renderLive(); });
  }
  function poll() {
    clearTimeout(timer);
    if (root.hidden) return;
    load().then(function () { timer = setTimeout(poll, document.hidden ? 30000 : 5000); });
  }
  function post(path, body) {
    return fetch(path, {
      method: 'POST', credentials: 'same-origin',
      headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
      body: JSON.stringify(body)
    }).then(function (r) {
      return r.json().catch(function () { return {}; }).then(function (json) {
        if (!r.ok) throw new Error(json.message || 'Request failed (' + r.status + ').');
        state = json; fetchedAt = Date.now(); render();
        return json;
      });
    });
  }

  // ---- tabs --------------------------------------------------------------
  var tabs = Array.prototype.slice.call(root.querySelectorAll('.fw-tab'));
  function activate(next, updateHash) {
    if (['online', 'weather', 'products'].indexOf(next) < 0) next = 'online';
    tab = next;
    tabs.forEach(function (b) {
      var on = b.dataset.fwtab === next;
      b.classList.toggle('active', on);
      b.setAttribute('aria-selected', String(on));
    });
    root.querySelectorAll('.fw-panel').forEach(function (p) { p.classList.toggle('active', p.id === 'fw-panel-' + next); });
    if (updateHash) history.replaceState(null, '', '#fw-' + next);
    radarLoop();
  }
  tabs.forEach(function (b) { b.addEventListener('click', function () { activate(b.dataset.fwtab, true); }); });

  document.addEventListener('adminproject', function (e) {
    if (e.detail === 'fw') {
      activate((location.hash.match(/^#fw-(\w+)/) || [])[1], false);
      poll();
      clearInterval(tickTimer);
      tickTimer = setInterval(tick, 1000);
    } else {
      clearTimeout(timer);
      clearInterval(tickTimer);
      radarLoop();
    }
  });
  document.addEventListener('visibilitychange', function () {
    if (!document.hidden && !root.hidden) poll();
    radarLoop();
  });

  // ---- rendering ---------------------------------------------------------
  function allPlayers() {
    var out = [];
    (state.servers || []).forEach(function (s) {
      s.players.forEach(function (p) { out.push({ p: p, s: s }); });
    });
    return out;
  }
  function grantsFor(userId) {
    return (state.grants || []).filter(function (g) { return g.userId === userId; });
  }
  function onlineIds() {
    var ids = {};
    allPlayers().forEach(function (e) { ids[e.p.userId] = true; });
    return ids;
  }
  function server() {
    var list = state.servers || [];
    return list.filter(function (s) { return s.jobId === selectedJob; })[0] || list[0] || null;
  }

  function renderLive() {
    var live = $('fwLive'), text = $('fwLiveText');
    if (failed) { live.className = 'fw-live off'; text.textContent = 'Can\'t reach the server — retrying'; return; }
    if (!state) return;
    var n = (state.servers || []).length;
    live.className = 'fw-live ' + (n ? 'on' : '');
    var age = Math.round((Date.now() - fetchedAt) / 1000);
    text.textContent = (n ? 'Live' : 'No live servers') + ' · updated ' + (age < 2 ? 'just now' : age + 's ago');
  }

  function render() {
    if (!state) return;
    $('fwSetup').hidden = state.configured;
    var players = allPlayers();
    $('fwStatPlayers').textContent = players.length;
    $('fwStatServers').textContent = (state.servers || []).length;
    $('fwStatGrants').textContent = (state.grants || []).length;
    $('fwStatWeather').textContent = state.weather.override ? label(state.weather.override) : 'Auto';
    renderLive();
    renderPlayers();
    renderServers();
    renderWeather();
    renderProducts();
    if (reduceMotion && tab === 'weather') drawRadar(0);
  }

  function renderPlayers() {
    var q = filter.toLowerCase();
    var rows = allPlayers().filter(function (e) {
      return !q || (e.p.name + ' ' + e.p.displayName + ' ' + e.p.userId).toLowerCase().indexOf(q) >= 0;
    }).sort(function (a, b) { return (a.p.displayName || a.p.name).localeCompare(b.p.displayName || b.p.name); });
    var body = $('fwPlayers');
    if (!rows.length) {
      body.innerHTML = '<tr><td colspan="6"><div class="fw-empty">' + (q
        ? '<b>No matching players</b>Try another name or user ID.'
        : '<b>Nobody is playing right now</b>Players show up here within 15 seconds of joining.') + '</div></td></tr>';
      return;
    }
    body.innerHTML = rows.map(function (e) {
      var g = grantsFor(e.p.userId).map(function (x) { return '<span class="fw-chip">' + esc(passName(x.pass)) + '</span>'; }).join('');
      var joined = e.p.joinedAt ? dur(now() / 1000 - e.p.joinedAt) : '—';
      return '<tr><td>' + who(e.p) + '</td>' +
        '<td class="num">' + Number(e.p.userId) + '</td>' +
        '<td><span class="fw-job" title="' + esc(e.s.jobId) + '">' + esc(shortJob(e.s.jobId)) + '</span></td>' +
        '<td class="num" data-joined="' + Number(e.p.joinedAt || 0) + '">' + joined + '</td>' +
        '<td>' + (g || '<span class="muted">—</span>') + '</td>' +
        '<td class="actions-cell"><button type="button" class="btn btn-ghost btn-sm fw-row-btn" data-grant="' +
        esc(e.p.name) + '">Grant pass</button></td></tr>';
    }).join('');
  }

  function renderServers() {
    var list = state.servers || [];
    var body = $('fwServers');
    if (!list.length) {
      body.innerHTML = '<tr><td colspan="5"><div class="fw-empty"><b>No live servers</b>' +
        (state.configured ? 'Servers report every 15 seconds once the game is running.' : 'Finish connecting the game above.') +
        '</div></td></tr>';
      return;
    }
    body.innerHTML = list.map(function (s) {
      var tags = (s.studio ? ' <span class="fw-chip muted-chip">Studio</span>' : '') +
        (s.privateServer ? ' <span class="fw-chip muted-chip">Private</span>' : '');
      var kind = s.weather.kind;
      return '<tr><td><span class="fw-job">' + esc(s.jobId) + '</span>' + tags + '</td>' +
        '<td class="num">' + s.players.length + '</td>' +
        '<td><span class="fw-chip kind-' + esc(kind) + '">' + esc(label(kind)) + (s.weather.override ? ' · locked' : '') + '</span></td>' +
        '<td class="num">' + (s.startedAt ? dur(now() / 1000 - s.startedAt) : '—') + '</td>' +
        '<td class="num" data-seen="' + s.seenAt + '">' + ago(s.seenAt) + '</td></tr>';
    }).join('');
  }

  function compass(deg) {
    var names = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    return names[Math.round(((deg % 360) + 360) % 360 / 45) % 8];
  }
  // Roblox X runs east and Z south; windAngle is the heading in the X/Z plane.
  function bearingOf(windAngle) {
    var a = windAngle * Math.PI / 180;
    return (Math.atan2(Math.cos(a), -Math.sin(a)) * 180 / Math.PI + 360) % 360;
  }

  function renderWeather() {
    var list = state.servers || [];
    var pick = $('fwServerPick');
    if (list.length > 1) {
      pick.innerHTML = list.map(function (s) {
        var on = server() === s;
        return '<button type="button" class="fw-seg" data-job="' + esc(s.jobId) + '" aria-pressed="' + on + '">' +
          esc(shortJob(s.jobId)) + ' · ' + s.players.length + (s.players.length === 1 ? ' player' : ' players') + '</button>';
      }).join('');
    } else pick.innerHTML = '';

    var s = server();
    $('fwRadarEmpty').hidden = !!s;
    var nowBox = $('fwNow');
    if (!s) {
      nowBox.innerHTML = '<div class="muted">Waiting for a live server…</div>';
    } else {
      var w = s.weather, from = compass(bearingOf(w.windAngle) + 180);
      nowBox.innerHTML = '<div class="fw-now-head"><div class="fw-now-ico">' + (ICONS[w.kind] || ICONS.Clear) + '</div>' +
        '<div><div class="fw-now-kind">' + esc(label(w.kind)) + '</div><div class="fw-now-sub">' +
        (w.override ? 'Locked by an override' : 'Following the forecast') + (list.length > 1 ? ' · server ' + esc(shortJob(s.jobId)) : '') +
        '</div></div></div><div class="fw-meters">' +
        meter('Rain', Math.round(w.rain * 100) + '%', w.rain) +
        meter('Cloud cover', Math.round(w.cloudCover * 100) + '%', w.cloudCover) +
        meter('Wind', Math.round(w.windSpeed) + ' studs/s · from ' + from, w.windSpeed / 56) +
        meter('Swell', w.waveAmplitude.toFixed(2) + ' studs', w.waveAmplitude / 0.72) +
        '</div>';
      $('fwRadar').setAttribute('aria-label', 'Weather radar: ' + label(w.kind) + ', rain ' + Math.round(w.rain * 100) +
        '%, wind ' + Math.round(w.windSpeed) + ' studs per second from the ' + from + ', ' + s.players.length + ' players shown.');
    }

    var kinds = ['Auto'].concat(state.weather.kinds || []);
    var active = state.weather.override || 'Auto';
    var box = $('fwKinds');
    if (box.dataset.kinds !== kinds.join()) {
      box.dataset.kinds = kinds.join();
      box.innerHTML = kinds.map(function (k) {
        return '<button type="button" class="fw-kind" role="radio" data-kind="' + esc(k) + '">' +
          (ICONS[k] || ICONS.Clear) + '<span>' + esc(label(k === 'Auto' ? '' : k)) + '</span></button>';
      }).join('');
    }
    box.querySelectorAll('.fw-kind').forEach(function (b) {
      var on = b.dataset.kind === active;
      b.setAttribute('aria-checked', String(on));
      b.tabIndex = on ? 0 : -1;
    });
    var note = $('fwWeatherNote');
    if (state.weather.override) {
      note.className = 'fw-note lock';
      note.innerHTML = 'Every server is locked to <b>' + esc(label(state.weather.override)) + '</b>' +
        (state.weather.setAt ? ' (set ' + esc(ago(state.weather.setAt)) + ')' : '') + '. Pick <b>Auto</b> to resume the forecast.';
    } else {
      note.className = 'fw-note';
      note.innerHTML = 'Following the built-in forecast. Picking a type locks every live server to it within 15 seconds.';
    }
    renderForecast(s);
  }
  function meter(k, v, f) {
    f = Math.max(0, Math.min(1, f || 0));
    return '<div class="fw-meter"><div class="k">' + k + '</div><div class="v">' + esc(v) + '</div>' +
      '<div class="bar"><i style="width:' + (f * 100).toFixed(1) + '%"></i></div></div>';
  }

  function renderForecast(s) {
    var box = $('fwForecast');
    var schedule = state.weather.schedule || [];
    if (!s || !schedule.length) { box.innerHTML = '<div class="muted">No forecast yet.</div>'; return; }
    var total = schedule.reduce(function (a, x) { return a + x.duration; }, 0);
    var elapsed = (s.weather.cycleElapsed + (now() - s.seenAt) / 1000) % total;
    var idx = 0, into = elapsed;
    while (idx < schedule.length - 1 && into >= schedule[idx].duration) { into -= schedule[idx].duration; idx++; }
    var locked = !!s.weather.override;
    var bar = '<div class="fw-timeline' + (locked ? ' paused' : '') + '" aria-hidden="true">' +
      schedule.map(function (x) {
        return '<span style="width:' + (x.duration / total * 100).toFixed(2) + '%;background:' + (KIND_COLOR[x.kind] || '#6f688a') + '"></span>';
      }).join('') + '<i class="now" style="left:' + (elapsed / total * 100).toFixed(2) + '%"></i></div>' +
      '<div class="fw-tl-scale"><span>Cycle start</span><span>' + dur(total) + ' cycle</span></div>';
    var items = [];
    var t = schedule[idx].duration - into;
    items.push('<li class="current">' + (ICONS[schedule[idx].kind] || '') + '<span>' + esc(label(schedule[idx].kind)) +
      ' <span class="muted">now</span></span><span class="when">' + dur(t) + ' left</span></li>');
    for (var i = 1; i <= 3; i++) {
      var st = schedule[(idx + i) % schedule.length];
      items.push('<li>' + (ICONS[st.kind] || '') + '<span>' + esc(label(st.kind)) + '</span><span class="when">in ' + dur(t) + '</span></li>');
      t += st.duration;
    }
    box.innerHTML = bar + (locked
      ? '<p class="fw-note lock" style="margin-top:0">The forecast is paused while this server is locked to ' + esc(label(s.weather.override)) + '.</p>'
      : '<ul class="fw-upcoming">' + items.join('') + '</ul>');
  }

  function renderProducts() {
    var passes = state.passes || [];
    var counts = {};
    (state.grants || []).forEach(function (g) { counts[g.pass] = (counts[g.pass] || 0) + 1; });
    $('fwPasses').innerHTML = passes.map(function (p) {
      return '<div class="fw-pass"><div class="fw-pass-ico">' + ICONS.Pass + '</div><div><b>' + esc(p.name) + '</b>' +
        '<small>ID ' + Number(p.id) + '</small>' +
        (p.id ? '<a href="https://www.roblox.com/game-pass/' + Number(p.id) + '" target="_blank" rel="noopener noreferrer">View on Roblox</a>' : '') +
        '</div><div class="count"><b>' + (counts[p.key] || 0) + '</b><small>granted</small></div></div>';
    }).join('');

    var select = $('fwGrantPass'), keep = select.value;
    var opts = passes.map(function (p) { return '<option value="' + esc(p.key) + '">' + esc(p.name) + '</option>'; }).join('');
    if (select.dataset.opts !== opts) { select.innerHTML = opts; select.dataset.opts = opts; if (keep) select.value = keep; }

    var names = {};
    allPlayers().forEach(function (e) { names[e.p.name] = e.p.displayName; });
    $('fwOnlineNames').innerHTML = Object.keys(names).sort().map(function (n) {
      return '<option value="' + esc(n) + '">' + esc(names[n]) + '</option>';
    }).join('');

    var online = onlineIds();
    var grants = state.grants || [];
    $('fwGrants').innerHTML = grants.length ? grants.map(function (g) {
      return '<tr><td>' + who(g) + '</td><td><span class="fw-chip">' + esc(passName(g.pass)) + '</span></td>' +
        '<td class="num">' + esc(ago(g.grantedAt)) + '</td>' +
        '<td><span class="fw-status' + (online[g.userId] ? ' on">In game' : '">Offline') + '</span></td>' +
        '<td class="actions-cell"><button type="button" class="btn btn-danger btn-sm fw-row-btn" data-revoke="' + Number(g.userId) +
        '" data-pass="' + esc(g.pass) + '" data-name="' + esc(g.name) + '">Revoke</button></td></tr>';
    }).join('') : '<tr><td colspan="5"><div class="fw-empty"><b>No grants yet</b>Grant a gamepass above and it shows up here.</div></td></tr>';
  }

  // Keeps the relative times moving between polls.
  function tick() {
    renderLive();
    if (!state) return;
    root.querySelectorAll('[data-seen]').forEach(function (td) { td.textContent = ago(Number(td.dataset.seen)); });
    root.querySelectorAll('[data-joined]').forEach(function (td) {
      var j = Number(td.dataset.joined);
      if (j) td.textContent = dur(now() / 1000 - j);
    });
    if (tab === 'weather' && !document.hidden) renderForecast(server());
  }

  // ---- interactions ------------------------------------------------------
  $('fwSearch').addEventListener('input', function (e) { filter = e.target.value.trim(); if (state) renderPlayers(); });
  $('fwServerPick').addEventListener('click', function (e) {
    var b = e.target.closest('[data-job]');
    if (b) { selectedJob = b.dataset.job; renderWeather(); }
  });
  $('fwRange').addEventListener('click', function (e) {
    var b = e.target.closest('[data-range]');
    if (!b) return;
    range = b.dataset.range;
    this.querySelectorAll('.fw-seg').forEach(function (x) { x.setAttribute('aria-pressed', String(x === b)); });
    if (reduceMotion) drawRadar(performance.now());
  });
  $('fwKinds').addEventListener('click', function (e) {
    var b = e.target.closest('.fw-kind');
    if (!b || b.getAttribute('aria-checked') === 'true') return;
    var buttons = this.querySelectorAll('.fw-kind');
    buttons.forEach(function (x) { x.disabled = true; });
    post('/admin/fishing-waters/weather', { kind: b.dataset.kind })
      .catch(function (err) { alert(err.message); })
      .then(function () { buttons.forEach(function (x) { x.disabled = false; }); });
  });
  $('fwKinds').addEventListener('keydown', function (e) {
    if (['ArrowRight', 'ArrowLeft', 'ArrowDown', 'ArrowUp'].indexOf(e.key) < 0) return;
    var buttons = Array.prototype.slice.call(this.querySelectorAll('.fw-kind'));
    var i = buttons.indexOf(document.activeElement);
    if (i < 0) return;
    e.preventDefault();
    buttons[(i + (e.key === 'ArrowRight' || e.key === 'ArrowDown' ? 1 : -1) + buttons.length) % buttons.length].focus();
  });
  root.addEventListener('click', function (e) {
    var g = e.target.closest('[data-grant]');
    if (g) {
      activate('products', true);
      $('fwGrantUser').value = g.dataset.grant;
      $('fwGrantPass').focus();
      return;
    }
    var r = e.target.closest('[data-revoke]');
    if (r) {
      if (!confirm('Revoke ' + passName(r.dataset.pass) + ' from @' + r.dataset.name + '? They lose its benefit straight away if they\'re online.')) return;
      r.disabled = true;
      post('/admin/fishing-waters/grants/revoke', { userId: Number(r.dataset.revoke), pass: r.dataset.pass })
        .catch(function (err) { r.disabled = false; alert(err.message); });
    }
  });
  $('fwGrantForm').addEventListener('submit', function (e) {
    e.preventDefault();
    var input = $('fwGrantUser'), msg = $('fwGrantMsg'), btn = $('fwGrantBtn');
    var user = input.value.trim();
    if (!user) {
      input.setAttribute('aria-invalid', 'true');
      msg.className = 'fw-msg err'; msg.textContent = 'Enter a Roblox username or user ID.';
      input.focus();
      return;
    }
    input.removeAttribute('aria-invalid');
    btn.disabled = true; btn.textContent = 'Granting…';
    msg.className = 'fw-msg'; msg.textContent = '';
    var pass = $('fwGrantPass').value;
    post('/admin/fishing-waters/grants', { user: user, pass: pass })
      .then(function (json) {
        var g = (json.grants || [])[0];
        msg.className = 'fw-msg ok';
        msg.textContent = 'Granted ' + passName(pass) + (g ? ' to @' + g.name : '') + '.';
        input.value = '';
      })
      .catch(function (err) {
        input.setAttribute('aria-invalid', 'true');
        msg.className = 'fw-msg err'; msg.textContent = err.message;
        input.focus();
      })
      .then(function () { btn.disabled = false; btn.textContent = 'Grant'; });
  });

  // ---- radar -------------------------------------------------------------
  // Sketch coordinates of the main island (Harbour.OUTER / Weather.BaySketch)
  // in world studs: (p - (870, 1330)) * 1.05.
  var OUTER = [[430,1340],[372,1290],[330,1200],[312,1090],[318,970],[345,860],[395,760],[450,680],[530,610],[640,555],[780,528],[950,532],[1120,552],[1270,575],[1350,610],[1405,690],[1445,800],[1475,950],[1490,1120],[1488,1320],[1470,1520],[1430,1700],[1360,1860],[1260,1990],[1120,2080],[950,2130],[760,2140],[580,2110],[430,2050],[320,1960],[262,1850],[250,1740],[265,1640],[290,1565]];
  var BAY = [[290,1565],[350,1555],[450,1553],[550,1565],[650,1598],[760,1640],[850,1640],[950,1620],[1030,1630],[1100,1668],[1170,1690],[1240,1660],[1305,1585],[1345,1480],[1362,1360],[1348,1262],[1290,1182],[1200,1122],[1105,1090],[1045,1050],[1012,980],[985,902],[940,852],[870,818],[760,820],[685,850],[652,905],[663,1000],[680,1118],[660,1190],[600,1255],[520,1300],[430,1340]];
  function world(p) { return [(p[0] - 870) * 1.05, (p[1] - 1330) * 1.05]; }
  var ISLAND = OUTER.map(world), LAKE = BAY.map(world);
  var BIOMES = [
    { name: 'Gullhaven Sound', x: 0, z: 0, r: 1300 },
    { name: 'The Sodden Mire', x: -3700, z: -200, r: 1250 },
    { name: 'Coral Shallows', x: -200, z: 3700, r: 1300 },
    { name: 'Cinder Isles', x: 3700, z: 300, r: 1250 },
    { name: 'Frostmere Expanse', x: 300, z: -3700, r: 1300 }
  ];
  var RANGES = { harbour: 1100, world: 5300 };
  var cells = null, cellSeed = null, rafId = 0;

  function rng(seed) {
    var s = (seed >>> 0) || 1;
    return function () { s = (s * 1664525 + 1013904223) >>> 0; return s / 4294967296; };
  }
  function makeCells(seed) {
    var r = rng(seed), out = [];
    for (var i = 0; i < 90; i++) out.push({ x: r(), y: r(), size: 0.06 + r() * 0.16, w: r(), heat: r(), core: r() });
    return out;
  }
  function rainColor(v) {
    return v < 0.3 ? [53, 180, 90] : v < 0.55 ? [196, 217, 58] : v < 0.8 ? [242, 184, 75] : [236, 95, 95];
  }

  function radarLoop() {
    cancelAnimationFrame(rafId);
    var visible = !root.hidden && tab === 'weather' && !document.hidden;
    if (!visible) return;
    if (reduceMotion) { drawRadar(0); return; }
    (function frame(t) { drawRadar(t); rafId = requestAnimationFrame(frame); })(performance.now());
  }

  function drawRadar(t) {
    var canvas = $('fwRadar');
    var size = canvas.clientWidth;
    if (!size) return;
    var dpr = Math.min(window.devicePixelRatio || 1, 2);
    if (canvas.width !== Math.round(size * dpr)) { canvas.width = Math.round(size * dpr); canvas.height = Math.round(size * dpr); }
    var ctx = canvas.getContext('2d');
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.clearRect(0, 0, size, size);
    var c = size / 2, rad = c - 18, R = RANGES[range], k = rad / R;
    function px(x, z) { return [c + x * k, c + z * k]; }

    ctx.save();
    ctx.beginPath(); ctx.arc(c, c, rad, 0, Math.PI * 2); ctx.clip();
    var bg = ctx.createRadialGradient(c, c, 0, c, c, rad);
    bg.addColorStop(0, '#0c2430'); bg.addColorStop(1, '#071520');
    ctx.fillStyle = bg; ctx.fillRect(0, 0, size, size);

    // Land
    function poly(points, fill, stroke) {
      ctx.beginPath();
      points.forEach(function (p, i) { var q = px(p[0], p[1]); i ? ctx.lineTo(q[0], q[1]) : ctx.moveTo(q[0], q[1]); });
      ctx.closePath();
      if (fill) { ctx.fillStyle = fill; ctx.fill(); }
      if (stroke) { ctx.strokeStyle = stroke; ctx.lineWidth = 1.2; ctx.stroke(); }
    }
    if (range === 'world') {
      ctx.setLineDash([4, 5]);
      BIOMES.forEach(function (b) {
        var q = px(b.x, b.z);
        ctx.beginPath(); ctx.arc(q[0], q[1], b.r * k, 0, Math.PI * 2);
        ctx.strokeStyle = 'rgba(143,225,239,.22)'; ctx.lineWidth = 1; ctx.stroke();
      });
      ctx.setLineDash([]);
    }
    poly(ISLAND, '#1b3a2d', '#3d7357');
    poly(LAKE, '#0a2230', 'rgba(61,115,87,.6)');

    // Precipitation: a seeded field of cells drifting with the server's wind.
    var s = server();
    if (s) {
      var w = s.weather;
      if (cellSeed !== w.seed) { cells = makeCells(w.seed); cellSeed = w.seed; }
      var span = rad * 2.6, a = w.windAngle * Math.PI / 180;
      var drift = (t / 1000) * w.windSpeed * 0.9 * (1100 / R) * k;
      var coverage = Math.min(1, w.cloudCover * 0.45 + w.rain * 0.7);
      var dx = Math.cos(a) * drift, dy = Math.sin(a) * drift;
      cells.forEach(function (cell) {
        if (cell.w > coverage) return;
        var x = ((cell.x * span + dx) % span + span) % span - span / 2 + c;
        var y = ((cell.y * span + dy) % span + span) % span - span / 2 + c;
        var r = cell.size * rad * (0.8 + w.cloudCover * 0.5);
        var g = ctx.createRadialGradient(x, y, 0, x, y, r);
        if (w.rain < 0.05) {
          g.addColorStop(0, 'rgba(180,195,210,' + (0.16 * w.cloudCover) + ')');
          g.addColorStop(1, 'rgba(180,195,210,0)');
        } else {
          var v = Math.min(1, w.rain * (0.45 + cell.heat * 0.55) + w.storm * cell.core * 0.4);
          var col = rainColor(v).join(',');
          g.addColorStop(0, 'rgba(' + col + ',.78)');
          g.addColorStop(0.55, 'rgba(' + col + ',.38)');
          g.addColorStop(1, 'rgba(' + col + ',0)');
        }
        ctx.fillStyle = g;
        ctx.beginPath(); ctx.arc(x, y, r, 0, Math.PI * 2); ctx.fill();
      });
    }

    // Range rings and crosshair
    ctx.strokeStyle = 'rgba(143,225,239,.14)'; ctx.lineWidth = 1;
    for (var i = 1; i <= 3; i++) { ctx.beginPath(); ctx.arc(c, c, rad * i / 3, 0, Math.PI * 2); ctx.stroke(); }
    ctx.beginPath(); ctx.moveTo(c - rad, c); ctx.lineTo(c + rad, c); ctx.moveTo(c, c - rad); ctx.lineTo(c, c + rad); ctx.stroke();

    // Sweep
    if (!reduceMotion && ctx.createConicGradient) {
      var ang = (t / 1000 * 1.1) % (Math.PI * 2);
      var sweep = ctx.createConicGradient(ang - 0.9, c, c);
      sweep.addColorStop(0, 'rgba(76,195,217,0)');
      sweep.addColorStop(0.143, 'rgba(76,195,217,.16)');
      sweep.addColorStop(0.144, 'rgba(76,195,217,0)');
      ctx.fillStyle = sweep;
      ctx.beginPath(); ctx.moveTo(c, c); ctx.arc(c, c, rad, ang - 0.9, ang); ctx.closePath(); ctx.fill();
      ctx.strokeStyle = 'rgba(143,225,239,.55)';
      ctx.beginPath(); ctx.moveTo(c, c); ctx.lineTo(c + Math.cos(ang) * rad, c + Math.sin(ang) * rad); ctx.stroke();
    }

    // Labels and players
    ctx.font = '600 11px ui-sans-serif,system-ui,Segoe UI,sans-serif';
    ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
    if (range === 'world') {
      BIOMES.forEach(function (b) {
        var q = px(b.x, b.z);
        ctx.fillStyle = 'rgba(191,240,248,.7)';
        ctx.fillText(b.name, q[0], b.z === 0 ? q[1] + b.r * k + 10 : q[1]);
      });
    }
    if (s) {
      var many = s.players.length > 12;
      s.players.forEach(function (p) {
        if (p.x == null || p.z == null) return;
        var q = px(p.x, p.z);
        ctx.beginPath(); ctx.arc(q[0], q[1], 6, 0, Math.PI * 2); ctx.fillStyle = 'rgba(76,195,217,.35)'; ctx.fill();
        ctx.beginPath(); ctx.arc(q[0], q[1], 3, 0, Math.PI * 2); ctx.fillStyle = '#fff'; ctx.fill();
        if (!many) {
          ctx.fillStyle = 'rgba(236,232,247,.92)';
          ctx.fillText(p.displayName || p.name, q[0], q[1] - 13);
        }
      });
    }
    ctx.restore();

    // Bezel, compass points and range label
    ctx.beginPath(); ctx.arc(c, c, rad, 0, Math.PI * 2);
    ctx.strokeStyle = '#2a4a55'; ctx.lineWidth = 1.5; ctx.stroke();
    ctx.fillStyle = '#8d86a8';
    ctx.font = '600 11px ui-sans-serif,system-ui,Segoe UI,sans-serif';
    ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
    ctx.fillText('N', c, 9); ctx.fillText('S', c, size - 9);
    ctx.fillText('W', 8, c); ctx.fillText('E', size - 8, c);
    ctx.textAlign = 'left';
    ctx.fillStyle = 'rgba(143,225,239,.55)';
    ctx.fillText(Math.round(R / 3).toLocaleString() + ' studs/ring', c + 6, c - rad / 3 - 8);

    // Wind arrow
    if (s) {
      var wa = s.weather.windAngle * Math.PI / 180, ax = size - 34, ay = 34;
      ctx.beginPath(); ctx.arc(ax, ay, 20, 0, Math.PI * 2);
      ctx.fillStyle = 'rgba(15,13,23,.85)'; ctx.fill();
      ctx.strokeStyle = '#2a4a55'; ctx.lineWidth = 1; ctx.stroke();
      ctx.save(); ctx.translate(ax, ay); ctx.rotate(wa);
      ctx.strokeStyle = '#bff0f8'; ctx.fillStyle = '#bff0f8'; ctx.lineWidth = 2;
      ctx.beginPath(); ctx.moveTo(-11, 0); ctx.lineTo(8, 0); ctx.stroke();
      ctx.beginPath(); ctx.moveTo(12, 0); ctx.lineTo(5, -4.5); ctx.lineTo(5, 4.5); ctx.closePath(); ctx.fill();
      ctx.restore();
      ctx.textAlign = 'center'; ctx.fillStyle = '#8d86a8';
      ctx.fillText('wind', ax, ay + 30);
    }
  }
  window.addEventListener('resize', function () { if (reduceMotion) drawRadar(0); });
})();
''';
}
