# PacLite game design

## Core promise

A brutally challenging, fast Pac-Man maze chase on Android. The player continuously eats pellets while dodging individually behaving ghosts. Clearing every pellet opens an exit; reaching it earns one of three upgrades. A run grows from a familiar arcade maze into an eerie factory and a frightening void, with spectacular passive combinations that can eventually turn Pac-Man into a ghost-hunting predator.

This document records decisions made during interactive planning. Numbers marked **tuning target** are starting values to validate on the phone, not promises to preserve when playtesting shows a better value.

## Audience, format, and identity

- Personal fan game named **PacLite**, delivered as a sideloadable APK to the owner. There are no ads, purchases, accounts, online requirements, or public commercial release in scope.
- Full source and project-created art/audio live in `Vaspyyy/PacLite`. Use newly made assets rather than copying files from existing games. The intended hero is normal yellow Pac-Man, with the familiar four colored ghosts at the heart of a larger cast. The classic shapes stay recognizable while zone colors and effects change.
- Target the owner's Galaxy S24 Ultra (SM-S928B), portrait orientation, immersive fullscreen respecting display cutouts. Linux desktop play can be added later.
- English and German interface text. No mandatory tutorial, first-run assistance, or adaptive difficulty. A bestiary explains ghosts after they are encountered.
- Selected stack: Godot 2D with GDScript. Game systems and content should be data-driven so later content and Linux support do not require rewriting the core.

## The run

- Main mode: a fixed route through **Arcade → Factory → Void**. Each zone has five regular generated mazes and one unique named boss maze. Defeating the Void boss wins the run and shows a short ending.
- Regular mazes target roughly two to three minutes each. With 15 mazes and three bosses, a successful run may take **40 to 60 minutes**. The earlier 30 to 45 minute estimate yields to the chosen floor count and pace.
- Start with **two hits** of health. The first zone is harsh from the first run. Some upgrades and risky fruit can heal. Small permanent bonuses never give a free third starting hit.
- Four ghosts begin a regular floor; more release from the house at **pellet progress thresholds**, with up to eight active in late main-run mazes. The first floor can use a smaller available roster while still starting with four active ghosts.
- Eat every pellet to open an exit, then reach the exit under pursuit. A floor ends only on exit. Optional fruit and shard opportunities encourage dangerous detours.
- After every regular floor, choose one of three randomly offered upgrades. Offers show exact values, rarity, current stack level, and related owned effects. Boss rewards can use the same choice interface with a stronger pool.
- The player can pause freely. Backgrounding or interruptions auto-pause; resuming requires a deliberate tap. Save the entire active floor every few seconds and on pause/backgrounding. Closing the app should resume the same maze, build, ghost state, and collected progress.
- Abandoning a run requires confirmation and grants no rewards. Death shows score, floor, build, cause of death, newly unlocked content, earned shards, and a quick retry action.

## Movement and phone presentation

- Pac-Man moves continuously along tile corridors. Swipe anywhere on the playfield to queue a direction; the most recent request stays queued until that turn becomes possible. A locked manual reverse upgrade means an opposite swipe cannot reverse in an open corridor initially. Pac-Man automatically turns around at a dead end. Once unlocked, manual reversing becomes a selectable run upgrade.
- A smooth scrolling camera looks ahead in the direction of motion. Its view covers several nearby junctions. Off-screen approaching ghosts have directional edge indicators.
- A small minimap reveals corridors as they are explored and distinguishes remaining pellet clusters and the exit. In the final zone, visibility can tighten as a clearly telegraphed hazard. The normal camera still shows enough nearby information for fair steering.
- Compact persistent HUD: health, score, remaining pellet count, power timer, and minimap. Pause gives access to the build, bestiary, settings, and run summary.
- Strong arcade haptics for meaningful events, with separate intensity control. Avoid vibrating on every ordinary pellet if it blurs feedback or drains the battery.
- Default smooth 60 fps with an optional 120 fps mode on capable devices. Include selectable balanced, efficiency, and performance settings. Pause and background states reduce work.

## Chases, damage, and scoring

- Each ghost has individual targeting behavior, rather than a shared chase/scatter cycle. The four classic ghosts anchor an eventual roster of **eight to ten distinct ghost types**. New ghosts add targeting personalities and clearly signaled powers such as gate control, trails, mimicry, or darkness. Encountering a ghost unlocks its bestiary entry.
- Generated mazes resemble Pac-Man: a ghost house, looping corridors, wrap tunnels, multiple routes, and some dangerous layouts. Maze sizes gradually increase. Generation must always validate basic completion and reachable objectives, even when a layout is nasty.
- A few power pellets are placed in risky but reachable locations on each maze. Base power lasts **about three seconds** (tuning target). A second pellet refreshes the timer without accumulating unused seconds. The final second gets a strong visual flash and sound warning.
- Eating ghosts sends their eyes home; they re-enter after a short delay. Score for successive catches during one power window doubles in the classic pattern. Effects may modify catches, but the baseline chain remains visible.
- On contact while vulnerable, lose one health point, scatter a small handful of recoverable pellets nearby, and get **about one second** of invulnerability (tuning target). The spilled pellets must be eaten before exit because clearing all pellets is still the objective.
- Fruit appears in dangerous locations and primarily grants score, with occasional healing. High scores reward fast clearing, risky fruit, and ghost chains. Records stay local, separated by mode and difficulty.
- Outside power mode, a few conditional upgrades may defeat ghosts. Avoidance remains central without a build designed for that exception.

## Worlds and bosses

| World | Look and play | Boss |
| --- | --- | --- |
| Arcade | Familiar blue-maze starting point, then a modernized palette. Pellet thresholds release new ghosts in waves. | **The Warden** governs the ghost house and its release timing. |
| Factory | Eerie machinery, timed gates, conveyor belts, and telegraphed electric tiles. Hazards can affect the chase without making routes impossible. | **The Engine** turns the learned machine hazards into one combined fight. |
| Void | Genuine eerie horror, distorted visuals and procedural sound. Telegraphed shifting routes, constrained visibility, and ghosts whose established abilities combine. | **The Echo** mimics earlier patterns and coordinates them with changing routes. |

- Bosses are unique named ghosts. Their fights showcase the hazards of their respective zones, with ordinary ghosts joining in phases.
- Clear the boss maze's pellet objectives to open short vulnerable windows; catch the boss **three times** while powered to win. Completed catches persist after damage. Exact phase geometry and pellet reset behavior are implementation tuning decisions, with no impossible softlocks.

## Upgrades and permanent progression

- Main release goal: **more than 100 run upgrades** across power mode, speed/movement, fruit, pellet effects, survival, and ghost control. Build the pool through playable milestones, starting with functional examples from each family.
- Mostly passive synergies. Most upgrades stack; interactions emerge from combinations instead of a catalog of named fusion recipes. Rarity tiers are common, rare, and legendary. Legendary picks can change rules rather than merely increase numbers. Powerful late builds may fill the screen with effects and chain ghost catches.
- Useful core options from every family are available from run one. Further content unlocks at a nearly every-run pace early on, slowing later. Permanent growth combines new options with **tiny capped stat edges**, never replacing the need to dodge.
- Ghost catches have a chance to drop separate **shards**. Later catches in the same power chain improve that chance. Limit shard rewards from a given ghost on a given floor to prevent waiting indefinitely to farm. Death forfeits **20% of that run's shards** (tuning target); the rest enters permanent currency. Voluntary abandonment awards none.
- An arcade-style menu contains Play, the branching permanent unlock tree, bestiary, local records, and settings. Over time every permanent branch can be unlocked; branches are not mutually exclusive.
- Beating the main run unlocks higher challenge tiers with stacked rule modifiers.

## Endless mode

- A separate fresh run starts from the beginning with a new build. After Void, cycle through Arcade, Factory, and Void again with stronger enemies and added modifiers.
- Upgrade stacking has no hard cap; escalating dangers answer increasingly absurd builds. Endless uses its own local score and floor records. It does not continue a main-run victory build.
- No player-facing seed entry or replay UI is planned. Internal deterministic seeds can still support debugging and saves.

## Art, effects, and audio

- Crisp 2D animated sprites, recognizable classic Pac-Man characters and pellets, modernized palettes by zone. Bright glow and motion trails communicate power and chained ghost catches. Late builds can become spectacular.
- Offer reduced flash, particle, and screen shake settings. Essential danger cues must remain legible when intensity is reduced.
- Procedural ambience has calm, slightly unnerving melodic fragments and layers. The emotional references are Factorio and Undertale; create original sounds and compositions. Proximity of ghosts raises tension, power mode shifts harmony, and bosses/void alter the layers. Arcade sound effects have a familiar rhythmic feel without importing recordings.
- Separate music and effects volume controls, plus haptic intensity.

## Delivery and scope

- The first APK is **one complete, generated floor**, with finished-feeling art, interface, controls, camera, audio, save/resume, and the baseline ghosts, pellets, power mode, damage, exit, and result flow. It is a polished slice, not the entire run.
- Every later milestone produces an APK for playtesting, followed by questions grounded in hands-on feedback. Keep source in this repository. Supply APKs to the owner directly and, if a repository release is used, keep test builds in **draft releases** rather than posting public downloads for this personal fan project.
- The game is a personal project using a recognizable Bandai Namco property. Do not treat the present design as cleared for commercial or public distribution. A future public release requires revisiting the identity and rights question first.
