import QtQuick
import qs.Commons
import qs.Ui
import "Presets.js" as Presets

// The Amiga Bar options: presets from the concept film on top, then one row
// of variants per bar element. Choosing applies at once (bar.layout is
// rewritten); "Heute" restores the layout saved before the first preset.
Item {
  id: panel

  property var host: null          // the Amiga Bar (apply/applyPreset/setVariant, options, presetId)
  property var bar: null
  property var anchorItem: null
  property bool isOpen: false
  property bool popoutSwitchClosing: false
  signal closeRequested()

  // Popout-owner contract used by KeyboardPanel / Bar.requestPopout.
  function close() { closeRequested() }
  function closeForPopoutSwitch() {
    popoutSwitchClosing = true
    closeRequested()
    Qt.callLater(function() { panel.popoutSwitchClosing = false })
  }

  readonly property var elements: {
    var out = []
    for (var key in Presets.ELEMENTS) out.push({ key: key, label: Presets.ELEMENTS[key].label, variants: Presets.ELEMENTS[key].variants })
    return out
  }

  KeyboardPanel {
    id: card
    anchorItem: panel.anchorItem
    owner: panel
    bar: panel.bar
    open: panel.isOpen
    centerOnBar: true
    focusTarget: keys
    contentWidth: Style.space(560)
    contentHeight: card.fittedContentHeight(column.childrenRect.height)

    Item {
      id: keys
      anchors.fill: parent
      focus: true
      Keys.onEscapePressed: function(e) { panel.closeRequested(); e.accepted = true }

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
            text: "Etappe A · nur lokal"
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
              selected: panel.host && panel.host.presetId === modelData.id
              onPicked: panel.host.applyPreset(modelData.id)
            }
          }
        }

        Repeater {
          model: panel.elements
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
                  selected: panel.host && panel.host.options[element] === modelData.id
                  onPicked: panel.host.setVariant(element, modelData.id)
                }
              }
            }
          }
        }

        Text {
          width: parent.width
          wrapMode: Text.WordWrap
          text: "Wirkt sofort. „Heute“ stellt dein bisheriges Layout wieder her. Weitere Elemente (AI, rechte Seite, Mitte) folgen in Etappe B."
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
