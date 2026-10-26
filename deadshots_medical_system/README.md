# Deadshot's Medical System

Standalone Garry's Mod addon for a realistic medical system. It is the successor of `deadshots_m_menu_v3` and does not need any gamemode.

## Features

- **Injuries instead of hit points:** every hit creates injuries that match the damage type and hit zone. There are about 44 types, from blaster grazes to fractures, burns, poisoning, radiation and amputations. Armor can stop injuries.
- **Vital signs:** pulse, blood pressure, oxygen saturation, breathing, blood volume, pain and infections are simulated continuously.
- **Unconsciousness:** players go down as a ragdoll and keep their equipment. They wake up when their vitals recover or someone treats them, and may respawn after a configurable time.
- **Death mode:** choose whether only injuries (vital signs), only hit points, or both (whichever comes first) put a player down.
- **Treatment window:**
  - Clickable body image, triage card, vital signs and activity log.
  - Diagnostics, medication (auto-injectors and IV), treatments and other measures such as tourniquet, recovery position, IV access and CPR.
  - Every action has a duration with a progress bar.
- **Access:**
  - Right-click in the context menu (C) on a player or body.
  - Medical datapad (`dms_datapad`): LMB examines the target, RMB examines yourself.
  - Console commands `dms_open` and `dms_self`.
  - F3 while unconscious shows your own condition.
- **Treatments that change injuries:** a treatment can turn an injury into another one or remove it, for example a comminuted fracture becomes a simple fracture once the bone fragments are removed.
- **Medics:** everyone, specific teams or specific user groups, or with DarkRP the job field `medic = true`. Some actions are reserved for medics.
- **In-game configuration:** an icon in the context menu, superadmins only (also `dms_config`).
  - All settings.
  - Language.
  - Per-injury and per-action overrides: disable, frequency, duration, treatments, conversions and so on.
  - Custom content: create new injuries, diagnostics, medication and treatments in-game.
  - A patients page with heal and revive.
- **Languages:** English (default), German and French (`dms_language`).
- **Storage:** server SQLite (`sv.db`), tables `dms_settings` and `dms_patients`. No MySQL is needed.
- **Optional:** ArcCW stun ammunition (`ammo_*_btm`) stuns instead of injuring.

## Installation

Copy the folder `deadshots_medical_system` into `garrysmod/addons/`. No workshop content is required. The body images are included, and the datapad uses the HL2 medkit model.

## Structure

```
lua/autorun/dms_loader.lua   loader (fixed load order)
lua/dms/core                 language, settings, helpers, database, UI building blocks
lua/dms/data                 body parts, injuries, treatments, medication, diagnostics, overrides, custom content
lua/dms/sim                  patients, vital signs, damage, network
lua/dms/client               treatment window, HUD, interaction, config menu
lua/dms/server               config (server)
lua/dms/lang                 en.lua, fr.lua (keys are the German source texts)
lua/weapons/dms_datapad.lua  medical datapad
materials/dms/body           body images
```
