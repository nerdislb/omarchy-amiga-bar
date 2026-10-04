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
        bg = "#dfdacb",
        dark_bg = "#d0cab7",
        darker_bg = "#c4bda9",
        lighter_bg = "#ebe7dc",
        fg = "#2b2924",
        dark_fg = "#47433b",
        light_fg = "#1a1916",
        bright_fg = "#000000",
        muted = "#6b6558",
        red = "#a3220f",
        yellow = "#000000",
        orange = "#3a372f",
        green = "#000000",
        cyan = "#59544a",
        blue = "#3a372f",
        magenta = "#47433a",
        brown = "#8a8476",
        bright_red = "#000000",
        bright_yellow = "#000000",
        bright_green = "#000000",
        bright_cyan = "#4f4a40",
        bright_blue = "#332f28",
        bright_magenta = "#3e3a32",
        accent = "#111111",
        cursor = "#000000",
        foreground = "#2b2924",
        background = "#dfdacb",
        selection = "#c4bda9",
        selection_foreground = "#000000",
        selection_background = "#c4bda9",
      },
      on_highlights = function(hl, c)
        local sig, strong = "#a3220f", "#000000"
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
