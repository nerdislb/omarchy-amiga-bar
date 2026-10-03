import QtQuick
import QtQuick.Effects

// One Lavur bloom as a sheet of wet paper (Tusche & Papier, frame round
// 03.10.2026, recommendation 6 „getrockneter Pigmentrand“):
// - the paper: the blob and the flare up into the bar, blurred and cut at a
//   gently noise-displaced threshold – a calm edge, one large slow wobble
//   of about ±1 px, softer and drifting while wet (shaders/bloomcut.frag);
// - the wet ink while the water clears it from the source outward, its
//   residue evaporating with the water (shaders/wetink.frag);
// - the dried pigment: a rim just inside the edge, gathered in a few short
//   denser sections, a broken faint drying line further in, a trace of
//   residue near the edge only (shaders/restink.frag);
// - under it the halo: Papier a short soft ink wash, Tusche a flat dark
//   seam that hides window lines next to it plus a breath of moonlight.
// All noise is in the card's own coordinates (it travels with the card),
// and every sheet has its own mask: sheets never melt into each other.
// Geometry in this item's coordinates. Keep the blob `pad` (≥ 24) px from
// the edges; the flare may run out of the top (it continues into the bar).
// Theme values: bar-material.json card.rest (ridge, pool, echo, residue,
// halo); missing ones fall back to the study's.
// (Same component in the Amiga Island: keep both copies alike.)
Item {
  id: sheet

  // the blob, its corner radius, and the flare up into the bar above it
  property real blobX: 0
  property real blobY: 0
  property real blobW: 0
  property real blobH: 0
  property real radius: 12
  property bool neck: true
  property real flare: 14
  // the bar's lower edge: the flare starts 32 px above it, the rim runs out towards it
  property real barY: 0
  // the card's top-left: the noise's anchor
  property real originX: 0
  property real originY: 0

  // material: the paper (the bar's colour), the ink (the tide colour), the theme's card.rest
  property color paper: "white"
  property color ink: "black"
  property bool light: true
  property var rest: null
  property var haloBase: null    // card.halo, for the halo's fallback colour

  // the water: clearing 0 = all ink … 1 = cleared; wet 1 → 0 while it dries; phase moves it
  property real clearing: 1
  property real wet: 0
  property real phase: 0
  // where the water comes from, its front's full reach; nothing of the ink above inkTop
  property real sourceX: 0
  property real sourceY: 0
  property real reach: 1
  property real inkTop: 0
  property real band: 58
  property real jitter: 26
  property real seed: 5

  readonly property bool on: visible && blobW > 0 && blobH > 0

  function num(v, d) { return typeof v === "number" && isFinite(v) ? v : d }
  function rgba(hex, alpha) { var c = Qt.color(hex || "#000000"); return Qt.rgba(c.r, c.g, c.b, alpha === undefined ? 1 : alpha) }
  function sstep(e0, e1, x) { var t = Math.max(0, Math.min(1, (x - e0) / (e1 - e0))); return t * t * (3 - 2 * t) }

  readonly property real ridgeA: num(rest ? rest.ridge : undefined, light ? 0.86 : 0.7)
  readonly property real poolA: num(rest ? rest.pool : undefined, 0.3)
  readonly property real echoA: num(rest ? rest.echo : undefined, light ? 0.24 : 0.2)
  readonly property real residA: num(rest ? rest.residue : undefined, light ? 0.07 : 0.06)
  // halo parts: { color, alpha, blur (σ px), dx, dy, spread (each side), dh (height) }
  readonly property var halo: {
    if (rest && rest.halo) return rest.halo
    var hc = haloBase && haloBase.color ? haloBase.color : (light ? "#111111" : "#ffffff")
    var ha = num(haloBase ? haloBase.alpha : undefined, light ? 0.22 : 0.14)
    return light ? { wash: { color: hc, alpha: ha * 0.85, blur: 9, dx: 1, dy: 5, dh: -1 } }
      : { seam: { color: "#000000", alpha: 0.6, blur: 4, spread: 2, dh: 3 },
          glow: { color: hc, alpha: ha * 0.45, blur: 14, dy: 4, dh: -2 } }
  }

  // the wet ink: full while the water clears, then its residue evaporates with the water
  readonly property real wetAlpha: clearing < 0.999 ? 1 : sstep(0, 0.7, wet)
  // the rim comes in while the front reaches the edge; the residue near it as the wet one goes
  readonly property real show: sstep(0.55, 1, clearing)
  readonly property real dry: 1 - wetAlpha

  component Halo: Item {
    id: part
    property var spec: null
    readonly property real sigma: spec && spec.blur > 0 ? spec.blur : 8
    readonly property real spread: spec ? sheet.num(spec.spread, 0) : 0
    visible: sheet.on && !!spec && sheet.num(spec.alpha, 0) > 0
    width: sheet.width
    height: sheet.height
    // enabled only while shown: a MultiEffect created hidden never draws
    layer.enabled: visible
    layer.effect: MultiEffect { blurEnabled: true; blur: 1; blurMax: Math.max(2, Math.min(64, Math.round(3.2 * part.sigma))); autoPaddingEnabled: false }
    Rectangle {
      x: sheet.blobX - part.spread + (part.spec ? sheet.num(part.spec.dx, 0) : 0)
      y: sheet.blobY + (part.spec ? sheet.num(part.spec.dy, 0) : 0)
      width: Math.max(0, sheet.blobW + 2 * part.spread)
      height: Math.max(0, sheet.blobH + (part.spec ? sheet.num(part.spec.dh, 0) : 0))
      radius: sheet.radius + part.spread / 2
      color: part.spec ? sheet.rgba(part.spec.color, sheet.num(part.spec.alpha, 0)) : "transparent"
    }
  }
  Halo { spec: sheet.halo.seam || null }
  Halo { spec: sheet.halo.glow || null }
  Halo { spec: sheet.halo.wash || null }

  // the paper's shapes, white: the flare up into the bar and the blob (only
  // sizes change: a hidden layer does not repaint for a merely hidden shape)
  Item {
    id: shapes
    anchors.fill: parent
    visible: false
    layer.enabled: true
    Rectangle {
      x: sheet.blobX - sheet.flare
      y: sheet.barY - 32
      width: sheet.neck && sheet.blobW > 0 ? sheet.blobW + 2 * sheet.flare : 0
      height: Math.max(0, sheet.blobY - sheet.barY + 33)
      color: "white"
    }
    Rectangle {
      x: sheet.blobX
      y: sheet.blobY
      width: sheet.blobW
      height: sheet.blobH
      radius: sheet.radius
      color: "white"
    }
  }
  // the shapes blurred (σ 6), across and down
  ShaderEffect {
    id: paperH
    anchors.fill: parent
    visible: false
    layer.enabled: true
    layer.smooth: true
    blending: false
    property var src: shapes
    property point dir: Qt.point(1 / Math.max(1, width), 0)
    property real s1: 6
    property real s2: 0
    property real first: 1
    fragmentShader: Qt.resolvedUrl("shaders/gauss.frag.qsb")
  }
  ShaderEffect {
    id: paperV
    anchors.fill: parent
    visible: false
    layer.enabled: true
    layer.smooth: true
    blending: false
    property var src: paperH
    property point dir: Qt.point(0, 1 / Math.max(1, height))
    property real s1: 6
    property real s2: 0
    property real first: 0
    fragmentShader: Qt.resolvedUrl("shaders/gauss.frag.qsb")
  }
  // the paper: cut at a gently displaced threshold (lo/hi as the fog's
  // threshold 0.4, spread 0.5: 0.1–0.6, narrowed to the middle once dry)
  ShaderEffect {
    id: cut
    anchors.fill: parent
    visible: sheet.on
    property var blurred: paperV
    property size size: Qt.size(width, height)
    property point origin: Qt.point(sheet.originX, sheet.originY)
    property real drift: 10 * sheet.wet * Math.sin(sheet.phase * 0.8)
    property real lo: 0.35 - 0.25 * (0.45 + 0.75 * sheet.wet)
    property real hi: 0.35 + 0.25 * (0.45 + 0.75 * sheet.wet)
    property real amp: 0.11 + 0.13 * sheet.wet
    property color paper: Qt.rgba(sheet.paper.r, sheet.paper.g, sheet.paper.b, 1)
    fragmentShader: Qt.resolvedUrl("shaders/bloomcut.frag.qsb")
  }
  // the paper, drawn from its cached texture (redrawn only when the cut
  // changes, not with every repaint of the window), and the mask for the
  // ink and the pigment
  ShaderEffectSource {
    id: paperMask
    anchors.fill: parent
    sourceItem: cut
    hideSource: true
    live: true
    visible: sheet.on
  }

  // the wet ink over the paper, below inkTop
  ShaderEffect {
    id: wetInk
    visible: sheet.on && sheet.wetAlpha > 0.004
    opacity: sheet.wetAlpha
    y: sheet.inkTop
    width: sheet.width
    height: Math.max(1, sheet.height - sheet.inkTop)
    property var mask: paperMask
    property size size: Qt.size(sheet.width, sheet.height)
    property point center: Qt.point(sheet.sourceX, sheet.sourceY)
    property rect region: Qt.rect(0, y, width, height)
    property color ink: Qt.rgba(sheet.ink.r, sheet.ink.g, sheet.ink.b, 1)
    property real front: sheet.reach * 1.15 * sheet.clearing
    property real band: sheet.band
    property real body: sheet.light ? 0.44 : 0.34
    property real ridge: sheet.light ? 0.38 : 0.3
    property real resid: sheet.light ? 0.08 : 0.07
    property real jitter: sheet.jitter
    property real seed: sheet.seed
    fragmentShader: Qt.resolvedUrl("shaders/wetink.frag.qsb")
  }

  // the pigment's distance to the edge: the paper's mask blurred with σ 2.2 (.r) and σ 4 (.g)
  ShaderEffect {
    id: edgeH
    anchors.fill: parent
    visible: false
    layer.enabled: true
    layer.smooth: true
    blending: false
    property var src: paperMask
    property point dir: Qt.point(1 / Math.max(1, width), 0)
    property real s1: 2.2
    property real s2: 4
    property real first: 1
    fragmentShader: Qt.resolvedUrl("shaders/gauss.frag.qsb")
  }
  ShaderEffect {
    id: edgeV
    anchors.fill: parent
    visible: false
    layer.enabled: true
    layer.smooth: true
    blending: false
    property var src: edgeH
    property point dir: Qt.point(0, 1 / Math.max(1, height))
    property real s1: 2.2
    property real s2: 4
    property real first: 0
    fragmentShader: Qt.resolvedUrl("shaders/gauss.frag.qsb")
  }
  // the dried pigment (cached in its layer: once dry it costs nothing on a repaint)
  ShaderEffect {
    id: pigment
    anchors.fill: parent
    visible: sheet.on && (sheet.show > 0 || sheet.dry > 0)
    layer.enabled: visible
    property var mask: paperMask
    property var blurs: edgeV
    property size size: Qt.size(width, height)
    property point origin: Qt.point(sheet.originX, sheet.originY)
    property color ink: Qt.rgba(sheet.ink.r, sheet.ink.g, sheet.ink.b, 1)
    property real ridge: sheet.ridgeA
    property real pool: sheet.poolA
    property real echo: sheet.echoA
    property real resid: sheet.residA
    property real show: sheet.show
    property real dry: sheet.dry
    property real barY: sheet.barY
    fragmentShader: Qt.resolvedUrl("shaders/restink.frag.qsb")
  }
}
