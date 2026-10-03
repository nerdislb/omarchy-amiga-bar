import QtQuick
import QtQuick.Effects
import qs.Commons

// Fog look (Amiga Bar option `fog`, a test) for an Omarchy KeyboardPanel.
// Without fog but with a theme material (edge option "theme": the theme's
// bar-material.json, Tusche & Papier) the card takes the theme's light and
// shadow instead – a hard ink shadow (Papier), a light halo (Tusche, Lavur)
// – and rolls out of the bar from the top, and back up when it closes.
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
  readonly property real shadowOpacity: lightTheme ? 0.22 : 0.55

  // Inside the panel we sit in its content holder; its parent is the card,
  // and the card's parent the panel window's root item.
  readonly property Item card: parent && parent.parent && parent.parent.borderSpec !== undefined ? parent.parent : null
  readonly property Item surface: card ? card.parent : null
  readonly property bool active: fog && !!card && !!surface && !!panel && panel.barPos === "top"
  readonly property bool reduced: Style.reduceMotion

  // Theme material (bar-material.json; set while the edge option is "theme").
  property var material: null
  readonly property var mat: material && material.card ? material.card : null
  readonly property bool matOn: !fog && !!mat && !!card && !!surface && !!panel
  readonly property bool rolls: matOn && mat.roll !== false && panel.barPos === "top"
  property real roll: 0      // 0 = rolled up into the bar, 1 = open
  readonly property bool rolling: rolls && roll < 0.999
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
      if (reduced) { roll = 1; return }
      rollOut.start()            // from where it is: 0 when fresh, partway when reopened
    } else {
      rollOut.stop()
      if (reduced || roll <= 0 || panel.popoutSwitchClosing) { rollIn.stop(); roll = 0; return }
      rollIn.start()
    }
  }
  // becoming a rolling card: take the state without animating (open = out, closed = in)
  onRollsChanged: { rollOut.stop(); rollIn.stop(); if (rolls) roll = panel && panel.open ? 1 : 0 }

  function follow() {
    followRoll()
    // Fog off: only stop. Writing grow/ink here would still go through the
    // card's opacity Binding (not yet released) and start the panel's
    // opacity Behavior, which then outlives the restored binding — closed
    // popups came back fully opaque and never unmapped. Turning the fog on
    // again resets both below.
    if (!active) { opening.stop(); closing.stop(); return }
    if (panel.open) {
      closing.stop()
      if (reduced) { grow = 1; ink = 1; return }
      if (grow >= 1) ink = 1          // reopened while still up
      else { ink = 0; opening.start() }
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
        // soft shadow under the blob, kept off the bar's edge
        Rectangle {
          visible: fp.edge
          x: fp.blob.x - stageItem.x + 4
          y: 18
          width: fp.grow > 0 ? Math.max(0, fp.blob.w - 8) : 0
          height: Math.max(0, fp.blob.h - 12)
          radius: 12
          color: Qt.rgba(0, 0, 0, fp.shadowOpacity)
        }
      }

      // the edge line: the same shapes a little larger, in the rim colour,
      // under the fog itself
      FogLayer {
        visible: fp.edge
        y: -fp.margin
        width: stageItem.width
        height: stageItem.height + fp.margin
        color: fp.rimColor
        blurMax: 24
        threshold: 0.4
        softness: 0.5
        Rectangle {
          x: fp.blob.x - stageItem.x - 14 - fp.rim
          width: fp.grow > 0 ? fp.blob.w + 28 + 2 * fp.rim : 0
          height: fp.margin + 1
          color: "white"
        }
        Rectangle {
          x: fp.blob.x - stageItem.x - fp.rim
          y: fp.margin
          width: fp.grow > 0 ? fp.blob.w + 2 * fp.rim : 0
          height: fp.blob.h + fp.rim
          radius: 10 + fp.rim
          color: "white"
        }
      }

      FogLayer {
        y: -fp.margin
        width: stageItem.width
        height: stageItem.height + fp.margin
        color: fp.color
        blurMax: 24
        threshold: 0.4
        softness: 0.5

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
      layer.enabled: fp.rolls
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
