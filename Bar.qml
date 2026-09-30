import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import qs.plugins.bar as Native
import "Presets.js" as Presets

// Amiga Bar: the native Omarchy bar (all widgets, drag, popouts, theme stay
// Omarchy-owned) plus presets and own compact modules. Only a bar plugin
// may rewrite bar.layout, which the presets need.
//
// The user's own layout is saved once (base.json) before the first preset;
// "Heute" restores it. Choices live in shell.json under bar.amiga.
Native.Bar {
  id: root

  readonly property string pluginDir: {
    var u = String(Qt.resolvedUrl("."))
    u = u.indexOf("file://") === 0 ? decodeURIComponent(u.substring(7)) : u
    return u.replace(/\/$/, "")
  }
  readonly property string moduleDir: pluginDir + "/modules"
  readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/amiga-bar"

  readonly property var amiga: barConfig && barConfig.amiga ? barConfig.amiga : ({})
  readonly property var options: Presets.normalizeOptions(amiga.options || {})
  readonly property string presetId: Presets.matchPreset(options)

  // ---------------------------------------------------------------- base layout
  property var baseLayout: null

  Process {
    running: true
    command: ["mkdir", "-p", root.stateDir]
    onExited: baseFile.reload()
  }

  FileView {
    id: baseFile
    path: root.stateDir + "/base.json"
    printErrors: false
    atomicWrites: true
    onLoaded: {
      try { root.baseLayout = JSON.parse(text()).layout } catch (e) { root.baseLayout = null }
      root.baseChecked = true
    }
    onLoadFailed: root.baseChecked = true
  }

  // The bar config arrives after load; capture then if nothing was saved.
  property bool baseChecked: false
  onBaseCheckedChanged: if (baseChecked && !baseLayout) captureBase()
  onBarConfigChanged: if (baseChecked && !baseLayout) captureBase()

  // First run: remember the layout as it is (without our own modules).
  function captureBase() {
    var current = barConfig && barConfig.layout ? barConfig.layout : null
    if (!current || (!current.left && !current.center && !current.right)) return
    baseLayout = Presets.stripOwn(current)
    baseFile.setText(JSON.stringify({ version: 1, saved: new Date().toISOString(), layout: baseLayout }, null, 2) + "\n")
  }

  // ---------------------------------------------------------------- apply
  function apply(nextOptions) {
    if (!shell || typeof shell.mutateShellConfig !== "function") return "no shell"
    if (!baseLayout) captureBase()
    if (!baseLayout) return "no base layout"
    var opts = Presets.normalizeOptions(nextOptions)
    var layout = Presets.build(baseLayout, opts, moduleDir)
    shell.mutateShellConfig(function(cfg) {
      cfg.bar = cfg.bar || {}
      cfg.bar.layout = layout
      cfg.bar.amiga = { version: 1, options: opts }
    })
    return "ok"
  }

  function applyPreset(id) {
    var p = Presets.presetById(String(id))
    if (!p) return "unknown preset: " + id
    return apply(p.options)
  }

  function setVariant(element, variant) {
    var o = JSON.parse(JSON.stringify(options))
    o[String(element)] = String(variant)
    return apply(o)
  }

  // ---------------------------------------------------------------- options popup
  property bool optionsOpen: false
  function toggleOptions() { optionsOpen = !optionsOpen }

  // Anchor: the centre anchor (the island clock) on the focused screen.
  readonly property var optionsAnchor: {
    var slots = moduleSlots || []
    var screen = focusedScreenName()
    var fallback = null
    for (var i = 0; i < slots.length; i++) {
      var s = slots[i]
      if (!s || !s.activeItem) continue
      if (!fallback) fallback = s.activeItem
      if (s.moduleName === centerAnchor && (!screen || slotScreenName(s) === screen)) return s.activeItem
    }
    return fallback
  }

  OptionsPanel {
    host: root
    bar: root
    anchorItem: root.optionsAnchor
    isOpen: root.optionsOpen && root.optionsAnchor !== null
    onCloseRequested: root.optionsOpen = false
  }

  IpcHandler {
    target: "amiga-bar"
    function options(): void { root.toggleOptions() }
    function preset(id: string): string { return root.applyPreset(id) }
    function set(element: string, variant: string): string { return root.setVariant(element, variant) }
    function recaptureBase(): string { root.captureBase(); return "ok" }
    function state(): string {
      return JSON.stringify({ preset: root.presetId, options: root.options, hasBase: root.baseLayout !== null,
                              moduleDir: root.moduleDir, optionsOpen: root.optionsOpen })
    }
  }
}
