pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland

QtObject {
  property var instances: ({})
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
}
