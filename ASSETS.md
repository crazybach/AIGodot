# Asset Download Guide

This game uses free third-party assets that are **not committed to the repository**.
On a fresh checkout you must download them into the paths listed below before
the project will run in the Godot editor.

---

## 1. 2DPIXX Topdown Shooter Pack

**Author:** Jana Ochse (2DPIXX)
**License:** [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) — must credit
**Source:** <https://opengameart.org/content/topdown-shooter-pack-0>

### Files needed

| File | Destination |
|---|---|
| `Soldier/Soldier_Walk.png` | `assets/prototype/2dpixx/soldier_walk.png` |
| `Soldier/Soldier_Shoot.png` | `assets/prototype/2dpixx/soldier_shoot.png` |
| `Soldier/Soldier_Hit.png` | `assets/prototype/2dpixx/soldier_hit.png` |
| `Robot/Robot_Walk.png` | `assets/prototype/2dpixx/robot_walk.png` |
| `Robot/Robot_Shoot.png` | `assets/prototype/2dpixx/robot_shoot.png` |
| `Robot/Robot_Hit.png` | `assets/prototype/2dpixx/robot_hit.png` |
| `Robot/Robot_Explode.png` | `assets/prototype/2dpixx/robot_explode.png` |
| `Tiles/City_Environment.png` | `assets/prototype/2dpixx/city_environment.png` |

> **Note:** The zip extracts with a `PNG/` root folder. Inside you will find
> `Soldier/`, `Robot/`, and `Tiles/` subfolders. Copy the files listed above
> into `assets/prototype/2dpixx/`, stripping the directory prefix.
>
> The original filenames use underscores and uppercase (e.g. `Soldier_Walk.png`).
> Copy them to **lowercase** names as shown in the Destination column.

### Quick commands (PowerShell)

```powershell
# Download the zip
Invoke-WebRequest -Uri "https://opengameart.org/sites/default/files/Topdown%20Shooter%20Pack.zip" -OutFile "$env:TEMP\2dpixx_topdown.zip"

# Extract
Expand-Archive -Path "$env:TEMP\2dpixx_topdown.zip" -DestinationPath "$env:TEMP\2dpixx_topdown"

# Create destination folder
New-Item -ItemType Directory -Force -Path "assets\prototype\2dpixx"

# Copy soldier files
Copy-Item "$env:TEMP\2dpixx_topdown\PNG\Soldier\Soldier_Walk.png"   "assets\prototype\2dpixx\soldier_walk.png"
Copy-Item "$env:TEMP\2dpixx_topdown\PNG\Soldier\Soldier_Shoot.png"  "assets\prototype\2dpixx\soldier_shoot.png"
Copy-Item "$env:TEMP\2dpixx_topdown\PNG\Soldier\Soldier_Hit.png"    "assets\prototype\2dpixx\soldier_hit.png"

# Copy robot files
Copy-Item "$env:TEMP\2dpixx_topdown\PNG\Robot\Robot_Walk.png"    "assets\prototype\2dpixx\robot_walk.png"
Copy-Item "$env:TEMP\2dpixx_topdown\PNG\Robot\Robot_Shoot.png"   "assets\prototype\2dpixx\robot_shoot.png"
Copy-Item "$env:TEMP\2dpixx_topdown\PNG\Robot\Robot_Hit.png"     "assets\prototype\2dpixx\robot_hit.png"
Copy-Item "$env:TEMP\2dpixx_topdown\PNG\Robot\Robot_Explode.png" "assets\prototype\2dpixx\robot_explode.png"

# Copy tileset
Copy-Item "$env:TEMP\2dpixx_topdown\PNG\Tiles\City_Environment.png" "assets\prototype\2dpixx\city_environment.png"
```

### Quick commands (bash / Git Bash)

```bash
# Download and extract
curl -L -o /tmp/2dpixx_topdown.zip "https://opengameart.org/sites/default/files/Topdown%20Shooter%20Pack.zip"
unzip -o /tmp/2dpixx_topdown.zip -d /tmp/2dpixx_topdown

# Create destination
mkdir -p assets/prototype/2dpixx

# Copy files
cp /tmp/2dpixx_topdown/PNG/Soldier/Soldier_Walk.png   assets/prototype/2dpixx/soldier_walk.png
cp /tmp/2dpixx_topdown/PNG/Soldier/Soldier_Shoot.png  assets/prototype/2dpixx/soldier_shoot.png
cp /tmp/2dpixx_topdown/PNG/Soldier/Soldier_Hit.png    assets/prototype/2dpixx/soldier_hit.png
cp /tmp/2dpixx_topdown/PNG/Robot/Robot_Walk.png       assets/prototype/2dpixx/robot_walk.png
cp /tmp/2dpixx_topdown/PNG/Robot/Robot_Shoot.png      assets/prototype/2dpixx/robot_shoot.png
cp /tmp/2dpixx_topdown/PNG/Robot/Robot_Hit.png        assets/prototype/2dpixx/robot_hit.png
cp /tmp/2dpixx_topdown/PNG/Robot/Robot_Explode.png    assets/prototype/2dpixx/robot_explode.png
cp /tmp/2dpixx_topdown/PNG/Tiles/City_Environment.png  assets/prototype/2dpixx/city_environment.png
```

---

## 2. Kenney Top-down Shooter (Zombie enemy)

**Author:** Kenney (kenney.nl)
**License:** [CC0](https://creativecommons.org/publicdomain/zero/1.0/) — public domain, no attribution required (but appreciated)
**Source:** <https://www.kenney.nl/assets/top-down-shooter>

### Files needed

| File | Destination |
|---|---|
| `PNG/Default size/Characters/Zombie 1/zoimbie1_stand.png` | `assets/prototype/kenney/characters/Zombie 1/zoimbie1_stand.png` |

> **Note:** Only the zombie `stand` frame is used by the current game code.
> The zip contains a full character set (gun, hold, machine, reload, silencer,
> stand) — you can extract the whole `Zombie 1/` folder if you want the full
> animation set for future use.

### Quick commands (PowerShell)

```powershell
Invoke-WebRequest -Uri "https://www.kenney.nl/content/3-assets/16-topdown-shooter/topdown-shooter.zip" -OutFile "$env:TEMP\kenney_topdown.zip"
Expand-Archive -Path "$env:TEMP\kenney_topdown.zip" -DestinationPath "$env:TEMP\kenney_topdown"
New-Item -ItemType Directory -Force -Path "assets\prototype\kenney\characters\Zombie 1"
Copy-Item "$env:TEMP\kenney_topdown\PNG\Default size\Characters\Zombie 1\zoimbie1_stand.png" "assets\prototype\kenney\characters\Zombie 1\zoimbie1_stand.png"
```

### Quick commands (bash / Git Bash)

```bash
curl -L -o /tmp/kenney_topdown.zip "https://www.kenney.nl/content/3-assets/16-topdown-shooter/topdown-shooter.zip"
unzip -o /tmp/kenney_topdown.zip -d /tmp/kenney_topdown
mkdir -p "assets/prototype/kenney/characters/Zombie 1"
cp "/tmp/kenney_topdown/PNG/Default size/Characters/Zombie 1/zoimbie1_stand.png" "assets/prototype/kenney/characters/Zombie 1/zoimbie1_stand.png"
```

---

## Verification

After downloading, the following files should exist:

```
assets/prototype/2dpixx/
├── soldier_walk.png      # 1100×275 px  (4 frames × 275)
├── soldier_shoot.png     # 1100×275 px  (4 frames × 275)
├── soldier_hit.png
├── robot_walk.png        # 9000×750 px (12 frames × 750)
├── robot_shoot.png
├── robot_hit.png
├── robot_explode.png
└── city_environment.png

assets/prototype/kenney/characters/Zombie 1/
└── zoimbie1_stand.png    # 33×43 px
```

## Attribution

These assets must be credited in any distributed build:

> **Art by Jana Ochse (2DPIXX) — [www.2dpixx.de](https://www.2dpixx.de)**
> licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).
>
> Additional assets by [Kenney.nl](https://kenney.nl) (CC0).

The game's HUD already includes a credits section — add these lines there or
in a `CREDITS.md` file.
