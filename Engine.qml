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
// "Heute" restores it. Options live in this plugin's shell.json entry.
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

  IpcHandler {
    target: "amiga-bar"
    function options(): void { root.toggle() }
    function preset(id: string): string { return root.applyPreset(id) }
    function set(element: string, variant: string): string { return root.setVariant(element, variant) }
    function recaptureBase(): string { root.captureBase(); return "ok" }
    function state(): string {
      return JSON.stringify({ preset: root.presetId, options: root.options, hasBase: root.baseLayout !== null,
                              open: root.isOpen, lastResult: root.lastResult, moduleDir: root.moduleDir })
    }
  }
}
