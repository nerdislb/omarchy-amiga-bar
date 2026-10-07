-- chrom: a resting chrome gradient on the active border that turns once when a window takes
-- focus (borderangle, no loop: a loop would redraw all the time); the window shadow a faint light.
local active_border_color = { colors = { "rgba(f2f3f7ff)", "rgba(8a8c92ff)", "rgba(3b3c41ff)", "rgba(8a8c92ff)", "rgba(f2f3f7ff)" }, angle = 90 }
local inactive_border_color = "rgba(26272aff)"

hl.config({
  general = {
    col = {
      active_border = active_border_color,
      inactive_border = inactive_border_color,
    },
  },

  group = {
    col = {
      border_active = active_border_color,
      border_inactive = inactive_border_color,
    },
  },

  decoration = {
    shadow = { enabled = true, range = 22, render_power = 3, offset = { 0, 4 }, color = "rgba(ffffff1c)", color_inactive = "rgba(00000000)" },
  },
})

hl.animation({ leaf = "borderangle", enabled = true, speed = 9, bezier = "easeOutQuint" })
