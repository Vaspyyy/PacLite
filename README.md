# PacLite

PacLite is a portrait Android Pac-Man roguelite for a personal APK. It keeps continuous maze chasing, pellets, power pellets, fruit, and ghosts, then adds generated scrolling mazes, escalating ghost releases, extreme upgrade synergies, three themed worlds, and an endless mode.

The agreed vision is in [the game design](docs/GAME_DESIGN.md). The order of playable builds and acceptance checks is in [the roadmap](docs/ROADMAP.md).

Status: first playable one-floor milestone in development. The project contains the generated maze, four individual ghost behaviors, swipe steering, pellets, power windows, damage, fruit, exit, camera/minimap, save/resume, bilingual menus, and procedural visuals and audio. The larger three-zone run, upgrades, and endless mode remain on the roadmap.

## Run and build

Open this directory with **Godot 4.7.2** and press Play. On desktop, use a mouse swipe or arrow/WASD keys. The Android export preset targets arm64, portrait mode, and package `com.vaspyyy.paclite`. To export a local debug APK, configure the Android SDK in Godot, then run:

```sh
godot --headless --editor --path . --import --quit
godot --headless --path . --script res://tests/maze_check.gd
mkdir -p build
godot --headless --path . --export-debug Android build/PacLite-debug.apk
```

GitHub Actions runs those checks and uploads an installable debug APK on each push to `main`. Keep the same signing key between builds if you want Android to install an update without removing the app and its saved data. The workflow caches a personal debug key, but a cache eviction can change that key.

The intended audience is the project owner on their Galaxy S24 Ultra. This is a personal fan project, not a commercial release. The repository will contain the full project and project-created assets. No ripped game or music assets are planned.
