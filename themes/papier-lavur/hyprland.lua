-- papier-lavur: borders and window shadow carry the light/shadow rule of the theme.
local active_border_color = { colors = { "rgba(111111ff)", "rgba(aaa38fff)" }, angle = 90 }
local inactive_border_color = "rgba(aaa38f80)"

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
    shadow = { enabled = true, range = 24, render_power = 3, offset = { 0, 4 }, color = "rgba(11111128)", color_inactive = "rgba(00000000)" },
  },
})
