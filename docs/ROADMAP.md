# PacLite playable roadmap

Each milestone ends with a sideloadable Android APK, a short change log, and a focused playtest on the Galaxy S24 Ultra. The first build prioritizes a coherent presentation rather than placeholder visuals. Content counts grow after the core controls feel right.

## 0. Project foundation

- Godot 2D project with portrait, immersive Android configuration, GDScript systems, content data definitions, bilingual text support, save versioning, and reproducible APK export instructions.
- Establish sprite, HUD, visual effect, procedural audio, and haptic direction. Store the full project and project-created assets in this repository.
- Set up build checks and private draft release workflow for owner-only test APKs.

**Done when:** the project opens cleanly and can export/install a minimal APK on the target device.

## 1. Polished one-floor APK

- Generated looping Pac-Man-style maze with central ghost house, wrap tunnel, pellets, risky power pellets, and an exit that opens only after all pellets are eaten.
- Continuous movement, swipe-anywhere queued turns, dead-end auto reverse, camera lookahead, revealing minimap, edge warnings, compact HUD.
- Four active ghosts with distinct individual targeting, release/progression hooks, eyes returning home, three-second power, doubling ghost score, two-hit health, small recoverable pellet spill, one-second hit protection, and clear game-over flow.
- Close-to-target crisp sprites, glow/trails, reactive procedural ambience, familiar-feeling original effects, strong adjustable haptics, pause, and full floor autosave/resume.
- English and German menus/settings; full screen presentation, 60 fps default, optional 120 fps, efficiency/performance settings.

**Done when:** repeated generated floors are finishable, controls feel reliable at speed, death and retry work, closing mid-floor resumes correctly, and the visual/audio direction feels like PacLite rather than a wireframe.

## 2. First short run

- Multiple floors, one-of-three post-floor choices, rarity/stacking, core examples from every upgrade family, fruit/healing, shard drops and permanent progression.
- Arcade menu, unlock tree, bestiary, local records, result summary, and abandoned-run behavior.
- Tune maze duration, damage recovery, power timing, phone thermals, haptic intensity, and effect readability from actual playtests.

**Done when:** one can finish or lose a multi-floor run, save anywhere, spend earned shards, and feel materially different builds.

## 3. Arcade zone and first boss

- Five arcade floors with pellet-triggered ghost release waves, an expanded ghost cast, The Warden, phased adds, and three powered boss catches.
- Validate hard but learnable first-zone difficulty without hidden first-run assistance.

## 4. Factory zone

- Five floors with rhythmic gates, conveyors, electric tiles, additional ghost behaviors, and The Engine.
- Make hazard telegraphs readable at both default and reduced effect intensity.

## 5. Void zone and main victory

- Five floors with shifting routes, constrained visibility, and combined ghost abilities. Add The Echo, victory sequence, and the full 40 to 60 minute main path.
- Extend the upgrade pool, bestiary, branching unlock tree, and local records.

## 6. Endless, challenge tiers, and content completion

- Fresh-build endless mode that loops harder versions of the three worlds, supports unlimited stacking, and tracks separate local records.
- Win-unlocked difficulty tiers with stacked modifiers. Expand and tune the run upgrade pool beyond 100, including substantial rule-changing legendary options.
- Complete bilingual text, performance modes, save migration, effect controls, and long-run stability testing.

## Playtest feedback after each APK

Ask the owner specifically about swipe reliability, perceived fairness, maze duration, ghost readability, power-window timing, upgrade excitement, audio tension, effect intensity, battery/heat, and any moment where a death felt outside their control. Use that feedback to adjust the next milestone before adding more content.
