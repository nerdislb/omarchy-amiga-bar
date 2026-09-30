import QtQuick

// The Boing ball (red/white checkered sphere), drawn on a Canvas.
// `spin` turns the checker pattern; the fixed Amiga colours are intended.
Canvas {
  id: ball
  property real size: 12
  property real spin: 0
  width: size
  height: size
  onSpinChanged: requestPaint()
  onSizeChanged: requestPaint()
  onPaint: {
    var ctx = getContext("2d")
    var r = size / 2
    ctx.reset()
    ctx.save()
    ctx.beginPath(); ctx.arc(r, r, r, 0, Math.PI * 2); ctx.clip()
    var n = 8, m = 4
    for (var i = -1; i < n + 1; i++) {
      for (var j = 0; j < m; j++) {
        var lat0 = -Math.PI / 2 + j * Math.PI / m, lat1 = lat0 + Math.PI / m
        var lon0 = (i + spin) * Math.PI / n - Math.PI / 2, lon1 = lon0 + Math.PI / n
        var c0 = Math.max(-Math.PI / 2, Math.min(Math.PI / 2, lon0)), c1 = Math.max(-Math.PI / 2, Math.min(Math.PI / 2, lon1))
        var x0 = Math.sin(c0), x1 = Math.sin(c1)
        if (x1 <= x0) continue
        var w0 = Math.cos((lat0 + lat1) / 2)
        ctx.fillStyle = ((i + j) % 2 + 2) % 2 ? "#ffffff" : "#e02020"
        ctx.fillRect(r + x0 * r * w0 - 0.5, r + Math.sin(lat0) * r, (x1 - x0) * r * w0 + 1, (Math.sin(lat1) - Math.sin(lat0)) * r + 0.5)
      }
    }
    ctx.restore()
    var g = ctx.createRadialGradient(r * 0.6, r * 0.6, r * 0.1, r, r, r)
    g.addColorStop(0, "rgba(255,255,255,0.35)")
    g.addColorStop(1, "rgba(0,0,0,0.25)")
    ctx.fillStyle = g
    ctx.beginPath(); ctx.arc(r, r, r, 0, Math.PI * 2); ctx.fill()
  }
}
