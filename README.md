# syncset

Syncset is a [LÖVR](https://lovr.org/) development tool designed to read motion tracking data from a VR headsets and send it to a desktop machine. The purpose of syncset is to enable users to develop and test VR projects on their flat monitors while still using the motion tracking capabilities of their VR headset. It works by reading all the motion tracking data on the VR headset, and sending it to the desktop machine via lua-enet connection. On the desktop the library replaces virtual headset functions with actual motion readings. It should work with almost all popular VR headsets, by utilizing the cross-platform nature of the lovr VR framework.

The synchronized readings include: controller poses, velocities, button status (touched, pressed), axis status (triggers, thumbstick...) and hand tracking skeleton info.

## usage

The syncset has two parts, the host app for the headset and the client library for user project. For Quest headsets, the `syncset-quest.apk` is included in the repo (but it can also be manually built from the sources included in the `hostapp` directory).

The IP address of the headset has to be manually set in the top of the `syncset.lua`. The included `syncset.sh` script can be used both to obtain the IP address of the Quest headset, and to start the host app quickly.

The library `syncset.lua` is `require`'d in any user project, at the end of your `main.lua` source file:

```lua
function lovr.update(dt)
  -- user code
end

require('syncset')
-- end of file
```

This placement ensures that the user's `lovr.update` function can be wrapped inside syncset's own `update` function which also preforms the network syncing. Most of `lovr.headset` functions are replaced with versions that use the same API, but return the motion tracking data received from real headset.


## status

This is alpha-quality release. It has received limited testing, and only with the Oculus Quest headset.

Syncset is licensed under the MIT license. The repository includes `serpent.lua` for convenience, which is also under MIT license.
