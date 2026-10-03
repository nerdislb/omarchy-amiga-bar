import QtQuick
import "bridge" as Bridge

// The theme material (and the fog look) for Omarchy's own popups – the
// KeyboardPanels of the native widgets the Amiga Bar hosts (folded into the
// status groups, or wrapped visibly by modules/Native.qml). It finds each
// widget's KeyboardPanel and hangs a FogPanel into its content, exactly as
// our own popups declare one, so the native network or audio popup rolls,
// casts the theme's shadow or blooms like ours. Omarchy's code stays as it
// is: a popup this search does not recognise keeps Omarchy's own look.
// Without fog and material nothing changes (edge: false – no extra line or
// shadow on Omarchy's popups).
QtObject {
  id: dress

  property bool enabled: true
  // panels that already carry a FogPanel
  property var dressed: []
  readonly property Component fogComponent: Component { FogPanel {} }

  // A KeyboardPanel (Omarchy's Ui/KeyboardPanel.qml), recognised by its API.
  function isPanel(o) {
    return !!o && o.borderSpec !== undefined && o.anchorItem !== undefined && o.contentItem !== undefined
      && typeof o.fittedContentHeight === "function" && o.barPos !== undefined
  }
  function panelsIn(o, depth, out) {
    if (!o || depth > 3) return out
    if (isPanel(o)) { out.push(o); return out }
    var kids = o.data || []
    for (var i = 0; i < kids.length; i++) panelsIn(kids[i], depth + 1, out)
    return out
  }
  // the panel's content holder: the parent of its content (the card is the holder's parent)
  function holderOf(panel) {
    var c = panel.contentItem
    var first = c && c.length > 0 ? c[0] : null
    var h = first ? first.parent : null
    return h && h.parent && h.parent.borderSpec !== undefined ? h : null
  }
  // Dress every KeyboardPanel inside `item` (a hosted native widget); returns how many were new.
  function attach(item) {
    if (!enabled || !item) return 0
    var panels = panelsIn(item, 0, []), added = []
    for (var i = 0; i < panels.length; i++) {
      var p = panels[i]
      if (dressed.indexOf(p) !== -1) continue
      var holder = holderOf(p)
      if (!holder) continue
      var fp = fogComponent.createObject(holder, {
        panel: p,
        edge: false,
        fog: Qt.binding(function() { return Bridge.ModuleBus.fog }),
        color: Qt.binding(function() { return Bridge.ModuleBus.fogColor }),
        material: Qt.binding(function() { return Bridge.ModuleBus.material })
      })
      if (fp) added.push(p)
    }
    if (added.length) dressed = dressed.concat(added)
    return added.length
  }
  // a destroyed widget takes its panels (and their FogPanels) along: forget them
  function forget() {
    dressed = dressed.filter(function(p) { return !!p && p.borderSpec !== undefined })
  }
}
