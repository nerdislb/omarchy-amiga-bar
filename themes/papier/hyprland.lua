-- papier: borders and window shadow carry the light/shadow rule of the theme.
local active_border_color = "rgba(111111ff)"
local inactive_border_color = "rgba(aaa38fff)"

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
    shadow = { enabled = true, sharp = true, range = 1, offset = { 6, 6 }, color = "rgba(111111ff)", color_inactive = "rgba(1111114d)" },
  },
})
