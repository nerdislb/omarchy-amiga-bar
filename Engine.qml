import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "Presets.js" as Presets
import "bridge" as Bridge

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
    onLoaded: { try { root.config = JSON.parse(text()); root.configLoaded = true } catch (e) {} }
  }
  property bool configLoaded: false
  readonly property var entry: {
    var list = config && Array.isArray(config.plugins) ? config.plugins : []
    for (var i = 0; i < list.length; i++) if (list[i] && list[i].id === pluginId) return list[i]
    return {}
  }
  readonly property var options: Presets.normalizeOptions(entry.options || {})
  readonly property string presetId: Presets.matchPreset(options)
  readonly property var currentLayout: config && config.bar ? config.bar.layout : null

  readonly property var edgeBar: shell ? shell.bar : null
  // Edges hang under the native bar only: on top, shown, not replaced.
  readonly property bool barReady: !!edgeBar
    && edgeBar.barSize > 0 && edgeBar.position === "top" && !edgeBar.barHidden
    && (!shell.barConfig || !shell.barConfig.id || shell.barConfig.id === "omarchy.bar")
  // The fog look (test) replaces the Workbench edge while it is on.
  readonly property bool fogOn: options.fog === "on"
  readonly property bool fogVisible: fogOn && barReady && !edgeBar.transparent
  readonly property bool edgeVisible: options.edge === "workbench" && !fogOn && options.form !== "a500" && barReady
  // The colour the bar ends in (opaque; the A500 form makes the native
  // bar's fill transparent): the bar's own, or the case's darker front.
  readonly property color fogColor: {
    var c = Color.bar.background
    var opaque = Qt.rgba(c.r, c.g, c.b, 1)
    return options.form === "a500" ? Qt.darker(opaque, 1.35) : opaque
  }
  Variants {
    model: root.fogVisible ? Quickshell.screens : []
    delegate: Component {
      FogEdge {
        required property var modelData
        screen: modelData
        fogColor: root.fogColor
        barHeight: root.edgeBar ? root.edgeBar.barSize : Style.bar.sizeHorizontal
      }
    }
  }
  Variants {
    model: root.edgeVisible ? Quickshell.screens : []
    delegate: Component {
      WorkbenchEdge {
        required property var modelData
        screen: modelData
        barHeight: root.edgeBar ? root.edgeBar.barSize : Style.bar.sizeHorizontal
      }
    }
  }

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
    if (!current || (!current.left && !current.center && !current.right)) return "no bar layout yet"
    // base.json lost while our modules are live: rebuild the native layout
    // from them (folded widgets keep their settings) instead of dead-ending.
    var reconstructed = Presets.hasOwn(current)
    baseLayout = reconstructed ? Presets.reconstructBase(current) : Presets.stripOwn(current)
    baseFile.setText(JSON.stringify({ version: 1, saved: new Date().toISOString(), reconstructed: reconstructed, layout: baseLayout }, null, 2) + "\n")
    if (reconstructed) lastResult = "Baseline rebuilt from the current bar (base.json was missing)"
    return "ok"
  }

  // Named combinations are local data, never filenames or shell arguments.
  property var savedPresets: []
  property bool savedReady: false
  property string saveResult: ""
  FileView {
    id: savedFile
    atomicWrites: true
    path: root.stateDir + "/presets.json"
    printErrors: false
    onLoaded: {
      try {
        var data = JSON.parse(text())
        if (!Array.isArray(data)) throw new Error("not a list")
        root.savedPresets = data.filter(function(p) { return p && typeof p.name === "string" && p.options })
        root.savedReady = true
      } catch (e) { root.saveResult = "Cannot read saved combinations; file kept unchanged"; root.savedReady = false }
    }
    onLoadFailed: function(error) {
      // Only a missing file is safe to initialize.
      root.savedReady = error === FileViewError.FileNotFound
      if (!root.savedReady) root.saveResult = "Cannot read saved combinations"
    }
  }
  function saveCombination(name) {
    name = String(name).trim()
    if (!savedReady) return "Saved combinations are not available"
    if (!name || name.length > 48) return "Use a name of 1–48 characters"
    var next = savedPresets.filter(function(p) { return p.name !== name })
    next.push({ name: name, options: Presets.normalizeOptions(options) })
    next.sort(function(a, b) { return a.name.localeCompare(b.name) })
    savedPresets = next
    savedFile.setText(JSON.stringify(next, null, 2) + "\n")
    return "Saved: " + name
  }
  function loadCombination(name) {
    for (var i = 0; i < savedPresets.length; i++) if (savedPresets[i].name === name) return apply(Presets.keepDesktopFont(savedPresets[i].options, options))
    return "Unknown combination"
  }
  function deleteCombination(name) {
    if (!savedReady) return
    savedPresets = savedPresets.filter(function(p) { return p.name !== name })
    savedFile.setText(JSON.stringify(savedPresets, null, 2) + "\n")
    saveResult = "Removed: " + name
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
    onExited: function(exitCode) {
      stdinEnabled = true
      // The desktop font profile changed: reload apps and the shell only now,
      // after the option is saved (the restart also restarts this engine).
      if (root.reloadAfterWrite) { root.reloadAfterWrite = false; root.reloadApps() }
    }
  }

  function apply(nextOptions) {
    if (!baseLayout) captureBase()
    if (!baseLayout) return "no base layout"
    if (writer.running) return "busy"
    var opts = Presets.normalizeOptions(nextOptions)
    var merged = Presets.mergeEmbeddedSettings(baseLayout, currentLayout)
    if (JSON.stringify(merged) !== JSON.stringify(baseLayout)) {
      baseLayout = merged
      baseFile.setText(JSON.stringify({ version: 1, layout: merged }, null, 2) + "\n")
    }
    writer.payload = JSON.stringify({ pluginId: pluginId, options: opts, layout: Presets.build(baseLayout, opts, moduleDir) })
    writer.running = true
    return "ok"
  }
  function applyPreset(id) {
    var p = Presets.presetById(String(id))
    return p ? apply(Presets.keepDesktopFont(p.options, options)) : "unknown preset: " + id
  }
  function setVariant(element, variant) {
    if (!Presets.ELEMENTS[element] || !Presets.ELEMENTS[element].variants.some(function(v) { return v.id === variant })) return "unknown element or variant"
    if (element === "font") return setFont(String(variant))
    var o = JSON.parse(JSON.stringify(options))
    o[String(element)] = String(variant)
    return apply(o)
  }

  // ---------------------------------------------------------------- pixel font
  // theme/topaz/bar only change our own text, live. "desktop" also installs
  // the system profile (bin/system-font.py); the option is saved only after
  // the script succeeded, then Ghostty and the shell reload.
  Binding { target: Bridge.ModuleBus; property: "fontLevel"; value: root.options.font }
  Binding { target: Bridge.ModuleBus; property: "fog"; value: root.fogOn }
  Binding { target: Bridge.ModuleBus; property: "fogColor"; value: root.fogColor }
  Binding { target: Bridge.ModuleBus; property: "noteActive"; value: root.caseVisible && !!root.islandSpan.note }
  Binding { target: Bridge.ModuleBus; property: "noteScreen"; value: String(root.islandSpan.noteScreen || "") }
  // per screen: the note comes out of the slot on the monitor it hangs on
  function noteOn(screenName) { return !!islandSpan.note && (!islandSpan.noteScreen || islandSpan.noteScreen === screenName) }

  // ---------------------------------------------------------------- bar form
  // "a500": the native bar's own fill goes transparent (bin/bar-form.py, a
  // managed block in ~/.config/omarchy/shell.toml) and A500Case draws the
  // case on the layer under it; "full" removes the block again. Synced only
  // once the options are read, so a restart never flashes the other form.
  readonly property string formOption: options.form
  readonly property bool caseVisible: formOption === "a500" && barReady
  // The bar's fill is transparent only while the case can be under it: on
  // the native bar at the top (a hidden bar keeps it, no churn).
  readonly property bool formWanted: formOption === "a500" && !!edgeBar && edgeBar.position === "top"
    && (!shell.barConfig || !shell.barConfig.id || shell.barConfig.id === "omarchy.bar")
  property string formResult: ""
  property bool formPending: false
  onFormWantedChanged: if (configLoaded && edgeBar) syncForm()
  onConfigLoadedChanged: if (configLoaded && edgeBar) syncForm()
  onEdgeBarChanged: if (configLoaded && edgeBar) syncForm()
  function syncForm() {
    if (formWriter.running) { formPending = true; return }
    formWriter.action = formWanted ? "enable" : "disable"
    formWriter.running = true
  }
  // Removed or disabled (not just reloaded): give the bar its fill back.
  // The script is copied to the state dir first, so this works even when
  // the plugin's files are already gone.
  Process { running: true; command: ["cp", root.pluginDir + "/bin/bar-form.py", root.stateDir + "/bar-form.py"] }
  Component.onDestruction: Quickshell.execDetached(["sh", "-c",
    "sleep 4; c=\"$HOME/.config/omarchy/shell.json\"; " +
    "jq -e --arg id \"$1\" '([.plugins[]? | select(type == \"object\" and .id == $id)] | length > 0) " +
    "and (((.disabledPlugins // []) | index($id)) == null)' \"$c\" >/dev/null 2>&1 && exit 0; " +
    "python3 \"$2\" disable >/dev/null 2>&1",
    "sh", root.pluginId, root.stateDir + "/bar-form.py"])
  Process {
    id: formWriter
    property string action: "status"
    command: ["python3", root.pluginDir + "/bin/bar-form.py", action]
    stdout: StdioCollector {
      onStreamFinished: {
        var r = null
        try { r = JSON.parse(text) } catch (e) {}
        root.formResult = r && r.error ? r.error : ""
      }
    }
    onExited: if (root.formPending) { root.formPending = false; root.syncForm() }
  }

  // Where the island sits in each bar and whether a note is coming out
  // (written by the Amiga Island while this form is on).
  property var islandSpan: ({})
  FileView {
    path: Quickshell.env("HOME") + "/.local/state/omarchy/amiga-island/bar-span.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: { try { root.islandSpan = JSON.parse(text()) } catch (e) {} }
  }
  // The compact strip's span per screen (for the case's LED window).
  property var ledSpans: ({})
  Timer {
    interval: 1500
    running: root.caseVisible
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      var out = {}
      ;(Bridge.ModuleBus.instances.status || []).forEach(function(i) {
        var r = i && typeof i.caseLedSpan === "function" ? i.caseLedSpan() : null
        if (r && r.screen) out[r.screen] = { x: r.x, w: r.w }
      })
      if (JSON.stringify(out) !== JSON.stringify(root.ledSpans)) root.ledSpans = out
    }
  }
  Variants {
    model: root.caseVisible ? Quickshell.screens : []
    delegate: Component {
      A500Case {
        required property var modelData
        screen: modelData
        barHeight: root.edgeBar ? root.edgeBar.barSize : Style.bar.sizeHorizontal
        slot: root.islandSpan.screens && root.islandSpan.screens[modelData.name] ? root.islandSpan.screens[modelData.name] : null
        led: root.ledSpans[modelData.name] || null
        noteOpen: root.noteOn(modelData.name)
      }
    }
  }
  property string systemProfile: "unknown"   // normal · amiga · partial
  property string systemFontResult: ""
  property string pendingFont: ""
  property bool reloadAfterWrite: false
  Process {
    id: systemFont
    property string action: "status"
    command: ["python3", root.pluginDir + "/bin/system-font.py", action, "--no-reload"]
    stdout: StdioCollector {
      onStreamFinished: {
        var result = null
        try { result = JSON.parse(text) } catch (e) {}
        if (result && result.profile) root.systemProfile = result.profile
        if (systemFont.action === "status") {
          if (!result || result.error) root.systemFontResult = "Could not read the desktop font profile"
          return
        }
        var next = root.pendingFont
        root.pendingFont = ""
        if (!result || result.error) {
          root.systemFontResult = (result && result.error ? result.error + " — " : "") + "nothing was saved"
          return
        }
        root.systemFontResult = result.message || ""
        var o = JSON.parse(JSON.stringify(root.options))
        o.font = next
        root.reloadAfterWrite = true
        var r = root.apply(o)
        if (r !== "ok") {
          root.reloadAfterWrite = false
          root.systemFontResult = "Profile changed, but the option was not saved: " + r
          root.reloadApps()
        }
      }
    }
  }
  function reloadApps() { Quickshell.execDetached(["python3", root.pluginDir + "/bin/system-font.py", "reload"]) }
  function refreshSystemFont() {
    if (systemFont.running) return
    systemFont.action = "status"; systemFont.running = true
  }
  function setFont(level) {
    if (systemFont.running || pendingFont !== "" || writer.running) return "busy"
    var toDesktop = level === "desktop"
    var needScript = toDesktop || options.font === "desktop" || systemProfile !== "normal"
    if (!needScript) return apply(Object.assign({}, options, { font: level }))
    pendingFont = level
    systemFontResult = toDesktop ? "Installing the desktop font profile …" : "Removing the desktop font profile …"
    systemFont.action = toDesktop ? "enable" : "restore"
    systemFont.running = true
    return "ok"
  }

  // ---------------------------------------------------------------- AI usage refresh
  // omarchy.agents (and the AI usage widget) keep ~/.local/state/omarchy/
  // agents/usage current only while they sit in the bar. When a variant folds
  // them away, the engine runs the same collectors with the Agents widget's
  // own settings (interval, disabled providers); otherwise limits froze at
  // their last value (e.g. a 5-hour limit at 100 % long after its reset).
  readonly property var agentsSettings: {
    var lists = baseLayout ? [baseLayout.left, baseLayout.center, baseLayout.right] : []
    for (var s = 0; s < lists.length; s++)
      for (var i = 0; i < (lists[s] || []).length; i++)
        if (Presets.entryId(lists[s][i]) === "omarchy.agents") return typeof lists[s][i] === "object" ? lists[s][i] : ({})
    return ({})
  }
  readonly property bool usageFolded: {
    var folded = Presets.foldedIds(options)
    var lists = baseLayout ? [baseLayout.left, baseLayout.center, baseLayout.right] : []
    for (var s = 0; s < lists.length; s++)
      for (var i = 0; i < (lists[s] || []).length; i++) {
        var id = Presets.entryId(lists[s][i])
        if (Presets.AI_IDS.indexOf(id) !== -1 && folded.indexOf(id) !== -1) return true
      }
    return false
  }
  readonly property int usageIntervalSec: Math.max(30, Number(agentsSettings.refreshIntervalSec || 900))
  property string pendingUsage: ""
  property double lastLimitsRun: 0
  Timer {
    interval: root.usageIntervalSec * 1000
    running: root.usageFolded
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refreshUsage("normal")
  }
  function usageCommand(kind, ids) {
    var command = ["omarchy-agent-usage-update"]
    if (kind === "force") command.push("--force")
    if (kind === "limits") command.push("--limits-only")
    var providers = agentsSettings.providers || {}
    for (var id in providers) if (providers[id] && providers[id].enabled === false) command.push("--except", id)
    return command.concat(ids || [])
  }
  function refreshUsage(kind, ids) {
    if (!usageFolded) return          // the native widgets refresh themselves
    if (kind === "limits" && !ids) {  // expired limits / opened popups: at most once a minute
      if (Date.now() - lastLimitsRun < 60000) return
      lastLimitsRun = Date.now()
    }
    if (usageUpdate.running) { if (kind === "force" || pendingUsage === "") pendingUsage = kind; return }
    usageUpdate.command = usageCommand(kind, ids)
    usageUpdate.running = true
  }
  Process {
    id: usageUpdate
    onExited: {
      if (root.pendingUsage !== "") { var k = root.pendingUsage; root.pendingUsage = ""; root.refreshUsage(k); return }
      retryScan.running = true
    }
  }
  // A collector that could not reach its endpoint (e.g. right after login)
  // sets retryAdvised: retry just those limits after 30 s, as omarchy.agents does.
  Process {
    id: retryScan
    command: ["sh", "-c", "grep -l '\"retryAdvised\": *true' \"${XDG_STATE_HOME:-$HOME/.local/state}\"/omarchy/agents/usage/*.json 2>/dev/null | sed 's#.*/##; s#\\.json$##'"]
    stdout: StdioCollector { onStreamFinished: { var ids = String(text).split("\n").filter(function(s) { return s }); if (ids.length) { usageRetry.ids = ids; usageRetry.restart() } } }
  }
  Timer { id: usageRetry; property var ids: []; interval: 30000; onTriggered: root.refreshUsage("limits", ids) }
  Connections {
    target: Bridge.ModuleBus
    function onUsageRefreshRequested(kind) { root.refreshUsage(kind) }
  }

  // ---------------------------------------------------------------- panel contract
  property bool isOpen: false
  readonly property bool opened: isOpen
  function open(payloadJson) { menuOpen = false; screenOpen = false; isOpen = true }
  function close() { isOpen = false }
  function toggle() { if (isOpen) close(); else open("") }

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
  function closeModulePopups() {
    ;(Bridge.ModuleBus.instances.status || []).forEach(function(i) {
      i.closePopup()
      Object.keys(i.mounted).forEach(function(id) { var m = i.mounted[id]; if (m && typeof m.close === "function") m.close() })
    })
    ;(Bridge.ModuleBus.instances.quota || []).forEach(function(i) { i.close() })
  }
  onIsOpenChanged: if (isOpen) { closeModulePopups(); refreshSystemFont() }
  Component.onCompleted: refreshSystemFont()
  onMenuOpenChanged: if (menuOpen) { isOpen = false; screenOpen = false; closeModulePopups() }
  onScreenOpenChanged: if (screenOpen) { isOpen = false; menuOpen = false; closeModulePopups(); refreshUsage("limits") }
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
    id: intuitionMenu
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
    target: "amiga-status"
    function group(id: string): void { var i = Bridge.ModuleBus.pick("status"); if (i) i.openGroup(id, i) }
    function member(id: string): void { var i = Bridge.ModuleBus.pick("status"); if (i) i.openMember(id) }
    function close(): void { var all = Bridge.ModuleBus.instances.status || []; all.forEach(function(i) { i.closePopup() }) }
    function state(): string { var i = Bridge.ModuleBus.pick("status"); return i ? i.stateJson() : "{}" }
  }
  IpcHandler {
    target: "amiga-quota"
    function toggle(): void { var i = Bridge.ModuleBus.pick("quota"); if (i) i.togglePopup() }
    function state(): string { var i = Bridge.ModuleBus.pick("quota"); return i ? JSON.stringify({ variant: i.variant, items: i.items, open: i.popupOpen }) : "{}" }
  }

  IpcHandler {
    target: "amiga-bar"
    // Legacy switch: amiga = whole desktop, normal = keep our text, drop the profile.
    function font(profile: string): string {
      if (profile === "amiga") return root.setFont("desktop")
      if (profile === "normal") return root.setFont(root.options.font === "desktop" ? "bar" : root.options.font)
      return "use amiga or normal"
    }
    function menuState(): string { return JSON.stringify({ open: root.menuOpen, tab: intuitionMenu.current, item: intuitionMenu.item }) }
    function options(): void { root.toggle() }
    function save(name: string): string { return root.saveCombination(name) }
    function load(name: string): string { return root.loadCombination(name) }
    function menu(): void { root.screenOpen = false; root.menuOpen = !root.menuOpen }
    function screen(): void { root.menuOpen = false; root.screenOpen = !root.screenOpen }
    function preset(id: string): string { return root.applyPreset(id) }
    function set(element: string, variant: string): string { return root.setVariant(element, variant) }
    // After choosing Today: fresh snapshot of your own layout. Without any
    // baseline (base.json lost) it rebuilds one from our modules instead.
    function recaptureBase(): string {
      if (Presets.hasOwn(root.currentLayout) && root.baseLayout) return "restore Today before capturing the baseline"
      return root.captureBase()
    }
    function state(): string {
      return JSON.stringify({ preset: root.presetId, options: root.options, hasBase: root.baseLayout !== null,
                              open: root.isOpen, menuOpen: root.menuOpen, screenOpen: root.screenOpen, saved: root.savedPresets.map(function(p) { return p.name }), lastResult: root.lastResult, moduleDir: root.moduleDir,
                              systemFont: root.systemProfile, fontResult: root.systemFontResult,
                              form: { option: root.formOption, caseVisible: root.caseVisible, result: root.formResult, island: root.islandSpan, led: root.ledSpans },
                              usage: { folded: root.usageFolded, intervalSec: root.usageIntervalSec, running: usageUpdate.running, command: usageUpdate.command } })
    }
  }
}
