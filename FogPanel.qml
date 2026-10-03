import QtQuick
import QtQuick.Effects
import qs.Commons

// Fog look (Amiga Bar option `fog`, a test) for an Omarchy KeyboardPanel.
// Without fog but with a theme material (edge option "theme": the theme's
// bar-material.json, Tusche & Papier) the card takes the theme's light and
// shadow instead – a hard ink shadow (Papier), a light halo (Tusche, Lavur)
// – and rolls out of the bar from the top, and back up when it closes.
// A material card with `bloom` (the Lavur themes) blooms instead: the fog's
// growth out of the bar, but with a wet, scalloped edge and a darker tide
// line (`tide`) – ink spreading on wet paper, standing still once open.
// Declare it inside the panel. While `fog` is on it takes the card's own
// fill and frame away and grows a fog blob out of the bar behind it: a drop
// under the anchor, then the card's size; the content fades in last.
// Closing: the content fades, the blob shrinks back into the bar and a
// faint fog lingers for a moment. Top bars only; elsewhere, and with fog
// off, the card stays Omarchy's own.
// (Same component in the Amiga Island: keep both copies alike.)
Item {
  id: fp

  property var panel: null
  property bool fog: false
  // The colour the bar ends in (opaque).
  property color color: Qt.rgba(Color.bar.background.r, Color.bar.background.g, Color.bar.background.b, 1)
  // Edge, with and without fog: a faint line in the text colour and a soft
  // shadow, so a popup in the bar's colour still stands apart from windows
  // of the same colour behind it. With fog the line follows the fog's shape.
  property bool edge: true
  readonly property bool lightTheme: 0.2126 * Color.popups.background.r + 0.7152 * Color.popups.background.g + 0.0722 * Color.popups.background.b > 0.55
  readonly property color rimColor: Util.alpha(Color.popups.text, lightTheme ? 0.24 : 0.22)
  readonly property real rim: 1.5
  // the line around the fog: faint rim, or the bloom's tide line – lighter
  // while the pigment is still on its way out, wider and softer while wet
  readonly property var tide: bloom && material && material.card ? material.card.tide || null : null
  readonly property color edgeColor: tide ? rgba(tide.color, tide.alpha * (0.4 + 0.6 * clearing)) : rimColor
  readonly property real edgeW: tide ? (tide.width || 2) * (1 + 0.35 * wet) : rim
  readonly property real edgeSoftness: bloom ? 0.5 + 0.18 * wet : 0.5

  // Wet bloom (Lavur): the ink fills the bloom, the water clears it from the
  // source outward and pushes the pigment as a ridge into the tide line
  // (shaders/wetink.frag); while wet the edge is soft and its scallops move,
  // drying it sharpens and stills – as in the bar round's film.
  property real clearing: 1  // 0 = all ink, 1 = cleared up to the tide line
  property real wet: 0       // 1 = wet, 0 = dry
  property real phase: 0     // the scallops' movement while wet
  readonly property color inkColor: tide ? rgba(tide.color, 1) : Color.popups.text
  // the clearing front's reach: the farthest corner of the card seen from the source, plus a margin
  readonly property real clearFar: {
    if (!card) return 1
    var sx = dropCx, sy = barBottom, far = 0
    var xs = [card.x, card.x + card.width], ys = [card.y, card.y + card.height]
    for (var i = 0; i < 2; i++) for (var j = 0; j < 2; j++) far = Math.max(far, Math.hypot(xs[i] - sx, ys[j] - sy))
    return far + 30
  }
  ParallelAnimation {
    id: wetting
    // the water follows the ink: it starts clearing once the drop spreads
    // (the first ~30 % of the growth is the drop) and passes the far corner
    // after the bloom has reached its size
    SequentialAnimation {
      PauseAnimation { duration: 200 }
      NumberAnimation { target: fp; property: "clearing"; from: 0; to: 1; duration: 720; easing.type: Easing.InOutQuad }
    }
    NumberAnimation { target: fp; property: "wet"; from: 1; to: 0; duration: 1700; easing.type: Easing.InQuad }
    NumberAnimation { target: fp; property: "phase"; from: 0; to: 6.283; duration: 1700 }
  }
  function settle() { wetting.stop(); clearing = 1; wet = 0 }
  // the bloom's soft halo under the blob, else the fog's shadow
  readonly property color shadeColor: bloom && mat && mat.halo ? rgba(mat.halo.color, mat.halo.alpha) : Qt.rgba(0, 0, 0, shadowOpacity)

  // Bloom: scallops along the blob's sides and foot (fixed pseudo-random
  // sizes; they follow the blob as it grows and come in with it)
  readonly property int scallopCount: 34
  // per scallop: where along the outline (0–1) and its size – computed once
  readonly property var scallopSeeds: {
    var out = []
    for (var i = 0; i < scallopCount; i++) {
      var k = Math.abs(Math.sin(i * 78.233) * 43758.5453) % 1
      out.push({ u: (i + 0.5 + 0.3 * Math.sin(i * 12.9898)) / scallopCount, r: 4 + 10 * k * k })
    }
    return out
  }
  function scallopAt(i) {
    var b = blob, per = 2 * b.h + b.w, sd = scallopSeeds[i]
    var u = sd.u * per, x, y
    if (u < b.h) { x = 0; y = u }
    else if ((u -= b.h) < b.w) { x = u; y = b.h }
    else { u -= b.w; x = b.w; y = Math.max(0, b.h - u) }
    var swell = 1 + 0.28 * wet * Math.sin(phase * 1.7 + i * 1.3)   // wet scallops move
    return { x: b.x + x, y: y, r: sd.r * swell * Math.max(0, Math.min(1, (grow - 0.3) / 0.5)) }
  }
  readonly property real shadowOpacity: lightTheme ? 0.22 : 0.55

  // Inside the panel we sit in its content holder; its parent is the card,
  // and the card's parent the panel window's root item.
  readonly property Item card: parent && parent.parent && parent.parent.borderSpec !== undefined ? parent.parent : null
  readonly property Item surface: card ? card.parent : null
  // Lavur material: the fog machinery, styled as a bloom
  readonly property bool bloomWanted: !fog && !!material && !!material.card && material.card.bloom === true
  readonly property bool active: (fog || bloomWanted) && !!card && !!surface && !!panel && panel.barPos === "top"
  readonly property bool bloom: active && !fog
  readonly property bool reduced: Style.reduceMotion

  // Theme material (bar-material.json; set while the edge option is "theme").
  property var material: null
  readonly property var mat: material && material.card ? material.card : null
  readonly property bool matOn: !fog && !!mat && mat.bloom !== true && !!card && !!surface && !!panel
  readonly property bool rolls: matOn && mat.roll !== false && panel.barPos === "top"
  property real roll: 0      // 0 = rolled up into the bar, 1 = open
  // only while it is out or on its way (closed, the card and its mask need no layer)
  readonly property bool rolling: rolls && roll < 0.999 && (panel.open || roll > 0.001)
  function rgba(hex, alpha) { var c = Qt.color(hex || "#000000"); return Qt.rgba(c.r, c.g, c.b, alpha === undefined ? 1 : alpha) }
  // the card's own shadow/halo from the material (null: the default soft shadow)
  readonly property var matShadow: !mat ? null : (mat.shadow ? { color: rgba(mat.shadow.color, mat.shadow.alpha), dx: mat.shadow.dx || 0, dy: mat.shadow.dy || 0, blur: 0 }
    : mat.halo ? { color: rgba(mat.halo.color, mat.halo.alpha), dx: 0, dy: 6, blur: mat.halo.blur || 40 }
    : mat.glow ? { color: rgba(mat.glow.color, mat.glow.alpha), dx: 0, dy: 0, blur: mat.glow.blur || 18 } : null)

  property real grow: 0      // 0 = inside the bar, 1 = the card's size
  property real ink: 1       // the content's opacity

  readonly property real margin: 32
  readonly property real dropW: 52
  readonly property real dropH: 28
  readonly property real barBottom: card && panel ? card.y - panel.gap : 0
  readonly property real dropCx: {
    if (!card || !panel) return 0
    var cx = panel.centerOnBar ? card.x + card.width / 2 : panel.anchorScreenPos.x + panel.anchorW / 2
    return Math.max(card.x + dropW / 2, Math.min(card.x + card.width - dropW / 2, cx))
  }

  // The card's fill and frame give way to the fog; its opacity carries
  // the content (kept just above 0 while the blob shrinks, so the panel,
  // which unmaps at opacity 0, stays up until the fog is back in the bar).
  Binding { target: fp.card; property: "color"; value: "transparent"; when: fp.active }
  Binding { target: fp.card; property: "borderSpec"; value: Border.flat("transparent", Math.max(1, Style.space(2))); when: fp.active }
  Binding { target: fp.card; property: "opacity"; value: Math.max(fp.ink, fp.grow > 0.001 ? 0.004 : 0); when: fp.active }
  // Rolling (material): the card stays up while it rolls back into the bar;
  // a mask on the card's layer shows only the rolled-out part.
  Binding { target: fp.card; property: "opacity"; value: fp.panel && (fp.panel.open || fp.roll > 0.001) ? 1 : 0; when: fp.rolls }
  // the card hangs flush from the bar: the inverted source tab runs into it
  Binding { target: fp.panel; property: "gap"; value: 0; when: fp.rolls }
  Binding { target: fp.card ? fp.card.layer : null; property: "enabled"; value: true; when: fp.rolling && !!fp.rollMask }
  Binding { target: fp.card ? fp.card.layer : null; property: "effect"; value: rollEffect; when: fp.rolling && !!fp.rollMask }
  Component {
    id: rollEffect
    MultiEffect { maskEnabled: true; maskSource: fp.rollMask; maskThresholdMin: 0.5; maskSpreadAtMin: 0; autoPaddingEnabled: false }
  }
  NumberAnimation { id: rollOut; target: fp; property: "roll"; to: 1; duration: 260; easing.type: Easing.OutCubic }
  NumberAnimation { id: rollIn; target: fp; property: "roll"; to: 0; duration: 200; easing.type: Easing.InCubic }

  function blobRect() {
    if (!card) return { x: 0, y: 0, w: 0, h: 0 }
    var d = Math.min(1, grow / 0.3)
    var e = Math.max(0, Math.min(1, (grow - 0.3) / 0.7))
    e = 1 - Math.pow(1 - e, 3)
    var fullH = card.y + card.height - barBottom
    var dx = dropCx - dropW / 2
    return {
      x: dx + (card.x - dx) * e,
      y: barBottom,
      w: dropW + (card.width - dropW) * e,
      h: d * dropH + (fullH - dropH) * e
    }
  }
  readonly property var blob: { grow; card ? card.x + card.y + card.width + card.height : 0; return blobRect() }

  SequentialAnimation {
    id: opening
    NumberAnimation { target: fp; property: "grow"; to: 1; duration: 480; easing.type: Easing.Linear }
    NumberAnimation { target: fp; property: "ink"; to: 1; duration: 140; easing.type: Easing.Linear }
  }
  SequentialAnimation {
    id: closing
    NumberAnimation { target: fp; property: "ink"; to: 0; duration: 110; easing.type: Easing.Linear }
    ScriptAction {
      script: {
        if (!fp.stage) return
        var g = fp.stage.ghost
        g.x = fp.blob.x - fp.stage.x; g.y = fp.blob.y - fp.stage.y
        g.width = fp.blob.w; g.height = fp.blob.h
        g.opacity = 0.16
        ghostFade.target = g
        ghostFade.restart()
      }
    }
    NumberAnimation { target: fp; property: "grow"; to: 0; duration: 380; easing.type: Easing.Linear }
  }
  NumberAnimation { id: ghostFade; property: "opacity"; to: 0; duration: 760; easing.type: Easing.InQuad }

  function followRoll() {
    // Same rule as the fog below: when rolling stops applying, only stop –
    // never write roll through a Binding that is about to be released.
    if (!rolls) { rollOut.stop(); rollIn.stop(); return }
    if (panel.open) {
      rollIn.stop()
      if (reduced) { rollOut.stop(); roll = 1; return }
      rollOut.start()            // from where it is: 0 when fresh, partway when reopened
    } else {
      rollOut.stop()
      if (reduced || roll <= 0 || panel.popoutSwitchClosing) { rollIn.stop(); roll = 0; return }
      rollIn.start()
    }
  }
  // becoming a rolling card: take the state without animating (open = out, closed = in)
  onRollsChanged: { rollOut.stop(); rollIn.stop(); if (rolls) roll = panel && panel.open ? 1 : 0 }
  // Reduced Motion switched on mid-roll, mid-fog or mid-bloom: jump to where it is going
  onReducedChanged: {
    if (!reduced) return
    if (rolls && (rollOut.running || rollIn.running)) followRoll()
    if (active && (opening.running || closing.running)) { opening.stop(); closing.stop(); follow() }
    if (wetting.running) settle()
  }

  function follow() {
    followRoll()
    // Fog off: only stop. Writing grow/ink here would still go through the
    // card's opacity Binding (not yet released) and start the panel's
    // opacity Behavior, which then outlives the restored binding — closed
    // popups came back fully opaque and never unmapped. Turning the fog on
    // again resets both below.
    if (!active) { opening.stop(); closing.stop(); settle(); return }
    if (panel.open) {
      closing.stop()
      if (reduced) { grow = 1; ink = 1; settle(); return }
      if (grow >= 1) ink = 1          // reopened while still up
      else {
        ink = 0; opening.start()
        // all ink from the first frame (the pause in `wetting` holds it)
        if (bloom) { wetting.stop(); clearing = 0; wet = 1; phase = 0; wetting.start() } else settle()
      }
    } else {
      opening.stop()
      // Switching to another bar popup closes this one at once (as
      // KeyboardPanel does): no shrinking fog next to the new one.
      if (reduced || grow <= 0 || panel.popoutSwitchClosing) {
        closing.stop(); grow = 0; ink = 0
        if (stage) stage.ghost.opacity = 0
        return
      }
      closing.start()
    }
  }
  Connections {
    target: fp.panel
    function onOpenChanged() { fp.follow() }
  }
  onActiveChanged: follow()

  // The fog, under the card in the panel window. Clipped at the bar's
  // lower edge: the shapes reach up into the bar for the blur, but nothing
  // may be painted over the bar's widgets.
  // Created straight into the panel window, under the card.
  property Item stage: null
  readonly property real ghostOpacity: stage ? stage.ghost.opacity : 0
  Component {
    id: stageComponent
    Item {
      id: stageItem
      readonly property alias ghost: ghost
      visible: fp.active && (fp.grow > 0 || ghost.opacity > 0)
      x: fp.card ? fp.card.x - fp.margin : 0
      y: fp.barBottom
      width: fp.card ? fp.card.width + fp.margin * 2 : 0
      height: fp.card ? fp.card.y + fp.card.height + fp.margin - fp.barBottom : 0
      clip: true

      Item {
        anchors.fill: parent
        layer.enabled: stageItem.visible
        layer.effect: MultiEffect { blurEnabled: true; blur: 1; blurMax: 48; autoPaddingEnabled: false }
        Rectangle { id: ghost; opacity: 0; radius: 12; color: fp.color }
        // soft shadow (bloom: the halo) under the blob, kept off the bar's edge
        Rectangle {
          visible: fp.edge || fp.bloom
          x: fp.blob.x - stageItem.x + 4
          y: 18
          width: fp.grow > 0 ? Math.max(0, fp.blob.w - 8) : 0
          height: Math.max(0, fp.blob.h - 12)
          radius: 12
          color: fp.shadeColor
        }
      }

      // the edge line: the same shapes a little larger, in the rim colour,
      // under the fog itself
      FogLayer {
        visible: fp.edge || fp.bloom
        y: -fp.margin
        width: stageItem.width
        height: stageItem.height + fp.margin
        color: fp.edgeColor
        blurMax: 24
        threshold: 0.4
        softness: fp.edgeSoftness
        Rectangle {
          x: fp.blob.x - stageItem.x - 14 - fp.edgeW
          width: fp.grow > 0 ? fp.blob.w + 28 + 2 * fp.edgeW : 0
          height: fp.margin + 1
          color: "white"
        }
        Rectangle {
          x: fp.blob.x - stageItem.x - fp.edgeW
          y: fp.margin
          width: fp.grow > 0 ? fp.blob.w + 2 * fp.edgeW : 0
          height: fp.blob.h + fp.edgeW
          radius: 10 + fp.edgeW
          color: "white"
        }
        Repeater {
          model: fp.bloom ? fp.scallopCount : 0
          Rectangle {
            required property int index
            readonly property var p: fp.scallopAt(index)
            readonly property real r: p.r > 0 ? p.r + fp.edgeW : 0
            x: p.x - stageItem.x - r
            y: fp.margin + p.y - r
            width: 2 * r; height: 2 * r; radius: r
            color: "white"
          }
        }
      }

      FogLayer {
        id: fillFog
        y: -fp.margin
        width: stageItem.width
        height: stageItem.height + fp.margin
        color: fp.color
        blurMax: 24
        threshold: 0.4
        softness: fp.edgeSoftness

        // up into the bar: the flare where the blob leaves it (shapes only
        // change size: the fog layer does not repaint a merely hidden one)
        Rectangle {
          x: fp.blob.x - stageItem.x - 14
          width: fp.grow > 0 ? fp.blob.w + 28 : 0
          height: fp.margin + 1
          color: "white"
        }
        Rectangle {
          x: fp.blob.x - stageItem.x
          y: fp.margin
          width: fp.blob.w
          height: fp.blob.h
          radius: 10
          color: "white"
        }
        Repeater {
          model: fp.bloom ? fp.scallopCount : 0
          Rectangle {
            required property int index
            readonly property var p: fp.scallopAt(index)
            x: p.x - stageItem.x - p.r
            y: fp.margin + p.y - p.r
            width: 2 * p.r; height: 2 * p.r; radius: p.r
            color: "white"
          }
        }
      }

      // the wet ink over the bloom's body (only while the water clears it);
      // the bloom's own fog layer is its mask, through an explicit source
      ShaderEffectSource {
        id: fillMask
        sourceItem: wetInk.visible ? fillFog : null
        hideSource: false
        live: true
        visible: false
      }
      ShaderEffect {
        id: wetInk
        visible: fp.bloom && fp.clearing < 0.999 && fp.grow > 0
        // below the bar's edge only (the flare reaching up into the bar stays paper)
        x: fillFog.x; y: fillFog.y + fp.margin - 4
        width: fillFog.width; height: Math.max(1, fillFog.height - fp.margin + 4)
        property var mask: fillMask
        property size size: Qt.size(fillFog.width, fillFog.height)
        // the source: where the blob leaves the bar (fill-layer coordinates)
        property point center: Qt.point(fp.dropCx - stageItem.x, fp.margin - 2)
        property rect region: Qt.rect(0, fp.margin - 4, width, height)
        property color ink: fp.inkColor
        property real front: fp.clearFar * 1.15 * fp.clearing
        property real band: 58
        property real body: fp.lightTheme ? 0.44 : 0.34
        property real ridge: fp.lightTheme ? 0.38 : 0.3
        property real resid: fp.lightTheme ? 0.08 : 0.07
        property real jitter: 26
        property real seed: 5.0
        fragmentShader: Qt.resolvedUrl("shaders/wetink.frag.qsb")
      }
    }
  }

  // Without fog (or where the fog does not apply): line on the card and a
  // shadow under it, fading with the card.
  property Item cardShadow: null
  property Item cardLine: null
  Component {
    id: cardShadowComponent
    Item {
      id: shade
      readonly property real spread: 40
      // material: the theme's hard shadow (no blur) or halo; else the soft default
      readonly property var spec: fp.matOn ? fp.matShadow : null
      readonly property bool soft: !spec || spec.blur > 0
      visible: (fp.edge || !!spec) && !fp.active && !!fp.card && fp.card.opacity > 0 && (!fp.matOn || !!spec)
      opacity: fp.card ? fp.card.opacity : 0
      x: fp.card ? fp.card.x - spread : 0
      y: fp.card ? fp.card.y - spread : 0
      width: fp.card ? fp.card.width + 2 * spread : 0
      height: fp.card ? fp.card.height + 2 * spread : 0
      layer.enabled: visible && soft
      layer.effect: MultiEffect { blurEnabled: true; blur: 1; blurMax: shade.spec ? Math.min(64, shade.spec.blur) : 32; autoPaddingEnabled: false }
      Rectangle {
        x: parent.spread + (shade.spec ? shade.spec.dx : 2)
        y: parent.spread + (shade.spec ? shade.spec.dy : 8)
        width: parent.width - 2 * parent.spread - (shade.spec ? 0 : 4)
        // rolls with the card
        height: (parent.height - 2 * parent.spread - (shade.spec ? 0 : 6)) * (fp.rolls ? fp.roll : 1)
        radius: fp.card ? fp.card.radius : 0
        color: shade.spec ? shade.spec.color : Qt.rgba(0, 0, 0, fp.shadowOpacity)
      }
    }
  }
  // the roll mask: the card's top part, as far as it has rolled out
  property Item rollMask: null
  Component {
    id: rollMaskComponent
    Item {
      visible: false
      layer.enabled: fp.rolling
      x: fp.card ? fp.card.x : 0
      y: fp.card ? fp.card.y : 0
      width: fp.card ? fp.card.width : 1
      height: fp.card ? fp.card.height : 1
      Rectangle { width: parent.width; height: Math.max(1, parent.height * fp.roll); color: "white" }
    }
  }
  Component {
    id: cardLineComponent
    Rectangle {
      anchors.fill: parent
      z: 1000
      visible: fp.edge && !fp.active && !fp.matOn
      color: "transparent"
      radius: fp.card ? fp.card.radius : 0
      border.width: 1
      border.color: fp.rimColor
    }
  }

  Component.onCompleted: {
    if (surface) {
      cardShadow = cardShadowComponent.createObject(surface, { z: card.z - 2 })
      stage = stageComponent.createObject(surface, { z: card.z - 1 })
      rollMask = rollMaskComponent.createObject(surface, { z: card.z - 3 })
    }
    if (card) cardLine = cardLineComponent.createObject(card)
    follow()
  }
  Component.onDestruction: {
    if (stage) stage.destroy()
    if (cardShadow) cardShadow.destroy()
    if (cardLine) cardLine.destroy()
    if (rollMask) rollMask.destroy()
  }
}
