.pragma library

// Presets and layout building for the Amiga Bar. Pure functions: the bar
// passes in the saved base layout (the user's own layout from before the
// first preset) and the chosen options, and gets a full bar.layout back.
//
// Options: { workspaces: "today"|"pips"|"stack"|"logo"|"minimap"|"cli"|"boing" }
// (more elements follow in stage B: ai, right, centre).

var ELEMENTS = {
  workspaces: {
    label: "Arbeitsbereiche",
    variants: [
      { id: "today", label: "Wie heute" },
      { id: "pips", label: "Pips" },
      { id: "stack", label: "Screen-Stapel" },
      { id: "logo", label: "Logo trägt die Nummer" },
      { id: "minimap", label: "Mini-Karte" },
      { id: "cli", label: "CLI-Prompt 2>" },
      { id: "boing", label: "Boing-Schiene" }
    ]
  }
}

// Presets from the concept film. Elements not built yet stay "today".
var PRESETS = [
  { id: "heute", label: "Heute", note: "Deine Bar wie vorher", options: { workspaces: "today" } },
  { id: "k1", label: "K1 · Aufgeräumt", note: "Pips (Etappe A)", options: { workspaces: "pips" } },
  { id: "k2", label: "K2 · Workbench", note: "Logo-Nummer (Etappe A)", options: { workspaces: "logo" } },
  { id: "k3", label: "K3 · Fokus", note: "Screen-Stapel (Etappe A)", options: { workspaces: "stack" } }
]

var OWN_PREFIX = "amiga."

function presetById(id) {
  for (var i = 0; i < PRESETS.length; i++) if (PRESETS[i].id === id) return PRESETS[i]
  return null
}

function copy(v) { return JSON.parse(JSON.stringify(v)) }

function entryId(e) { return typeof e === "string" ? e : (e && e.id ? String(e.id) : "") }

// The user's layout without anything this plugin added.
function stripOwn(layout) {
  var out = { left: [], center: [], right: [] }
  var sections = ["left", "center", "right"]
  for (var s = 0; s < sections.length; s++) {
    var list = layout && Array.isArray(layout[sections[s]]) ? layout[sections[s]] : []
    for (var i = 0; i < list.length; i++)
      if (entryId(list[i]).indexOf(OWN_PREFIX) !== 0) out[sections[s]].push(copy(list[i]))
  }
  return out
}

function hasOwn(layout) {
  var sections = ["left", "center", "right"]
  for (var s = 0; s < sections.length; s++) {
    var list = layout && Array.isArray(layout[sections[s]]) ? layout[sections[s]] : []
    for (var i = 0; i < list.length; i++) if (entryId(list[i]).indexOf(OWN_PREFIX) === 0) return true
  }
  return false
}

// Replace the ids in `remove` (in whichever section they sit) by `entry`,
// placed where the first of them was. Returns true if something matched.
function replaceGroup(layout, remove, entry) {
  var sections = ["left", "center", "right"]
  for (var s = 0; s < sections.length; s++) {
    var list = layout[sections[s]]
    var at = -1
    for (var i = list.length - 1; i >= 0; i--) {
      if (remove.indexOf(entryId(list[i])) !== -1) { at = i; list.splice(i, 1) }
    }
    if (at !== -1) { list.splice(at, 0, entry); return true }
  }
  return false
}

// base: saved user layout; options: element -> variant; moduleDir: absolute
// path of this plugin's modules/ directory.
function build(base, options, moduleDir) {
  var layout = stripOwn(base)
  var o = options || {}
  var ws = String(o.workspaces || "today")
  if (ws !== "today") {
    var entry = { id: "amiga.workspaces", source: moduleDir + "/Workspaces.qml", variant: ws, menu: true }
    if (!replaceGroup(layout, ["omarchy.menu", "omarchy.workspaces"], entry)) layout.left.unshift(entry)
  }
  return layout
}

function normalizeOptions(o) {
  var out = {}
  for (var key in ELEMENTS) {
    var v = o && o[key] ? String(o[key]) : "today"
    var ok = ELEMENTS[key].variants.some(function(x) { return x.id === v })
    out[key] = ok ? v : "today"
  }
  return out
}

function matchPreset(options) {
  var n = normalizeOptions(options)
  for (var i = 0; i < PRESETS.length; i++)
    if (JSON.stringify(normalizeOptions(PRESETS[i].options)) === JSON.stringify(n)) return PRESETS[i].id
  return ""
}
