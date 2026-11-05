-- Audio choices the engine leaves to the config: device labels and virtual devices.
return {
    -- `node_name` to the label every mixer row, picker and OSD shows instead of PipeWire's
    -- description. `node_name` survives reboots; `wpctl inspect <id>` prints it as `node.name`.
    names = {
        -- ["alsa_output.pci-0000_00_1f.3.analog-stereo"] = "Speakers",
    },
    -- `shell.lua` passes this list to `mantle.audio:set_virtual_devices` on every load, so an
    -- emptied list removes what an earlier load declared. Each entry shows up in `sinks` or
    -- `sources`. Every kind but `null_sink` runs one `pipewire -c` child under the Supervisor.
    -- To enable one, uncomment it and save: the reload declares it.
    virtual_devices = {
        -- { kind = "echo_cancel", name = "mic_aec", description = "Microphone (echo cancelled)" },
        -- { kind = "null_sink", name = "stream_mix", description = "Stream mix" },
    },
}
