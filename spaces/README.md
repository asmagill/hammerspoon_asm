Work in progress simplification of `hs._asm.undocumented.spaces` to provide basic spaces support within Hammerspoon.

What is present works, but isn't fully documented or tested.

Most functions work in terms of space IDs, but goto and remove still use the missionControl name, so see hs.spaces.missionControlNameForSpace to convert.

If you want to test it before it's fully documented here, you can install the precompiled version into your congfig directory (usually ~/.hammerspoon). The docs.json file will be loaded if you invoke `hs.help("hs.spaces")` from the Hammerspoon console.
