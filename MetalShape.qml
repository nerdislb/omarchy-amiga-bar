import QtQuick
import qs.Commons

// Liquid metal for the Chrom & Platin themes (design round 07.10.2026): a
// chrome tube along a rounded rect (kind "rim"), a ring with a filled arc
// ("ring", the quota rings), a cylinder bar ("pill", meters) or only a glint
// running along a rounded rect ("frame", window frames: `arc` is the glint's
// lead, the caller drives `sweep`/`sweepAmt`), drawn by shaders/metal.frag. The shape sits `pad` px inside the item, so the tube's
// soft edge has room.
// The metal stands still – a static picture, nothing redraws. play() runs a
// glint once along it (material `sweepMs`, 900 ms) with the coloured sparks of
// the moment; a material with `flow` > 0 (rad/s) lets the highlights flow all
// the time instead, like the original video. Reduced Motion: neither.
// `spec` is the theme's material.metal (bar-material.json).
// (Same component in the Tusche Island: keep both copies alike.)
ShaderEffect {
  id: m

  property var spec: null
  property string kind: "rim"
  property real pad: 3
  property real radius: 0
  property real tube: spec && spec.rim ? Number(spec.rim) : 1.6
  property real arc: 1
  property real dim: 0.2
  property color track: "transparent"
  // rings: 0 chrome all round (the rest dimmed), 1 chrome arc on a flat track, 2 solid arc (ink) with a chrome head
  property real ringStyle: 0
  property color ink: light ? "#1d1e21" : "#e6e7eb"
  property real boost: 0
  property real sweep: 0
  property real sweepAmt: 0
  property real t: 1.7

  readonly property bool light: !!spec && spec.light === true
  readonly property bool reduced: Style.reduceMotion
  readonly property real flowRate: spec && Number(spec.flow) > 0 ? Number(spec.flow) : 0

  readonly property vector2d size: Qt.vector2d(width, height)
  readonly property vector4d rect: Qt.vector4d(pad, pad, Math.max(1, width - 2 * pad), Math.max(1, height - 2 * pad))
  readonly property real mode: kind === "ring" ? 1 : kind === "pill" ? 2 : kind === "frame" ? 3 : 0
  readonly property real disp: spec && spec.disp !== undefined ? Number(spec.disp) : 0.8
  readonly property real spark: spec && spec.spark !== undefined ? Number(spec.spark) : 0.35
  readonly property real sharp: spec && spec.sharp !== undefined ? Number(spec.sharp) : 0.75
  readonly property real gain: spec && spec.gain !== undefined ? Number(spec.gain) : 1
  readonly property real base: spec && spec.base !== undefined ? Number(spec.base) : 1
  readonly property real lightOn: light ? 1 : 0
  property color tint: spec && spec.tint ? spec.tint : (light ? "#f7f8fa" : "#f2f3f7")

  blending: true
  fragmentShader: Qt.resolvedUrl("shaders/metal.frag.qsb")

  function play() {
    if (reduced || !visible || width <= 0) return
    glint.restart()
  }
  ParallelAnimation {
    id: glint
    readonly property int duration: m.spec && Number(m.spec.sweepMs) > 0 ? Number(m.spec.sweepMs) : 900
    NumberAnimation { target: m; property: "sweep"; from: -0.15; to: 1.15; duration: glint.duration; easing.type: Easing.InOutQuad }
    NumberAnimation { target: m; property: "sweepAmt"; from: 0.95; to: 0; duration: glint.duration; easing.type: Easing.InQuad }
  }
  // (a frame glint is driven from outside through a binding: leave it be)
  onReducedChanged: if (reduced && kind !== "frame") { glint.stop(); sweepAmt = 0 }
  FrameAnimation {
    running: m.visible && !m.reduced && m.flowRate > 0
    onTriggered: m.t += frameTime * m.flowRate
  }
}
