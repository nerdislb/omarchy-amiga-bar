pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.Commons

QtObject {
  property var instances: ({})
  // Fog look (test), set by the engine from the `fog` option.
  property bool fog: false
  property color fogColor: "black"
  // A500 form: a note is coming out of the drive slot (DF0 lights).
  property bool noteActive: false
  property string noteScreen: ""
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

  // ---- typography (set by the engine from the "font" option)
  // theme: theme font everywhere · topaz: NerdWorkbench for Amiga moments
  // (menu strip, requester, Guru, title line) · bar/desktop: NerdWorkbench
  // for all Amiga Bar and Island text and icons. The pixel font is only crisp
  // on its 16 px grid, so every size collapses to 16 (or 32 for display).
  property string fontLevel: "theme"
  readonly property bool pixelAll: fontLevel === "bar" || fontLevel === "desktop"
  readonly property bool pixelMoments: fontLevel !== "theme"
  property FontLoader pixelRegular: FontLoader { source: Qt.resolvedUrl("../assets/fonts/nerdworkbench/NerdWorkbenchMono-Regular.ttf") }
  property FontLoader pixelBold: FontLoader { source: Qt.resolvedUrl("../assets/fonts/nerdworkbench/NerdWorkbenchMono-Bold.ttf") }
  readonly property string pixelFamily: pixelRegular.status === FontLoader.Ready ? pixelRegular.name : "NerdWorkbench Mono"
  readonly property string family: pixelAll ? pixelFamily : Style.font.family
  readonly property string momentFamily: pixelMoments ? pixelFamily : Style.font.family
  function px(size) { return pixelAll ? (size >= 24 ? 32 : 16) : size }
  function momentPx(size) { return pixelMoments ? (size >= 24 ? 32 : 16) : size }
}
