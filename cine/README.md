# cine

Single-resource FiveM MVP for cinematic stages backed by routing buckets, server-side spawns, and synced timeline playback.

## ACE

Grant these permissions in your server config:

```cfg
add_ace group.admin cine.use allow
add_ace group.admin cine.manage allow
```

`cine.use` lets a player join/leave stages and use local tools.

`cine.manage` lets a player create stages, load setups, spawn/clear entities, and start/stop playback.

## Layout

- `server/`: stage manager, setup repository, spawn service, playback sync
- `client/`: stage context, world lock, preload, timeline, local camera
- `data/setups/`: JSON setup documents

## Server Exports

```lua
local stageId = exports.cine:CreateStage('demo_alley', source)
exports.cine:JoinStage(source, stageId)
exports.cine:LoadSetup(stageId, 'demo_alley', source)
exports.cine:Spawn(stageId, source)
exports.cine:PlaybackStart(stageId, { delayMs = 1500, requireReady = true }, source)
exports.cine:PlaybackStop(stageId, source)
exports.cine:Clear(stageId, source)
exports.cine:LeaveStage(source)
```

The optional final `source` argument lets a bridge resource preserve controller ownership and ACE enforcement when it calls exports server-side.

## Client/Server Events

Client requests:

- `cine:sv:createStage(requestId, setupId)`
- `cine:sv:joinStage(requestId, stageId)`
- `cine:sv:leaveStage(requestId)`
- `cine:sv:loadSetup(requestId, stageId, setupId)`
- `cine:sv:spawn(requestId, stageId)`
- `cine:sv:clear(requestId, stageId)`
- `cine:sv:playbackStart(requestId, stageId, opts)`
- `cine:sv:playbackStop(requestId, stageId)`

Server replies:

- `cine:cl:requestResult(requestId, ok, payload)`
- `cine:cl:stageState(snapshot)`
- `cine:cl:setupLoaded(stageId, setupId, setupDoc, manifest)`
- `cine:cl:setupCleared(stageId)`
- `cine:cl:entityMap(stageId, entityMap)`
- `cine:cl:preloadRequest(stageId, token, manifest)`
- `cine:cl:playbackStart(stageId, payload)`
- `cine:cl:playbackStop(stageId)`

## Playback Notes

- Playback start is scheduled on the server, then translated to a local start time on each client.
- Camera tracks are always local.
- Networked entity tracks only execute on the current stage controller to avoid conflicting ped/task commands.
- If asset preloading times out, playback still starts and reports the unready member list in the payload.

## Local Camera

- Command: `cinecam`
- Client export: `exports.cine:SetCinematicCameraEnabled(true|false)`

## Included Setup

`data/setups/demo_alley.json` is a minimal sample with:

- world lock
- one prop spawn
- one ped spawn
- a camera keyframe track
- a ped animation track
