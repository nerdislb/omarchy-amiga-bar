pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.Commons

QtObject {
  property var instances: ({})
  // The bar colour as an opaque ink/fill (Color.bar.background has alpha 0
  // while Omarchy's bar is transparent).
  readonly property color barColor: Qt.rgba(Color.bar.background.r, Color.bar.background.g, Color.bar.background.b, 1)
  // Light themes (Papier …): Qt.lighter() runs into white there, so raised
  // and sunken parts are drawn the other way round.
  function isLight(c) { return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b > 0.55 }
  readonly property bool barLight: isLight(barColor)
  // The engine, for modules that show its menus (set by the engine).
  property var engine: null
  // the current theme's bar material (bar-material.json) while the edge option
  // is "theme"; null otherwise. MaterialCard styles cards with it.
  property var material: null
  // the current theme folder and a counter bumped on every theme switch (reload images
  // that keep their file name, e.g. the Lavur menu brush)
  property string themeDir: ""
  property int themeStamp: 0
  function register(kind, item) {
    var next = Object.assign({}, instances)
    next[kind] = (next[kind] || []).filter(function(i) { return i !== item }).concat([item])
    instances = next
  }
  function unregister(kind, item) {
    var next = Object.assign({}, instances)
    next[kind] = (next[kind] || []).filter(function(i) { return i !== item })
    instances = next
  }
  function pick(kind) {
    var candidates = (instances[kind] || []).filter(function(i) { return i && i.QsWindow.window && i.QsWindow.window.visible })
    var focus = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
    for (var i = 0; i < candidates.length; i++) {
      var screen = candidates[i].QsWindow.window.screen
      if (screen && screen.name === focus) return candidates[i]
    }
    return candidates.length ? candidates[0] : null
  }

  // ---- AI usage records: modules ask, the engine runs the collectors
  // ("normal" · "limits" = limits only, cheap · "force").
  signal usageRefreshRequested(string kind)
  function requestUsageRefresh(kind) { usageRefreshRequested(String(kind || "normal")) }
}
