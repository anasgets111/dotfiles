-- Developer tooling that `lib/updates.lua` updates after the package manager.
-- Each entry has a name, the binary that must exist, and argv commands run in order until the first
-- non-zero exit. Commands resolve against the `PATH` the shell started with, and a tool the session
-- cannot see hides its row. Everything runs as the user, because `composer global update` under
-- `pkexec` would leave `~/.config/composer` owned by root.
return {
    { name = "composer",       requires = "composer",             run = { { "composer", "global", "update" } } },
    {
        name = "node",
        requires = "fnm",
        -- Install the LTS, default to it, then prune every other version.
        run = {
            { "fnm", "install", "--use",     "lts-latest" },
            { "fnm", "default", "lts-latest" },
            {
                "bash",
                "-c",
                'fnm ls | awk -v current="$(fnm current)" \'$2 != "system" && $2 != current { print $2 }\''
                .. " | xargs -r -n1 fnm uninstall",
            },
        },
    },
    { name = "rust binaries",  requires = "cargo-install-update", run = { { "cargo", "install-update", "-a" } } },
    { name = "rust toolchain", requires = "rustup",               run = { { "rustup", "update" } } },
}
