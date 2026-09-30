.pragma library

// Presets and layout building for the Amiga Bar. Pure functions: the bar
// passes in the saved base layout (the user's own layout from before the
// first preset) and the chosen options, and gets a full bar.layout back.
//
// Options: { workspaces, ai, right, centre, effects, font } — see ELEMENTS.
// effects/font are read by the Amiga Island too (Guru look, Boing, Copper, Topaz).

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
  },
  ai: {
    label: "AI-Kontingente",
    variants: [
      { id: "today", label: "Wie heute" },
      { id: "gauge", label: "Tankanzeige" },
      { id: "vu", label: "Tracker-VU" },
      { id: "rings", label: "Ringe" },
      { id: "ondemand", label: "Nur bei Bedarf" }
    ]
  },
  right: {
    label: "Rechte Seite",
    variants: [
      { id: "today", label: "Wie heute" },
      { id: "groups", label: "Gruppen" },
      { id: "deviations", label: "Nur Abweichungen" },
      { id: "drawer", label: "Schublade" }
    ]
  },
  centre: {
    label: "Mitte",
    variants: [
      { id: "today", label: "Wie heute" },
      { id: "calm", label: "Temperatur am Wetter" }
    ]
  },
  effects: {
    label: "Ereignisse",
    variants: [
      { id: "plain", label: "Omarchy-Stil" },
      { id: "amiga", label: "Amiga-Effekte (Boing, Copper, Guru-Look)" }
    ]
  },
  font: {
    label: "Amiga-Schrift (Topaz)",
    variants: [
      { id: "theme", label: "Theme-Schrift" },
      { id: "topaz", label: "Topaz für Amiga-Momente" }
    ]
  }
}

// Presets from the concept film.
var PRESETS = [
  { id: "heute", label: "Heute", note: "Deine Bar wie vorher",
    options: { workspaces: "today", ai: "today", right: "today", centre: "today", effects: "plain", font: "theme" } },
  { id: "k1", label: "K1 · Aufgeräumt", note: "Pips · Tank · Gruppen",
    options: { workspaces: "pips", ai: "gauge", right: "groups", centre: "calm", effects: "plain", font: "theme" } },
  { id: "k2", label: "K2 · Workbench", note: "Logo · VU · Schublade",
    options: { workspaces: "logo", ai: "vu", right: "drawer", centre: "calm", effects: "amiga", font: "topaz" } },
  { id: "k3", label: "K3 · Fokus", note: "Stapel · Bedarf · Abweichungen",
    options: { workspaces: "stack", ai: "ondemand", right: "deviations", centre: "calm", effects: "plain", font: "theme" } }
]

// Native widgets a variant folds into our own modules (removed from the
// layout; our modules show their state and controls instead). Mail and
// WhatsApp always stay native: their widgets need their own services.
var AI_IDS = ["nerdibeard.ai-usage", "omarchy.agents"]
var GROUPED = {
  net: ["omarchy.network", "io.github.iamfitsum.omarchy-proton-vpn", "omarchy.tailscale", "omarchy.bluetooth"],
  phone: ["flux", "io.github.nerdislb.buds-control"],
  system: ["bitr0t.system-monitor", "nerdibeard.monitor", "nerdibeard.googledrive", "com.omastorm.radar", "community.plugin-manager"]
}
var DRAWER = ["flux", "com.omastorm.radar", "io.github.nerdislb.buds-control", "bitr0t.system-monitor", "nerdibeard.googledrive",
              "io.github.iamfitsum.omarchy-proton-vpn", "community.plugin-manager", "omarchy.tailscale", "omarchy.bluetooth", "nerdibeard.monitor"]
var CENTRE_IDS = ["omarchy.weather", "omarchy.elsewhen"]

function groupedIds() {
  var out = []
  for (var g in GROUPED) out = out.concat(GROUPED[g])
  return out
}

// Ids removed from the layout for these options.
function foldedIds(options) {
  var o = normalizeOptions(options)
  var out = []
  if (o.ai !== "today") out = out.concat(AI_IDS)
  if (o.right === "groups" || o.right === "deviations") out = out.concat(groupedIds())
  else if (o.right === "drawer") out = out.concat(DRAWER)
  if (o.right !== "today" && out.indexOf("omarchy.agents") === -1) out.push("omarchy.agents")
  return out
}

function removeIds(layout, ids) {
  var sections = ["left", "center", "right"]
  for (var s = 0; s < sections.length; s++)
    layout[sections[s]] = layout[sections[s]].filter(function(e) { return ids.indexOf(entryId(e)) === -1 })
}

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
  var o = normalizeOptions(options)
  var ws = String(o.workspaces || "today")
  if (ws !== "today") {
    var entry = { id: "amiga.workspaces", source: moduleDir + "/Workspaces.qml", variant: ws, menu: true }
    if (!replaceGroup(layout, ["omarchy.menu", "omarchy.workspaces"], entry)) layout.left.unshift(entry)
  }
  var topaz = o.font === "topaz"
  // Insert our modules where the widgets they replace sat, then fold.
  if (o.ai && o.ai !== "today") {
    var q = { id: "amiga.quota", source: moduleDir + "/Quota.qml", variant: String(o.ai), topaz: topaz }
    if (!insertBefore(layout, "nerdibeard.ai-usage", q)) layout.left.push(q)
  }
  if (o.right && o.right !== "today") {
    // Folded widgets travel along with their own settings: the status
    // module mounts them invisibly so their native popups keep working.
    var embeds = {}
    var fold = foldedIds(o)
    var sections = ["left", "center", "right"]
    for (var si = 0; si < sections.length; si++) {
      var list = layout[sections[si]]
      for (var li = 0; li < list.length; li++) {
        var eid = entryId(list[li])
        if (fold.indexOf(eid) === -1 || AI_IDS.indexOf(eid) !== -1 || CENTRE_IDS.indexOf(eid) !== -1) continue
        var es = typeof list[li] === "object" ? copy(list[li]) : {}
        delete es.id
        embeds[eid] = es
      }
    }
    var st = { id: "amiga.status", source: moduleDir + "/Status.qml", variant: String(o.right), topaz: topaz, embeds: embeds }
    if (!insertBefore(layout, "omarchy.audio", st)) layout.right.push(st)
  }
  // Weather and world clocks stay native (their popups position
  // themselves through the centre section); we add the temperature.
  if (o.centre === "calm") {
    var centre = { id: "amiga.centre", source: moduleDir + "/Centre.qml" }
    if (!insertAfter(layout, "omarchy.weather", centre)) layout.center.push(centre)
  }
  removeIds(layout, foldedIds(o))
  // Workspaces carry the font choice too.
  for (var s = 0; s < layout.left.length; s++)
    if (entryId(layout.left[s]) === "amiga.workspaces") layout.left[s].topaz = topaz
  return layout
}

function insertAfter(layout, id, entry) {
  var sections = ["left", "center", "right"]
  for (var s = 0; s < sections.length; s++) {
    var list = layout[sections[s]]
    for (var i = 0; i < list.length; i++) if (entryId(list[i]) === id) { list.splice(i + 1, 0, entry); return true }
  }
  return false
}

function insertBefore(layout, id, entry) {
  var sections = ["left", "center", "right"]
  for (var s = 0; s < sections.length; s++) {
    var list = layout[sections[s]]
    for (var i = 0; i < list.length; i++) if (entryId(list[i]) === id) { list.splice(i, 0, entry); return true }
  }
  return false
}

function normalizeOptions(o) {
  var out = {}
  for (var key in ELEMENTS) {
    var v = o && o[key] ? String(o[key]) : ELEMENTS[key].variants[0].id
    var ok = ELEMENTS[key].variants.some(function(x) { return x.id === v })
    out[key] = ok ? v : ELEMENTS[key].variants[0].id
  }
  return out
}

function matchPreset(options) {
  var n = normalizeOptions(options)
  for (var i = 0; i < PRESETS.length; i++)
    if (JSON.stringify(normalizeOptions(PRESETS[i].options)) === JSON.stringify(n)) return PRESETS[i].id
  return ""
}
