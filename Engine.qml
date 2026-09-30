import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "Presets.js" as Presets

// Amiga Bar engine (keep-loaded panel next to the native Omarchy bar).
// It owns the options window and writes presets into bar.layout; the bar
// itself stays the native one, so every widget keeps its own service.
//
// The user's layout is saved once (base.json) before the first preset;
// "Today" restores it. Options live in this plugin's shell.json entry.
Item {
  id: root

  property var shell: null
  property var manifest: null
  readonly property string pluginId: manifest && manifest.id ? manifest.id : "nerdibeard.amiga-bar"

  readonly property string pluginDir: {
    var u = String(Qt.resolvedUrl("."))
    u = u.indexOf("file://") === 0 ? decodeURIComponent(u.substring(7)) : u
    return u.replace(/\/$/, "")
  }
  readonly property string moduleDir: pluginDir + "/modules"
  readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/amiga-bar"

  // ---------------------------------------------------------------- config
  property var config: ({})
  FileView {
    path: Quickshell.env("HOME") + "/.config/omarchy/shell.json"
    watchChanges: true
    onFileChanged: reload()
    onLoaded: { try { root.config = JSON.parse(text()) } catch (e) {} }
  }
  readonly property var entry: {
    var list = config && Array.isArray(config.plugins) ? config.plugins : []
    for (var i = 0; i < list.length; i++) if (list[i] && list[i].id === pluginId) return list[i]
    return {}
  }
  readonly property var options: Presets.normalizeOptions(entry.options || {})
  readonly property string presetId: Presets.matchPreset(options)
  readonly property var currentLayout: config && config.bar ? config.bar.layout : null

  // ---------------------------------------------------------------- base layout
  property var baseLayout: null
  property bool baseChecked: false
  Process {
    running: true
    command: ["mkdir", "-p", root.stateDir]
    onExited: baseFile.reload()
  }
  FileView {
    id: baseFile
    path: root.stateDir + "/base.json"
    printErrors: false
    onLoaded: { try { root.baseLayout = JSON.parse(text()).layout } catch (e) { root.baseLayout = null }; root.baseChecked = true }
    onLoadFailed: root.baseChecked = true
  }
  onBaseCheckedChanged: if (baseChecked && !baseLayout) captureBase()
  onCurrentLayoutChanged: if (baseChecked && !baseLayout) captureBase()

  function captureBase() {
    var current = currentLayout
    if (!current || (!current.left && !current.center && !current.right)) return
    baseLayout = Presets.stripOwn(current)
    baseFile.setText(JSON.stringify({ version: 1, saved: new Date().toISOString(), layout: baseLayout }, null, 2) + "\n")
  }

  // ---------------------------------------------------------------- apply
  property string lastResult: ""
  Process {
    id: writer
    property string payload: ""
    command: ["python3", root.pluginDir + "/bin/apply-layout.py"]
    stdinEnabled: true
    onStarted: { write(payload); stdinEnabled = false }
    stdout: StdioCollector { onStreamFinished: root.lastResult = String(text).trim() }
    stderr: StdioCollector { onStreamFinished: if (String(text).trim()) root.lastResult = "error: " + String(text).trim() }
    onExited: stdinEnabled = true
  }

  function apply(nextOptions) {
    if (!baseLayout) captureBase()
    if (!baseLayout) return "no base layout"
    if (writer.running) return "busy"
    var opts = Presets.normalizeOptions(nextOptions)
    writer.payload = JSON.stringify({ pluginId: pluginId, options: opts, layout: Presets.build(baseLayout, opts, moduleDir) })
    writer.running = true
    return "ok"
  }
  function applyPreset(id) {
    var p = Presets.presetById(String(id))
    return p ? apply(p.options) : "unknown preset: " + id
  }
  function setVariant(element, variant) {
    var o = JSON.parse(JSON.stringify(options))
    o[String(element)] = String(variant)
    return apply(o)
  }

  // ---------------------------------------------------------------- panel contract
  property bool isOpen: false
  readonly property bool opened: isOpen
  function open(payloadJson) { isOpen = true }
  function close() { isOpen = false }
  function toggle() { isOpen = !isOpen }

  OptionsWindow {
    host: root
    open: root.isOpen
    onCloseRequested: root.isOpen = false
  }

  // ---------------------------------------------------------------- menu strip + status screen (stage D)
  property bool menuOpen: false
  property bool screenOpen: false
  SysState { id: sysState; active: root.menuOpen || root.screenOpen }
  readonly property alias sys: sysState

  function run(cmd) { Quickshell.execDetached(["sh", "-c", cmd]) }

  // Open a widget's own popup, wherever it lives now: folded into the
  // status module (embedded) or still in the bar.
  function openWidget(id) {
    var folded = options.right !== "today" && Presets.foldedIds(options).indexOf(id) !== -1
    run(folded ? "omarchy-shell amiga-status member " + id : "omarchy-shell shell summon " + id)
  }
  function focusAgent(a) {
    if (!a) return
    var pane = String(a.pane || "")
    if (pane.indexOf("oc:") === 0) Quickshell.execDetached(["xdg-open", "http://127.0.0.1:18789/"])
    else Quickshell.execDetached(["herdr", "agent", "focus", pane])
  }
  function openScreen() { menuOpen = false; screenOpen = true }

  // Menus (built on demand from live state). Items: { label, note, checked,
  // key, disabled, separator, action }.
  function menuModel() {
    var s = sysState
    var sep = { separator: true }
    var agents = s.agents.map(function(a) {
      return { label: (a.title || a.agent || "Agent"), note: (a.agent || "") + " · " + (a.status === "blocked" ? "waiting" : a.status === "working" ? "working" : "idle"),
               action: function() { root.focusAgent(a) } }
    })
    if (!agents.length) agents = [{ label: "No agents reported", disabled: true }]
    return [
      { title: "Omarchy", items: [
        { label: "Omarchy menu …", action: function() { root.run("omarchy-menu toggle root") } },
        { label: "Terminal", key: "↵", action: function() { root.run("xdg-terminal-exec") } },
        sep,
        { label: "Do not disturb", checked: s.dnd, action: function() { root.run("omarchy-shell notifications toggleDnd") } },
        { label: "Stay awake", checked: s.stayAwake, action: function() { root.run("omarchy-toggle-idle") } },
        sep,
        { label: "Lock", action: function() { root.run("loginctl lock-session") } }
      ] },
      { title: "Agents", items: agents.concat([sep,
        { label: "Quotas …", action: function() { root.run(root.options.ai !== "today" ? "omarchy-shell amiga-quota toggle" : "omarchy-shell shell summon nerdibeard.ai-usage") } },
        { label: "Status screen", key: "M", action: function() { root.openScreen() } }]) },
      { title: "System", items: [
        { label: "System monitor …", note: "CPU " + Math.round(s.cpu * 100) + " %", action: function() { root.openWidget("bitr0t.system-monitor") } },
        { label: "Display & brightness …", action: function() { root.openWidget("nerdibeard.monitor") } },
        { label: "Google Drive …", action: function() { root.openWidget("nerdibeard.googledrive") } },
        { label: "Rain radar …", action: function() { root.openWidget("com.omastorm.radar") } },
        { label: "Manage plugins …", action: function() { root.openWidget("community.plugin-manager") } }
      ] },
      { title: "Network", items: [
        { label: "Wi-Fi · " + (s.wifiUp ? s.wifiName : "disconnected"), action: function() { root.openWidget("omarchy.network") } },
        { label: "Proton VPN", checked: s.vpnUp, note: s.vpnUp ? "disconnect" : "connect",
          action: function() { root.run(s.vpnUp ? "protonvpn disconnect" : "protonvpn connect") } },
        { label: "Tailscale", checked: s.tailscaleUp, note: s.tailscaleUp ? "disconnect" : "connect",
          action: function() { root.run(s.tailscaleUp ? "tailscale down" : "tailscale up") } },
        { label: "Bluetooth …", action: function() { root.openWidget("omarchy.bluetooth") } }
      ] },
      { title: "Phone", items: [
        { label: "Flux · " + (s.phone ? s.phone.name : "Pixel"), note: s.phone && s.phone.charge >= 0 ? s.phone.charge + " %" : "", action: function() { root.run("omarchy-shell shell toggle flux") } },
        { label: "Buds …", action: function() { root.openWidget("io.github.nerdislb.buds-control") } },
        sep,
        { label: "WhatsApp …", action: function() { root.run("omarchy-shell io.github.moizibnyousaf.omawhatsapp toggleDropdown") } },
        { label: "Mail …", action: function() { root.run("omarchy-shell shell toggle omamail") } }
      ] },
      { title: "Tools", items: [
        { label: "Status screen", key: "M", action: function() { root.openScreen() } },
        { label: "Open island", action: function() { root.run("omarchy-shell amiga-island expand") } },
        { label: "Amiga Bar options …", action: function() { root.isOpen = true } },
        sep,
        { label: "Concept gallery", action: function() { Quickshell.execDetached(["xdg-open", Quickshell.env("HOME") + "/.openclaw/workspace/output/amiga-bar-2026-09-30/index.html"]) } }
      ] }
    ]
  }

  IntuitionMenu {
    host: root
    open: root.menuOpen
    onCloseRequested: root.menuOpen = false
  }
  StatusScreen {
    host: root
    open: root.screenOpen
    onCloseRequested: root.screenOpen = false
  }

  IpcHandler {
    target: "amiga-bar"
    function options(): void { root.toggle() }
    function menu(): void { root.screenOpen = false; root.menuOpen = !root.menuOpen }
    function screen(): void { root.menuOpen = false; root.screenOpen = !root.screenOpen }
    function preset(id: string): string { return root.applyPreset(id) }
    function set(element: string, variant: string): string { return root.setVariant(element, variant) }
    function recaptureBase(): string { root.captureBase(); return "ok" }
    function state(): string {
      return JSON.stringify({ preset: root.presetId, options: root.options, hasBase: root.baseLayout !== null,
                              open: root.isOpen, lastResult: root.lastResult, moduleDir: root.moduleDir })
    }
  }
}
