-- aether with the theme palette; red is the signal colour only.
return {
  {
    "omacom/aether.nvim",
    branch = "v3",
    name = "aether",
    priority = 1000,
    opts = {
      styles = { comments = { italic = true }, keywords = { bold = true }, functions = { bold = true } },
      colors = {
        bg = "#000000",
        dark_bg = "#090a0b",
        darker_bg = "#050505",
        lighter_bg = "#111214",
        fg = "#e0e0e1",
        dark_fg = "#a5a6a8",
        light_fg = "#ececec",
        bright_fg = "#ffffff",
        muted = "#747679",
        red = "#ff4a2b",
        yellow = "#ffffff",
        orange = "#bcbdbf",
        green = "#ffffff",
        cyan = "#929497",
        blue = "#afb0b2",
        magenta = "#c3c4c5",
        brown = "#5a5c60",
        bright_red = "#ffffff",
        bright_yellow = "#ffffff",
        bright_green = "#ffffff",
        bright_cyan = "#abacae",
        bright_blue = "#c7c8c9",
        bright_magenta = "#d7d8d9",
        accent = "#ffffff",
        cursor = "#ffffff",
        foreground = "#e0e0e1",
        background = "#000000",
        selection = "#2c2e32",
        selection_foreground = "#ffffff",
        selection_background = "#2c2e32",
      },
      on_highlights = function(hl, c)
        local sig, strong = "#ff4a2b", "#ffffff"
        for _, g in ipairs({ "Error", "ErrorMsg", "DiagnosticError", "DiagnosticSignError", "DiagnosticVirtualTextError",
          "DiagnosticFloatingError", "diffRemoved", "Removed", "GitSignsDelete", "DiffviewFilePanelDeletions", "SpellBad" }) do
          hl[g] = { fg = sig, bold = g == "Error" or g == "ErrorMsg" }
        end
        hl.DiagnosticUnderlineError = { undercurl = true, sp = sig }
        for _, g in ipairs({ "diffAdded", "Added", "GitSignsAdd" }) do hl[g] = { fg = strong, bold = true } end
        hl.String = { fg = c.green, italic = true }
        hl.Comment = { fg = c.muted, italic = true }
        hl.CursorLineNr = { fg = strong, bold = true }
        hl.Todo = { fg = c.bg, bg = strong, bold = true }
      end,
    },
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "aether",
    },
  },
}
