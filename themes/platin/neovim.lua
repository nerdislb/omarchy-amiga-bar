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
        bg = "#dde0e4",
        dark_bg = "#cdd0d4",
        darker_bg = "#c0c3c7",
        lighter_bg = "#eaedf1",
        fg = "#27292b",
        dark_fg = "#414346",
        light_fg = "#17191b",
        bright_fg = "#000000",
        muted = "#646568",
        red = "#b02614",
        yellow = "#000000",
        orange = "#353739",
        green = "#000000",
        cyan = "#535457",
        blue = "#353739",
        magenta = "#414346",
        brown = "#818488",
        bright_red = "#000000",
        bright_yellow = "#000000",
        bright_green = "#000000",
        bright_cyan = "#494a4d",
        bright_blue = "#2e2f32",
        bright_magenta = "#383a3d",
        accent = "#0f1113",
        cursor = "#000000",
        foreground = "#27292b",
        background = "#dde0e4",
        selection = "#c0c3c7",
        selection_foreground = "#000000",
        selection_background = "#c0c3c7",
      },
      on_highlights = function(hl, c)
        local sig, strong = "#b02614", "#000000"
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
