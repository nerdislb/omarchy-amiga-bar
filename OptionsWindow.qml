import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Commons
import qs.Ui as Ui
import "Presets.js" as Presets

// Options window: presets on top, then one row of variants per element.
// Looks like Omarchy's own bar popups (popup card, theme frame, gap under
// the bar); click outside or Esc closes it.
PanelWindow {
  id: win

  property var host: null
  property bool open: false
  signal closeRequested()

  readonly property var elements: {
    var out = []
    for (var key in Presets.ELEMENTS) out.push({ key: key, label: Presets.ELEMENTS[key].label, variants: Presets.ELEMENTS[key].variants })
    return out
  }

  screen: {
    var s = Quickshell.screens
    var f = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
    for (var i = 0; i < s.length; i++) if (s[i].name === f) return s[i]
    return s.length ? s[0] : null
  }
  visible: open || card.opacity > 0
  color: "transparent"
  anchors { top: true; bottom: true; left: true; right: true }
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.namespace: "amiga-bar-options"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

  MouseArea {
    anchors.fill: parent
    enabled: win.open
    onClicked: win.closeRequested()
  }

  Ui.BorderSurface {
    id: card
    readonly property int pad: Style.spacing.popupPadding
    width: Style.space(580)
    height: column.childrenRect.height + pad * 2 + Border.top(borderSpec) + Border.bottom(borderSpec)
    x: Math.round((win.width - width) / 2)
    y: Style.bar.sizeHorizontal + Style.gapsOut
    color: Color.popups.background
    borderSpec: Border.surfaceSpec("popups", "border", Color.popups.border, Math.max(1, Style.space(2)))
    padding: pad
    radius: Style.cornerRadius
    opacity: win.open ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: Style.duration(140); easing.type: Easing.OutCubic } }

    MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }

    Item {
      id: keys
      x: card.contentLeftInset; y: card.contentTopInset
      width: card.width - card.contentLeftInset - card.contentRightInset
      height: column.childrenRect.height
      focus: win.open
      Keys.onEscapePressed: function(e) { win.closeRequested(); e.accepted = true }

      Column {
        id: column
        width: parent.width
        spacing: Style.spacing.rowGap

        Row {
          width: parent.width
          Text {
            text: "Amiga Bar"
            font.family: Style.font.family; font.bold: true; font.pixelSize: Style.font.title
            color: Color.popups.text
          }
          Text {
            anchors.baseline: parent.children[0].baseline
            leftPadding: Style.space(10)
            text: "private build"
            font.family: Style.font.family; font.pixelSize: Style.font.caption
            color: Util.alpha(Color.popups.text, 0.55)
          }
        }

        SectionLabel { text: "PRESETS" }
        Flow {
          width: parent.width
          height: childrenRect.height
          spacing: Style.space(6)
          Repeater {
            model: Presets.PRESETS
            Choice {
              required property var modelData
              label: modelData.label
              note: modelData.note
              selected: win.host && win.host.presetId === modelData.id
              onPicked: win.host.applyPreset(modelData.id)
            }
          }
        }

        Repeater {
          model: win.elements
          Column {
            required property var modelData
            width: column.width
            spacing: Style.space(4)
            SectionLabel { text: modelData.label.toUpperCase() }
            Flow {
              width: parent.width
              height: childrenRect.height
              spacing: Style.space(6)
              Repeater {
                model: modelData.variants
                Choice {
                  required property var modelData
                  readonly property string element: parent.parent.modelData.key
                  label: modelData.label
                  selected: win.host && win.host.options[element] === modelData.id
                  onPicked: win.host.setVariant(element, modelData.id)
                }
              }
            }
          }
        }

        Text {
          width: parent.width
          wrapMode: Text.WordWrap
          text: "Applies at once (the bar rebuilds briefly). \"Today\" restores your previous layout. Esc or a click outside closes."
          font.family: Style.font.family; font.pixelSize: Style.font.caption
          color: Util.alpha(Color.popups.text, 0.55)
        }
      }
    }
  }

  component SectionLabel: Text {
    font.family: Style.font.family; font.bold: true; font.pixelSize: Style.font.caption
    color: Qt.darker(Color.popups.text, 1.4)
    topPadding: Style.space(4)
  }

  component Choice: Rectangle {
    id: choice
    property string label: ""
    property string note: ""
    property bool selected: false
    signal picked()
    width: inner.implicitWidth + Style.space(20)
    height: inner.implicitHeight + Style.space(10)
    radius: Style.cornerRadius
    color: selected ? Color.accent
      : mouse.pressed ? Style.pressedFillFor(Color.popups.text, Color.accent, Color.urgent)
      : mouse.containsMouse ? Style.hoverFillFor(Color.popups.text, Color.accent, Color.urgent)
      : Util.alpha(Color.popups.text, 0.06)
    border.width: selected ? 0 : 1
    border.color: Util.alpha(Color.popups.text, 0.15)
    Behavior on color { ColorAnimation { duration: Style.duration(120) } }
    Column {
      id: inner
      anchors.centerIn: parent
      Text {
        text: choice.label
        font.family: Style.font.family; font.pixelSize: Style.font.body; font.bold: choice.selected
        color: choice.selected ? Color.popups.background : Color.popups.text
      }
      Text {
        visible: choice.note !== ""
        text: choice.note
        font.family: Style.font.family; font.pixelSize: Style.font.caption
        color: choice.selected ? Util.alpha(Color.popups.background, 0.8) : Util.alpha(Color.popups.text, 0.55)
      }
    }
    MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: choice.picked() }
  }
}
