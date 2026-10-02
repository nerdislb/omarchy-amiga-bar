import QtQuick
import Quickshell
import Quickshell.Io
import "vendor/MenuModel.js" as MenuModel

// The Omarchy menu's own definition for the drop-down logo menu: the
// shipped omarchy-menu.jsonc with the user's extensions merged on top, and
// the `when:` / `checked:` / `disabled:` guards answered in one batch — the
// same reading as the native menu (vendor/MenuModel.js is its library).
// Rows open on the last answers; evaluate() refreshes them.
Item {
  id: src

  readonly property string omarchyPath: Quickshell.env("OMARCHY_PATH") || (Quickshell.env("HOME") + "/.local/share/omarchy")
  property var defaultItems: []
  property var userItems: []
  property var items: ({})
  property var itemOrder: []
  property var whenResults: ({})
  property var checkedResults: ({})
  property var disabledResults: ({})
  property bool pending: false
  // While the menu is up, a changed definition is re-checked at once.
  property bool live: false

  function rebuild() {
    var merged = MenuModel.mergeMenuSources(defaultItems, userItems)
    items = merged.items
    itemOrder = merged.itemOrder
    if (live) evaluate()
  }

  FileView {
    id: defaultFile
    path: src.omarchyPath + "/default/omarchy/omarchy-menu.jsonc"
    watchChanges: true
    printErrors: false
    onLoaded: { src.defaultItems = MenuModel.parseMenuJsonc(text()); src.rebuild() }
    onLoadFailed: { src.defaultItems = []; src.rebuild() }
    onFileChanged: reload()
  }
  FileView {
    id: userFile
    path: Quickshell.env("HOME") + "/.config/omarchy/extensions/omarchy-menu.jsonc"
    watchChanges: true
    printErrors: false
    onLoaded: { src.userItems = MenuModel.parseMenuJsonc(text()); src.rebuild() }
    onLoadFailed: { src.userItems = []; src.rebuild() }
    onFileChanged: reload()
  }

  function entry(id) { return MenuModel.item(items, id) }
  function shown(e) { return MenuModel.isVisible(items, itemOrder, whenResults, e, 0) }

  // A row for the view. kind: "menu" (opens inside the drop-down),
  // "provider" (a list the shell fills in, e.g. Apps: opens the native
  // menu there), "action".
  function row(e) {
    var target = e.kind === "link" ? e.target : e.id
    return {
      id: e.id, target: target, label: e.label, title: e.title || e.label,
      icon: e.icon || "", iconFont: e.iconFont || "",
      kind: e.provider ? "provider" : (e.kind === "menu" || e.kind === "link") ? "menu" : "action",
      action: e.action || "",
      checked: !!(e.checked && checkedResults[e.id]) || MenuModel.isDisabled(disabledResults, e),
      disabled: MenuModel.isDisabled(disabledResults, e),
      path: MenuModel.parentPathFor(items, e.id)
    }
  }

  function children(menuId) {
    var out = []
    for (var i = 0; i < itemOrder.length; i++) {
      var e = items[itemOrder[i]]
      if (!e || e.parent !== menuId || e.kind === "app") continue
      if (!shown(e)) continue
      out.push(row(e))
    }
    return out
  }

  // Search over the whole tree, ranked the native way.
  function search(query, limit) {
    var q = String(query || "").trim()
    if (!q) return []
    var hits = []
    for (var i = 0; i < itemOrder.length; i++) {
      var e = items[itemOrder[i]]
      if (!e || e.kind === "app" || e.id === "root") continue
      var listed = shown(e) && ancestorsVisible(e)
      if (!MenuModel.matchesQuery(e, q, listed)) continue
      hits.push({ score: MenuModel.searchScore(items, e, q), row: row(e) })
    }
    hits.sort(function(a, b) { return a.score - b.score })
    return hits.slice(0, limit || 40).map(function(h) { return h.row })
  }
  function ancestorsVisible(e) {
    var p = entry(e.parent), guard = 0
    while (p && p.id !== "root" && guard++ < 32) {
      if (!shown(p)) return false
      p = entry(p.parent)
    }
    return true
  }

  function evaluate() {
    if (guardProc.running) { pending = true; return }
    pending = false
    var script = MenuModel.guardScript(items)
    if (!script) { whenResults = ({}); checkedResults = ({}); disabledResults = ({}); return }
    guardProc.collected = ""
    guardProc.command = ["bash", "-lc", script]
    guardProc.running = true
  }

  Process {
    id: guardProc
    property string collected: ""
    stdout: SplitParser { onRead: function(data) { guardProc.collected += data + "\n" } }
    onExited: function(exitCode, exitStatus) {
      if (exitCode === 0 && exitStatus === 0) {
        var w = ({}), c = ({}), d = ({})
        var lines = guardProc.collected.split("\n")
        for (var i = 0; i < lines.length; i++) {
          var line = lines[i].trim()
          var colon = line.lastIndexOf(":")
          if (colon < 0) continue
          var value = line.substring(colon + 1) === "1"
          var rest = line.substring(0, colon)
          var tagAt = rest.lastIndexOf(":")
          if (tagAt < 0) continue
          var id = rest.substring(0, tagAt), tag = rest.substring(tagAt + 1)
          if (tag === "w") w[id] = value
          else if (tag === "c") c[id] = value
          else if (tag === "d") d[id] = value
        }
        src.whenResults = w; src.checkedResults = c; src.disabledResults = d
      }
      if (src.pending) Qt.callLater(src.evaluate)
    }
  }
}
