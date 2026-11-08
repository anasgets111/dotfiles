-- Developer tooling that `lib/updates.lua` updates after the package manager.
-- Each entry has a name, the binary that must exist, and argv commands run in order until the first
-- non-zero exit. Commands resolve against the `PATH` the shell started with, and a tool the session
-- cannot see hides its row. Everything runs as the user, because `composer global update` under
-- `pkexec` would leave `~/.config/composer` owned by root.
return {
    { name = "composer",     requires = "composer", run = { { "composer", "global", "update" } } },
    {
        name = "node",
        requires = "fnm",
        -- Install the LTS and default to it, bring every installed major to its latest release for the
        -- projects pinned to it, then prune the older releases within each major.
        -- ponytail: a major stays until `fnm uninstall`, so a past LTS lingers once nothing pins it.
        run = {
            { "fnm", "install", "--use",     "lts-latest" },
            { "fnm", "default", "lts-latest" },
            {
                "bash",
                "-c",
                "fnm ls | awk '$2 ~ /^v/ { sub(/\\..*/, \"\", $2); print $2 }' | sort -u | xargs -r -n1 fnm install",
            },
            {
                "bash",
                "-c",
                "fnm ls | awk '$2 ~ /^v/ { print $2 }' | sort -Vr | awk -F. 'seen[$1]++' | xargs -r -n1 fnm uninstall",
            },
        },
    },
    { name = "pnpm globals", requires = "pnpm",     run = { { "pnpm", "update", "-g" } } },
    {
        name = "playwright",
        requires = "playwright-cli",
        run = { { "playwright-cli", "install-browser", "chromium" } },
    },
    { name = "bun globals",    requires = "bun",                  run = { { "bun", "update", "-g" } } },
    { name = "uv tools",       requires = "uv",                   run = { { "uv", "tool", "upgrade", "--all" } } },
    { name = "tldr pages",     requires = "tldr",                 run = { { "tldr", "--update" } } },
    { name = "rust binaries",  requires = "cargo-install-update", run = { { "cargo", "install-update", "-a" } } },
    { name = "rust toolchain", requires = "rustup",               run = { { "rustup", "update" } } },
}
