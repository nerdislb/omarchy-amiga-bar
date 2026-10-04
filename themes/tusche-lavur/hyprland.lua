-- tusche-lavur: borders and window shadow carry the light/shadow rule of the theme.
local active_border_color = { colors = { "rgba(ffffffff)", "rgba(2e2e2eff)" }, angle = 90 }
local inactive_border_color = "rgba(1a1a1aff)"

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
    shadow = { enabled = true, range = 50, render_power = 2, offset = { 0, 6 }, color = "rgba(ffffff24)", color_inactive = "rgba(00000000)" },
  },
})
