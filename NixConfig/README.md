# NixConfig Overview

This directory is organized into host definitions and shared modules.

## Structure

```text
NixConfig/
  flake.nix
  hosts/
  modules/
```

## Module Responsibility

- `modules/common.nix`: shared system defaults, package sets, Nix settings, users, SSH policy.
- `modules/home.nix`: Home Manager configuration and dotfile linking.
- `modules/php.nix`: local PHP/nginx/dnsmasq development stack.
- `modules/containers.nix`: podman + OCI container services.

## Host Responsibility

- `hosts/Wolverine/default.nix`: NVIDIA + Hyprland host specifics.
- `hosts/Mentalist/default.nix`: Intel + Niri host specifics.
- `hosts/*/hardware-config.nix`: scanner-owned hardware modules (regenerated per machine).
