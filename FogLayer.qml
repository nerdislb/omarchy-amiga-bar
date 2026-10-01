import QtQuick
import QtQuick.Effects

// Gooey fog: white shapes placed in this layer are blurred and then cut
// with a soft alpha threshold, so neighbouring shapes melt into one blob
// with a feathered edge (the metaball trick), filled with `color`.
// Shapes must keep `blurMax` px away from the layer's edges, or the blur
// fades them out there; extend the layer past a window edge instead.
// (Same component in the Amiga Island: keep both copies alike.)
Item {
  id: fog

  property color color: "black"
  property int blurMax: 24
  // Where the blurred alpha is cut, and how soft the cut is.
  property real threshold: 0.5
  property real softness: 0.12
  default property alias shapes: shapeSource.data

  Item {
    id: shapeSource
    anchors.fill: parent
    visible: false
    layer.enabled: fog.visible
  }

  // Built only while the layer is visible, so a fog switched on later
  // starts like one that was on from the start. The hidden shape layer
  // repaints on geometry changes, not when a shape is merely shown or
  // hidden: change a shape's size instead of its visibility.
  Loader {
    anchors.fill: parent
    active: fog.visible
    sourceComponent: Item {
      MultiEffect {
        id: blurred
        anchors.fill: parent
        source: shapeSource
        visible: false
        layer.enabled: true
        autoPaddingEnabled: false
        blurEnabled: true
        blur: 1
        blurMax: fog.blurMax
      }

      Rectangle {
        id: fill
        anchors.fill: parent
        visible: false
        layer.enabled: true
        color: fog.color
      }

      MultiEffect {
        anchors.fill: parent
        source: fill
        autoPaddingEnabled: false
        maskEnabled: true
        maskSource: blurred
        maskThresholdMin: fog.threshold
        maskSpreadAtMin: fog.softness
      }
    }
  }
}
