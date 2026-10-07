-- platin: a resting polished-steel gradient on the active border that turns once when a window
-- takes focus (borderangle, no loop); the window shadow a soft dark.
local active_border_color = { colors = { "rgba(1a1b1dff)", "rgba(7a7d82ff)", "rgba(c9ccd0ff)", "rgba(7a7d82ff)", "rgba(1a1b1dff)" }, angle = 90 }
local inactive_border_color = "rgba(b0b3b8ff)"

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
    shadow = { enabled = true, range = 24, render_power = 3, offset = { 0, 4 }, color = "rgba(1112142a)", color_inactive = "rgba(00000000)" },
  },
})

hl.animation({ leaf = "borderangle", enabled = true, speed = 9, bezier = "easeOutQuint" })
