-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- Clipboard: pin the provider instead of letting Neovim autodetect one.
--
-- LazyVim sets clipboard = "unnamedplus", so `y` writes the "+" register and
-- Neovim hands that write to whatever clipboard tool it detected at startup.
-- Detection resolves `wl-copy` through $PATH, and this editor gets launched
-- from places where $PATH is the bare system one -- zellij's EditScrollback is
-- the routine case -- with no linuxbrew on it, which is where wl-clipboard
-- actually lives here.
--
-- Pinning takes $PATH and startup-time detection out of the question, and
-- points the editor at the same dispatcher zellij's copy_command uses, so the
-- editor, the multiplexer, and the shell all agree on what "the clipboard"
-- means. Under WSLg that reaches the Windows clipboard via the Wayland bridge;
-- on a native box the script picks wl-copy or xclip the same way.
--
-- Guarded on the script being present, so a machine without the `bin` stow
-- package falls back to Neovim's own detection rather than to nothing.
local copy = vim.fn.expand("~/.local/bin/clipboard-copy")
local paste = vim.fn.expand("~/.local/bin/clipboard-paste")

if vim.fn.executable(copy) == 1 and vim.fn.executable(paste) == 1 then
  vim.g.clipboard = {
    name = "clipboard-dispatcher",
    copy = { ["+"] = copy, ["*"] = copy },
    paste = { ["+"] = paste, ["*"] = paste },
    -- Read through every time: another window (or Windows itself) may have
    -- taken the clipboard since the last yank, and a cache would hide that.
    cache_enabled = 0,
  }
end
