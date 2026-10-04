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
        dark_bg = "#0a0a0a",
        darker_bg = "#050505",
        lighter_bg = "#121212",
        fg = "#e0e0e0",
        dark_fg = "#a6a6a6",
        light_fg = "#ececec",
        bright_fg = "#ffffff",
        muted = "#767676",
        red = "#ff4a2b",
        yellow = "#ffffff",
        orange = "#bdbdbd",
        green = "#ffffff",
        cyan = "#949494",
        blue = "#b0b0b0",
        magenta = "#c4c4c4",
        brown = "#5c5c5c",
        bright_red = "#ffffff",
        bright_yellow = "#ffffff",
        bright_green = "#ffffff",
        bright_cyan = "#acacac",
        bright_blue = "#c8c8c8",
        bright_magenta = "#d8d8d8",
        accent = "#ffffff",
        cursor = "#ffffff",
        foreground = "#e0e0e0",
        background = "#000000",
        selection = "#2e2e2e",
        selection_foreground = "#ffffff",
        selection_background = "#2e2e2e",
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
