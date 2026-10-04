import QtQuick
import QtQuick.Shapes
import qs.Commons

// The official Arch Linux mark, unaltered: the first path of
// /usr/share/pixmaps/archlinux-logo.svg (package filesystem) without the ™,
// filled in one colour (the bar's strong ink, the tab's text when inverted).
// One closed contour without holes, so the winding fill draws exactly what
// the SVG's even-odd fill does (and the curve renderer takes it as it is).
// Arch's trademark policy allows unaltered, non-commercial use that implies
// no endorsement – so no change of its shape, and motion only as a whole:
// it arrives with one calm fade (0.22 s; reduced motion 0.12 s), then stands
// still (logo design round 04.10., the reviewed version).
// Size: `size` is the height of the path's box in px; the triangle reads
// lighter than a square glyph, so the bar gives it 1.18 × its 18 px field.
// The item is the path's box (232.6 × 232.4 units), so it centres on it.
Item {
  id: arch

  property color color: "white"
  property real size: 18 * 1.18

  readonly property real k: size / 232.4
  width: 232.6 * k
  height: size

  opacity: 0
  NumberAnimation on opacity {
    from: 0; to: 1
    duration: Style.reduceMotion ? 120 : 220
    easing.type: Style.reduceMotion ? Easing.Linear : Easing.OutCubic
  }

  Shape {
    x: -11.9 * arch.k
    y: -12.07 * arch.k
    width: 256; height: 256
    scale: arch.k
    transformOrigin: Item.TopLeft
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
      fillColor: arch.color
      strokeWidth: -1
      strokeColor: "transparent"
      fillRule: ShapePath.WindingFill
      PathSvg { path: "m127.98 12.07c-10.316 25.309-16.543 41.855-28.031 66.41 7.043 7.4609 15.691 16.156 29.734 25.977-15.098-6.207-25.395-12.445-33.094-18.918-14.703 30.68-37.742 74.391-84.492 158.39 36.746-21.219 65.23-34.293 91.773-39.289-1.1406-4.8945-1.7852-10.195-1.7422-15.734l0.042969-1.1719c0.58203-23.551 12.828-41.645 27.336-40.418 14.508 1.2266 25.781 21.316 25.199 44.867-0.10938 4.4219-0.60938 8.6914-1.4805 12.641 26.258 5.1328 54.438 18.18 90.684 39.105-7.1484-13.156-13.527-25.016-19.621-36.316-9.5938-7.4336-19.605-17.117-40.023-27.594 14.035 3.6406 24.082 7.8516 31.914 12.555-61.941-115.32-66.957-130.66-88.199-180.5z" }
    }
  }
}
