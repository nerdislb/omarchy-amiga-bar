import QtQuick
import Quickshell
import Quickshell.Io

// Live desktop state for the Intuition menu and the status screen. Polls
// only while one of them is open (`active`), plus once on start. Read-only;
// actions are separate commands.
Item {
  id: st

  property bool active: false
  readonly property string home: Quickshell.env("HOME")

  // ---- values
  property var agents: []          // herdr / OpenClaw via Flux: { pane, agent, status, title, project }
  property var phone: null         // { name, online, charge, charging }
  property bool vpnUp: false
  property string vpnName: ""
  property bool wifiUp: true
  property string wifiName: ""
  property bool tailscaleUp: false
  property bool dnd: false
  property bool stayAwake: false
  property real cpu: 0
  property real mem: 0
  property string disk: ""
  property var quotas: []          // { name, label, percent (-1 = balance), value, resetsAt }
  property var events: []          // { title, start, end, allDay, source }
  property var tests: null         // { run, running, summary, failed }

  function refresh() {
    for (var i = 0; i < procs.length; i++) if (!procs[i].running) procs[i].running = true
    stat.reload(); meminfo.reload()
    for (var j = 0; j < files.length; j++) files[j].reload()
  }
  readonly property var procs: [flux, nm, ts, dndProc, idleProc, df, testsProc]
  readonly property var files: [cal, usageClaude, usageCodex, usageGemini, usageDeepseek]

  Timer { interval: 4000; running: st.active; repeat: true; triggeredOnStart: true; onTriggered: st.refresh() }
  Component.onCompleted: refresh()

  Process {
    id: flux
    command: ["flux-cli", "status", "--json"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var d = JSON.parse(text), list = d.devices || []
          var h = d.herdr || {}
          st.agents = h.running && Array.isArray(h.agents) ? h.agents : []
          var p = null
          for (var i = 0; i < list.length; i++) if (list[i].paired) { p = list[i]; break }
          st.phone = p ? { name: String(p.name || "Pixel"), online: !!p.online,
                           charge: p.battery ? Number(p.battery.charge) : -1, charging: !!(p.battery && p.battery.charging) } : null
        } catch (e) {}
      }
    }
  }
  Process {
    id: nm
    command: ["nmcli", "-t", "-f", "NAME,TYPE", "connection", "show", "--active"]
    stdout: StdioCollector {
      onStreamFinished: {
        var wifi = "", vpn = ""
        String(text).split("\n").forEach(function(l) {
          var p = l.split(":")
          if (p.length < 2) return
          if ((p[1] === "802-11-wireless" || p[1] === "802-3-ethernet") && !wifi) wifi = p[0]
          if ((p[1] === "vpn" || p[1] === "wireguard") && !vpn) vpn = p[0]
        })
        st.wifiUp = wifi !== ""; st.wifiName = wifi; st.vpnUp = vpn !== ""; st.vpnName = vpn
      }
    }
  }
  Process {
    id: ts
    command: ["tailscale", "status", "--json"]
    stdout: StdioCollector { onStreamFinished: { try { st.tailscaleUp = JSON.parse(text).BackendState === "Running" } catch (e) { st.tailscaleUp = false } } }
  }
  Process {
    id: dndProc
    command: ["omarchy-shell", "notifications", "isDnd"]
    stdout: StdioCollector { onStreamFinished: st.dnd = String(text).trim() === "on" || String(text).trim() === "true" }
  }
  Process {
    id: idleProc
    command: ["test", "-f", st.home + "/.local/state/omarchy/indicators/stay-awake"]
    onExited: function(code) { st.stayAwake = code === 0 }
  }
  Process {
    id: df
    command: ["df", "-h", "--output=pcent,avail", "/"]
    stdout: StdioCollector {
      onStreamFinished: {
        var l = String(text).trim().split("\n")[1] || ""
        var p = l.trim().split(/\s+/)
        st.disk = p.length >= 2 ? p[0] + " used · " + p[1] + " free" : ""
      }
    }
  }
  // Latest nbtiles-test run: summary if finished, "running" otherwise.
  Process {
    id: testsProc
    command: ["sh", "-c", "d=$(ls -1d \"$HOME\"/.local/state/nbtiles-test/runs/*/ 2>/dev/null | tail -1); [ -n \"$d\" ] || exit 0; " +
                          "echo \"$(basename \"$d\")\"; if [ -f \"$d/summary.txt\" ]; then tail -1 \"$d/summary.txt\"; else echo RUNNING; " +
                          "grep -h -o '[0-9]* tests, [0-9]* failed' \"$d\"/shard-*.log 2>/dev/null | tr '\\n' ';'; echo; " +
                          "stat -c %Y \"$d\"/*.log 2>/dev/null | sort -n | tail -1; fi"]
    stdout: StdioCollector {
      onStreamFinished: {
        var lines = String(text).trim().split("\n")
        if (!lines[0]) { st.tests = null; return }
        var running = lines[1] === "RUNNING"
        // No summary and no output for 15 min: the run was interrupted.
        var lastOut = running ? Number(lines[3]) * 1000 : 0
        var stale = running && lastOut > 0 && Date.now() - lastOut > 15 * 60000
        st.tests = { run: lines[0], running: running && !stale, stale: stale, lastOut: lastOut,
                     summary: running ? (lines[2] || "") : (lines[1] || ""),
                     failed: /([1-9][0-9]*) failed/.test(running ? (lines[2] || "") : (lines[1] || "")) }
      }
    }
  }

  property var lastCpu: null
  FileView {
    id: stat
    path: "/proc/stat"
    onLoaded: {
      var f = String(text()).split("\n")[0].trim().split(/\s+/).slice(1).map(Number)
      var idle = f[3] + (f[4] || 0), total = f.reduce(function(a, b) { return a + b }, 0)
      if (st.lastCpu) { var dt = total - st.lastCpu.total; if (dt > 0) st.cpu = Math.max(0, Math.min(1, 1 - (idle - st.lastCpu.idle) / dt)) }
      st.lastCpu = { total: total, idle: idle }
    }
  }
  FileView {
    id: meminfo
    path: "/proc/meminfo"
    onLoaded: { var t = String(text()), a = /MemTotal:\s+(\d+)/.exec(t), b = /MemAvailable:\s+(\d+)/.exec(t); if (a && b) st.mem = 1 - Number(b[1]) / Number(a[1]) }
  }

  // ---- quotas (same files as the quota module)
  readonly property string usageDir: home + "/.local/state/omarchy/agents/usage"
  property var providerData: ({})
  function setProvider(id, name, text) {
    var d; try { d = JSON.parse(text) } catch (e) { return }
    var next = {}; for (var k in providerData) next[k] = providerData[k]
    next[id] = { name: name, limits: Array.isArray(d.limits) ? d.limits : [] }
    providerData = next
    var out = []
    var order = ["claude", "codex", "antigravity", "deepseek"]
    for (var i = 0; i < order.length; i++) {
      var p = providerData[order[i]]; if (!p) continue
      p.limits.forEach(function(l) {
        // past its reset time a limit is back at 0 %, whatever the record still says
        var resets = Date.parse(String(l.resetsAt || "")), expired = !l.noQuota && resets > 0 && resets <= Date.now()
        out.push({ name: p.name, label: String(l.title || l.label || ""), percent: l.noQuota ? -1 : expired ? 0 : Number(l.percent) || 0,
                   value: String(l.valueText || ""), resetsAt: String(l.resetsAt || ""), expired: expired })
      })
    }
    quotas = out
  }
  FileView { id: usageClaude; path: st.usageDir + "/claude.json"; printErrors: false; onLoaded: st.setProvider("claude", "Claude", text()) }
  FileView { id: usageCodex; path: st.usageDir + "/codex.json"; printErrors: false; onLoaded: st.setProvider("codex", "Codex", text()) }
  FileView { id: usageGemini; path: st.usageDir + "/antigravity.json"; printErrors: false; onLoaded: st.setProvider("antigravity", "Gemini", text()) }
  FileView { id: usageDeepseek; path: st.home + "/.local/state/deepseek-usage/display.json"; printErrors: false; onLoaded: st.setProvider("deepseek", "DeepSeek", text()) }

  // ---- today and tomorrow from OmaMail's calendar cache
  FileView {
    id: cal
    path: st.home + "/.cache/omamail/calendar-bar.json"
    printErrors: false
    onLoaded: {
      var c; try { c = JSON.parse(text()) } catch (e) { return }
      var now = Date.now(), best = null
      for (var k in (c.ranges || {})) {
        var r = c.ranges[k]
        if (!r || !Array.isArray(r.events)) continue
        if (!best || (r.at || 0) > (best.at || 0)) best = r
      }
      if (!best) return
      var until = new Date(); until.setHours(0, 0, 0, 0); until = until.getTime() + 2 * 86400000
      st.events = best.events.filter(function(e) { return e && e.start && e.end && e.end.ms > now && e.start.ms < until && String(e.status || "").toUpperCase() !== "CANCELLED" })
        .map(function(e) { return { title: String(e.summary || ""), start: e.start.ms, end: e.end.ms, allDay: !!e.start.allDay, source: String(e.sourceName || "") } })
        .sort(function(a, b) { return a.start - b.start }).slice(0, 6)
    }
  }
}
