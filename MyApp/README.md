# BANANA BLAST

A first-person landscape arcade game prototype for iPhone, built with Swift + SpriteKit.

## Gameplay included
- First-person jungle viewpoint with hands holding a banana.
- Monkeys approach directly ahead along the jungle path.
- Drag in the play area to aim; tap THROW to launch.
- BURST special banana with area damage and limited charges.
- Three hearts; an enemy reaching you costs one heart.
- Score, combo multipliers, coins, best score saved on-device.
- Progressive waves: faster enemies, more enemies, and tougher monkeys.
- Main menu, pause/resume, game-over and replay screens.
- Haptic feedback and built-in system sound effects.

## Upload from iPhone
1. Extract the ZIP in the Files app.
2. Create a GitHub repository named `BANANA-BLAST`.
3. Upload the *contents* of this folder to the repository root, preserving `.github/workflows/build.yml`.
4. Open the repository's Actions tab.
5. Run **Build BANANA BLAST** (or push a commit).
6. Download the `BANANA-BLAST-unsigned` artifact from the completed run.

## Signing
This workflow builds an unsigned app artifact for the later signing/export step. It does not create an installable signed IPA yet. We'll add your developer certificate and provisioning profile after confirming this source builds successfully.

## Next upgrades
Custom pixel sprite sheets, real music/audio, more monkey types, boss fights, additional banana types, unlockable skins, daily challenge, achievements, settings and shop are planned follow-up upgrades.
