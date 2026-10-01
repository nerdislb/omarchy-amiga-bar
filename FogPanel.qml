import QtQuick
import QtQuick.Effects
import qs.Commons

// Fog look (Amiga Bar option `fog`, a test) for an Omarchy KeyboardPanel.
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

  // Inside the panel we sit in its content holder; its parent is the card,
  // and the card's parent the panel window's root item.
  readonly property Item card: parent && parent.parent && parent.parent.borderSpec !== undefined ? parent.parent : null
  readonly property Item surface: card ? card.parent : null
  readonly property bool active: fog && !!card && !!surface && !!panel && panel.barPos === "top"
  readonly property bool reduced: Style.reduceMotion

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

  function follow() {
    if (!active) { opening.stop(); closing.stop(); grow = 0; ink = 1; return }
    if (panel.open) {
      closing.stop()
      if (reduced) { grow = 1; ink = 1; return }
      if (grow >= 1) ink = 1          // reopened while still up
      else { ink = 0; opening.start() }
    } else {
      opening.stop()
      if (reduced || grow <= 0) { grow = 0; ink = 0; return }
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

  Component.onCompleted: {
    if (surface) stage = stageComponent.createObject(surface, { z: card.z - 1 })
    follow()
  }
  Component.onDestruction: if (stage) stage.destroy()
}
