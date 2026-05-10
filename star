<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no">
<meta name="referrer" content="no-referrer">
<title>Sports Live</title>
<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/shaka-player@4.16.2/dist/controls.css">
<style>
*{margin:0;padding:0;box-sizing:border-box}
html,body{width:100%;height:100%;background:#0a0a0a;overflow:hidden;font-family:'Segoe UI',Roboto,Helvetica,Arial,sans-serif;-webkit-user-select:none;user-select:none;-webkit-touch-callout:none}

#overlay{position:fixed;inset:0;background:#0a0a0a;z-index:9999;display:flex;align-items:center;justify-content:center;flex-direction:column;gap:14px}
#overlay svg{animation:spin 1s linear infinite}
@keyframes spin{to{transform:rotate(360deg)}}
#overlay p{color:#555;font-size:13px;letter-spacing:.4px;text-align:center;padding:0 20px}

#channel-list{position:fixed;inset:0;background:#0a0a0a;z-index:9998;display:none;flex-direction:column;overflow-y:auto;padding:24px 16px}
#channel-list h1{color:#fff;font-size:15px;font-weight:600;letter-spacing:.5px;margin-bottom:18px;padding-bottom:10px;border-bottom:1px solid #1e1e1e;text-align:center}
#ch-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(140px,1fr));gap:10px}
.ch-card{background:#141414;border:1px solid #1e1e1e;border-radius:8px;padding:14px 10px;cursor:pointer;text-decoration:none;display:flex;align-items:center;justify-content:center;text-align:center;transition:background .2s,border-color .2s;-webkit-tap-highlight-color:transparent}
.ch-card:hover{background:#1c1c1c;border-color:#333}
.ch-card:active{background:#222}
.ch-card span{color:#e0e0e0;font-size:12px;font-weight:500;line-height:1.4}

#pc{position:fixed;inset:0;background:#000;display:none;align-items:center;justify-content:center;touch-action:manipulation}
video{width:100%;height:100%;object-fit:contain;background:#000}
video.mode-fill{object-fit:fill}
video.mode-cover{object-fit:cover}

#status{position:fixed;top:0;right:0;z-index:9997;padding:5px 10px;background:rgba(0,0,0,0.82);font-size:10px;letter-spacing:.04em;border-bottom-left-radius:6px;pointer-events:none;opacity:0;transition:opacity .4s ease;max-width:280px;text-align:right;line-height:1.5}
#status.show{opacity:1}
#status.ok{color:#4ade80}
#status.warn{color:#facc15}
#status.err{color:#f87171}

.shaka-fit-btn{background:transparent!important;border:none!important;cursor:pointer!important;padding:0 7px!important;opacity:.85;display:flex;align-items:center;justify-content:center;height:100%}
.shaka-fit-btn:hover{opacity:1}
.shaka-fit-btn svg{width:20px;height:20px;display:block}
</style>
</head>
<body>

<div id="overlay">
  <svg width="40" height="40" viewBox="0 0 40 40" fill="none">
    <circle cx="20" cy="20" r="16" stroke="#222" stroke-width="4"/>
    <path d="M20 4a16 16 0 0 1 16 16" stroke="#e74c3c" stroke-width="4" stroke-linecap="round"/>
  </svg>
  <p id="loadMsg">Loading...</p>
</div>

<div id="status"></div>

<div id="channel-list">
  <h1>&#9654; Sports Live</h1>
  <div id="ch-grid"></div>
</div>

<div id="pc">
  <video id="v" autoplay muted playsinline webkit-playsinline preload="metadata"></video>
</div>

<script src="https://cdn.jsdelivr.net/npm/shaka-player@4.16.2/dist/shaka-player.ui.min.js"></script>
<script>
(function() {
"use strict";

var API_URL = "https://sayan-json-3.pages.dev/Data/sports.json";

var overlayEl  = document.getElementById("overlay");
var loadMsgEl  = document.getElementById("loadMsg");
var statusEl   = document.getElementById("status");
var listEl     = document.getElementById("channel-list");
var gridEl     = document.getElementById("ch-grid");
var pcEl       = document.getElementById("pc");
var vidEl      = document.getElementById("v");

var stTimer    = null;

var FIT_MODES  = ["contain", "fill", "cover"];
var FIT_ICONS  = {
  contain: '<svg viewBox="0 0 24 24" fill="none"><rect x="3" y="6" width="18" height="12" rx="1" stroke="rgba(255,255,255,0.9)" stroke-width="1.6"/><rect x="6" y="9" width="12" height="6" rx=".5" fill="rgba(255,255,255,0.22)"/></svg>',
  fill:    '<svg viewBox="0 0 24 24" fill="none"><rect x="3" y="3" width="18" height="18" rx="1" stroke="rgba(255,255,255,0.9)" stroke-width="1.6"/><rect x="3" y="3" width="18" height="18" rx="1" fill="rgba(255,255,255,0.18)"/><path d="M3 9h18M3 15h18M9 3v18M15 3v18" stroke="rgba(255,255,255,0.3)" stroke-width="1"/></svg>',
  cover:   '<svg viewBox="0 0 24 24" fill="none"><rect x="3" y="3" width="18" height="18" rx="1" stroke="rgba(255,255,255,0.9)" stroke-width="1.6"/><rect x="5" y="5" width="14" height="14" rx=".5" fill="rgba(255,255,255,0.22)"/><path d="M3 3l4 4M21 3l-4 4M3 21l4-4M21 21l-4-4" stroke="rgba(255,255,255,0.55)" stroke-width="1.4" stroke-linecap="round"/></svg>'
};

function showStatus(msg, type, dur) {
  statusEl.textContent = msg;
  statusEl.className = "show " + (type || "ok");
  if (stTimer) clearTimeout(stTimer);
  if (dur !== 0) {
    stTimer = setTimeout(function() {
      statusEl.className = statusEl.className.replace("show","").trim();
      stTimer = null;
    }, dur || 4000);
  }
}

function setLoadMsg(msg) { if (loadMsgEl) loadMsgEl.textContent = msg; }
function hideOverlay()   { if (overlayEl) overlayEl.style.display = "none"; }

function getChannelId() {
  return new URLSearchParams(location.search).get("id") || "";
}

function extractRawCookie(cookie) {
  return cookie && cookie.startsWith("__hdnea__=") ? cookie.substring(10) : (cookie || "");
}

function appendCookieToUri(uri, rawCookie) {
  if (!uri || !rawCookie) return uri;
  if (uri.indexOf("__hdnea__") !== -1) return uri;
  return uri + (uri.indexOf("?") !== -1 ? "&" : "?") + "__hdnea__=" + rawCookie;
}

async function fetchSportsData() {
  var res = await fetch(API_URL, { cache: "no-store", headers: { "Accept": "application/json" } });
  if (!res.ok) throw new Error("HTTP " + res.status);
  var d = await res.json();
  if (!d || !Array.isArray(d.channels) || d.channels.length === 0) throw new Error("No channels in response");
  return d;
}

function showChannelList(channels) {
  hideOverlay();
  channels.forEach(function(ch) {
    var a = document.createElement("a");
    a.className = "ch-card";
    a.href = "?id=" + encodeURIComponent(ch.id);
    a.innerHTML = "<span>" + ch.name + "</span>";
    gridEl.appendChild(a);
  });
  listEl.style.display = "flex";
}

function showErrorMsg(msg) {
  hideOverlay();
  setLoadMsg(msg);
  overlayEl.style.display = "flex";
  showStatus(msg, "err", 0);
}

function shakaErrStr(err) {
  if (!err) return "Unknown error";
  var cats = {1:"Network",2:"Text",3:"Media",4:"Manifest",5:"Streaming",6:"DRM",7:"Player"};
  var s = (cats[err.category] || "Error") + " " + (err.category||"?") + ":" + (err.code||"?");
  if (err.data && err.data[0]) {
    var d = err.data[0];
    if (typeof d === "string" && d.length) s += " — " + d.slice(0,80);
  }
  return s;
}

function injectFitButton(container, video) {
  var panel = container.querySelector(".shaka-controls-button-panel");
  if (!panel) return;

  var modeIdx = 0;

  var btn = document.createElement("button");
  btn.className = "shaka-fit-btn";
  btn.title = "Toggle Fit Mode";
  btn.innerHTML = FIT_ICONS.contain;

  var anchor = panel.querySelector(".shaka-fullscreen-button");
  if (anchor) panel.insertBefore(btn, anchor);
  else panel.appendChild(btn);

  function applyMode(idx) {
    modeIdx = idx;
    var m = FIT_MODES[idx];
    video.classList.remove("mode-fill", "mode-cover");
    if (m === "fill")  video.classList.add("mode-fill");
    if (m === "cover") video.classList.add("mode-cover");
    btn.innerHTML = FIT_ICONS[m];
    btn.title = m === "contain" ? "Fit (tap: Stretch)" : m === "fill" ? "Stretch (tap: Zoom)" : "Zoom (tap: Fit)";
  }

  btn.addEventListener("click", function(e) {
    e.stopPropagation();
    applyMode((modeIdx + 1) % FIT_MODES.length);
  });

  ["fullscreenchange","webkitfullscreenchange","mozfullscreenchange","MSFullscreenChange"].forEach(function(ev) {
    document.addEventListener(ev, function() {
      var inFs = !!(document.fullscreenElement || document.webkitFullscreenElement || document.mozFullScreenElement || document.msFullscreenElement);
      if (!inFs) applyMode(0);
    });
  });
}

async function startPlayer(ch) {
  pcEl.style.display = "flex";

  shaka.polyfill.installAll();

  if (!shaka.Player.isBrowserSupported()) {
    showErrorMsg("Browser not supported — use Chrome, Firefox or Edge.");
    return;
  }

  var player = new shaka.Player();
  await player.attach(vidEl);

  var ui = new shaka.ui.Overlay(player, pcEl, vidEl);
  ui.configure({
    controlPanelElements: ["mute","play_pause","time_and_duration","spacer","quality","picture_in_picture","fullscreen"],
    seekBarColors: { base:"#9c9a9a", buffered:"#c90000", played:"#00ab17" }
  });

  setTimeout(function() { injectFitButton(pcEl, vidEl); }, 80);

  var activeCookie = ch.cookie;
  var activeRaw    = extractRawCookie(activeCookie);
  var activeKeyId  = ch.key_id;
  var activeKey    = ch.key;
  var activeUrl    = ch.stream_url;

  function applyConfig() {
    player.configure({
      drm: { clearKeys: { [activeKeyId]: activeKey } },
      manifest: {
        defaultPresentationDelay: 5,
        retryParameters: { maxAttempts:3, baseDelay:1000, backoffFactor:2, fuzzFactor:0.5 }
      },
      streaming: {
        lowLatencyMode:  true,
        bufferingGoal:   12,
        rebufferingGoal: 2,
        safeSeekOffset:  5,
        retryParameters: { maxAttempts:4, baseDelay:1000, backoffFactor:2, fuzzFactor:0.5 }
      }
    });
  }

  applyConfig();

  var T = shaka.net.NetworkingEngine.RequestType;
  player.getNetworkingEngine().registerRequestFilter(function(type, req) {
    req.headers["Referer"]    = "https://www.jiotv.com/";
    req.headers["User-Agent"] = "plaYtv/7.1.5 (Linux;Android 13) ExoPlayerLib/2.11.6";
    req.headers["Cookie"]     = activeCookie;
    if (type === T.MANIFEST || type === T.SEGMENT) {
      req.uris = req.uris.map(function(u) { return appendCookieToUri(u, activeRaw); });
    }
  });

  var isRefreshing = false;
  var refreshCount = 0;

  async function refreshAndReload(reason) {
    if (isRefreshing) return;
    if (refreshCount >= 4) {
      showStatus("Stream down — reload the page.", "err", 0);
      return;
    }
    isRefreshing = true;
    refreshCount++;
    showStatus("Reconnecting (" + refreshCount + "/4)...", "warn", 0);
    try {
      var data = await fetchSportsData();
      var fresh = data.channels.find(function(c) { return c.id === ch.id; });
      if (!fresh) throw new Error("Channel not found in refresh");
      activeCookie = fresh.cookie;
      activeRaw    = extractRawCookie(activeCookie);
      activeKeyId  = fresh.key_id;
      activeKey    = fresh.key;
      activeUrl    = fresh.stream_url;
      applyConfig();
      await player.load(activeUrl);
      vidEl.play().catch(function(){});
      refreshCount = 0;
      showStatus("Live \u25CF", "ok", 5000);
    } catch (e) {
      showStatus("Reconnect failed: " + (e.message || e), "err", 7000);
    } finally {
      isRefreshing = false;
    }
  }

  player.addEventListener("error", function(ev) {
    var err  = ev.detail;
    var code = err && err.code;
    var recoverableCodes = [1001,1002,1003,6006,6007,7000,7001,7002];
    if (recoverableCodes.indexOf(code) !== -1) {
      refreshAndReload("shaka error " + code);
    } else {
      showStatus(shakaErrStr(err), "err", 8000);
    }
  });

  try {
    setLoadMsg("Starting playback...");
    showStatus("Loading stream...", "warn", 0);
    await player.load(activeUrl);
    vidEl.play().catch(function(){});
    hideOverlay();
    showStatus("Live \u25CF", "ok", 5000);
  } catch (e) {
    hideOverlay();
    var msg = shakaErrStr(e);
    showStatus("Playback failed: " + msg, "err", 0);
    setLoadMsg("Playback failed — reload page.");
    return;
  }

  vidEl.addEventListener("play", function() { vidEl.muted = false; }, { once: true });

  var stalledTimer = null;

  function onStall() {
    if (stalledTimer) return;
    showStatus("Buffering...", "warn", 0);
    stalledTimer = setTimeout(function() {
      stalledTimer = null;
      refreshAndReload("stall timeout");
    }, 9000);
  }

  vidEl.addEventListener("waiting", onStall);
  vidEl.addEventListener("stalled", onStall);

  vidEl.addEventListener("playing", function() {
    if (stalledTimer) { clearTimeout(stalledTimer); stalledTimer = null; }
    showStatus("Live \u25CF", "ok", 4000);
  });

  document.addEventListener("visibilitychange", function() {
    if (!document.hidden && vidEl.paused && !isRefreshing) {
      vidEl.play().catch(function() { refreshAndReload("tab resume"); });
    }
  });
}

async function main() {
  var channelId = getChannelId();
  var data;

  try {
    setLoadMsg("Fetching channels...");
    data = await fetchSportsData();
  } catch (e) {
    showErrorMsg("Network error: " + e.message);
    return;
  }

  if (!channelId) {
    showChannelList(data.channels);
    return;
  }

  var ch = null;
  for (var i = 0; i < data.channels.length; i++) {
    if (data.channels[i].id === channelId) { ch = data.channels[i]; break; }
  }

  if (!ch) {
    showErrorMsg("Channel \"" + channelId + "\" not found.");
    return;
  }

  document.title = ch.name + " — Live";
  await startPlayer(ch);
}

document.addEventListener("DOMContentLoaded", main);

})();
</script>
</body>
</html>
