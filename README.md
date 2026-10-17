# LunarCore 4.6 Docker & Docker Compose

A ready-to-use Docker and Docker Compose setup for building and running [KuraXR/LunarCore-4.6](https://github.com/KuraXR/LunarCore-4.6) alongside MongoDB 7, with 4.6 game data (`Config`, `ExcelOutput`, `TextMap`) automatically fetched from [Dimbreath/turnbasedgamedata](https://gitlab.com/Dimbreath/turnbasedgamedata) during the image build.

---

## Features

- **Multi-stage Docker Build**:
  1. Clones and compiles [KuraXR/LunarCore-4.6](https://github.com/KuraXR/LunarCore-4.6) (`main` branch, Java 21) into `LunarCore.jar`.
  2. Performs a shallow sparse-checkout of 4.6 `Config`, `ExcelOutput`, and `TextMap` from GitLab (`Dimbreath/turnbasedgamedata`) so unneeded assets (`Story`, `Stages`, `.git`) are excluded from the final image.
  3. Produces a clean `eclipse-temurin:21-jre-noble` runtime image.
- **4.6 Client Design Data Support (`clientDataDir`)**:
  - In version 4.6, the client requests design data and hotfix archives from `/design_data` before loading game scenes.
  - Built-in volume mount (`./client_data` or `CLIENT_DATA_PATH`) with automatic detection of your client's `StarRail_Data` folder.
- **External MongoDB 7 Container**: Configured with healthchecks and persistent storage (`mongo_data` volume).
- **Dynamic Configuration via Environment Variables**: `docker-entrypoint.sh` automatically initializes and updates `config.json` on startup using `jq`.
- **Interactive Console Support**: Configured with `stdin_open: true` and `tty: true` so you can attach to the server console at any time to run `/account`, `/give`, `/avatar`, or `/help` commands.

---

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/) (20.10+)
- [Docker Compose](https://docs.docker.com/compose/install/) (v2+)
- ~4–6 GB of free disk space (for game resources and Docker layers)
- 4.6.0 Game Client (logged in at least once to an official server to download local client assets)

---

## Quick Start

### 1. Configure Environment (Optional)

Copy `.env.example` to `.env` if you want to customize ports, memory limits, public IP/domain, or branches:

```bash
cp .env.example .env
```

### 2. Client Design Data Setup (4.6 Client)

In version 4.6, the client requests design data from LunarCore. If missing, the client will stall at 0% with an empty dialog.

> [!TIP]
> **Do NOT copy the entire `StarRail_Data` folder (~112 GB).** LunarCore only requires **~5–10 MB** of version manifest files (`DesignData` and `NativeData`), not the large 3D models, audio, or cutscenes (`AssetBundles/`, `Audio/`, `Video/`).

From your client PC's `StarRail_Data` folder, copy only these **3 subfolders**:
1. `StarRail_Data/Persistent/DesignData/` (~few MB)
2. `StarRail_Data/Persistent/NativeData/` (~few MB)
3. `StarRail_Data/StreamingAssets/DesignData/` (~few KB)

Place them into `./client_data` on your server to match this structure:

```text
fervent-lovelace/
└── client_data/
    ├── Persistent/
    │   ├── DesignData/
    │   │   └── Windows/
    │   │       ├── M_DesignV.bytes
    │   │       └── DesignV_*.bytes
    │   └── NativeData/
    │       └── Windows/
    │           ├── M_NativeDataV.bytes
    │           └── NativeDataV_*.bytes
    └── StreamingAssets/
        └── DesignData/
            └── Windows/
                └── M_DesignV.bytes
```

#### One-Click Extraction from Windows Client (PowerShell)
If your client is on a Windows machine, open PowerShell and run:

```powershell
$gameData = "C:\Program Files\HoYoPlay\games\Star Rail Games\StarRail_Data"
$outDir = "$HOME\Desktop\client_data"

New-Item -ItemType Directory -Force -Path "$outDir\Persistent", "$outDir\StreamingAssets"
Copy-Item -Recurse -Force "$gameData\Persistent\DesignData" "$outDir\Persistent\"
Copy-Item -Recurse -Force "$gameData\Persistent\NativeData" "$outDir\Persistent\"
Copy-Item -Recurse -Force "$gameData\StreamingAssets\DesignData" "$outDir\StreamingAssets\"

Compress-Archive -Path "$outDir\*" -DestinationPath "$HOME\Desktop\client_data.zip"
```

Transfer `client_data.zip` (~5–10 MB) to your server and unzip it into `./client_data`. The server container will automatically detect it on startup.

### 3. Build and Start the Server

```bash
docker compose up -d --build
```

> **Note:** The first build will take several minutes as it compiles `LunarCore.jar` with Gradle and downloads 4.6 game resources (`Config`, `ExcelOutput`, `TextMap`) from GitLab. Subsequent startups are fast.

### 4. View Server Logs

Watch the startup progress (resource loading, handbook generation, and database connection):

```bash
docker compose logs -f lunarcore
```

Wait until you see:
- `Game version: 4.6.0`
- `Resource loading complete`
- `Connected to the MongoDB database at mongodb://mongo:27017`

---

## Using the Interactive Server Console

LunarCore includes an interactive CLI console for running server commands (`/account`, `/give`, `/avatar`, `/help`, etc.).

1. **Attach to the running container:**
   ```bash
   docker attach lunarcore
   ```
2. **Run commands at the `> ` prompt:**
   ```text
   > /status
   > /account create player
   > /help
   ```
3. **Detach without stopping the server:**
   Press **`Ctrl+P`** followed by **`Ctrl+Q`**. *(Do not press `Ctrl+C`, as that will stop the server container.)*

> **Tip:** You can also run commands in-game by messaging the dummy friend named **"Server"** in your in-game friends list.

---

## Configuration Reference (`.env`)

| Variable | Default | Description |
| :--- | :--- | :--- |
| `LUNARCORE_REPO` | `https://github.com/KuraXR/LunarCore-4.6.git` | Git repository for LunarCore 4.6 source |
| `LUNARCORE_BRANCH` | `main` | Branch to build (`main` for v4.6.0) |
| `RESOURCE_REPO` | `https://gitlab.com/Dimbreath/turnbasedgamedata.git` | Git repository for game resources |
| `RESOURCE_BRANCH` | `main` | Branch/tag of the resource repository (4.6 data) |
| `CLIENT_DATA_PATH` | `./client_data` | Host directory containing the client's `StarRail_Data` |
| `CLIENT_DATA_DIR` | *(auto-detected)* | Container path for `clientDataDir` (set automatically when mounted) |
| `PUBLIC_HOST` | `127.0.0.1` | Default public IP or hostname advertised to clients |
| `HTTP_HOST_PORT` | `80` | Host TCP port mapped to the HTTP dispatch server |
| `HTTP_PORT` | `80` | Container bind port for the HTTP dispatch server |
| `HTTP_PUBLIC_ADDRESS` | `127.0.0.1` | Public address advertised by the HTTP dispatch server |
| `HTTP_PUBLIC_PORT` | *(empty)* | Public port advertised by HTTP server (defaults to `HTTP_PORT`) |
| `GAME_HOST_PORT` | `23301` | Host UDP port mapped to the KCP game server |
| `GAME_PORT` | `23301` | Container bind port for the KCP game server |
| `GAME_PUBLIC_ADDRESS` | `127.0.0.1` | Public address advertised for the KCP game server |
| `GAME_PUBLIC_PORT` | *(empty)* | Public port advertised for KCP game server (defaults to `GAME_PORT`) |
| `AUTO_CREATE_ACCOUNT` | `true` | Automatically create accounts on first login |
| `SERVER_LANGUAGE` | `EN` | Language code used for generating `Lunar Core Handbook.txt` |
| `JAVA_OPTS` | `-Xms1G -Xmx4G` | JVM memory and garbage collection arguments |
| `SKIP_CONFIG_SYNC` | `false` | Set to `true` to prevent `docker-entrypoint.sh` from overwriting `config.json` with env vars |

---

## Connecting with the Client (Fiddler Classic)

1. Log in to the official server at least once in your 4.6 game client so all client assets are downloaded.
2. Open **Fiddler Classic** and paste the following into the **FiddlerScript** tab (replace `localhost` if hosting on a remote machine or custom port):

```csharp
import System;
import System.Windows.Forms;
import Fiddler;
import System.Text.RegularExpressions;

class Handlers
{
    static function OnBeforeRequest(oS: Session) {
        if (oS.host.EndsWith(".starrails.com") || oS.host.EndsWith(".hoyoverse.com") || oS.host.EndsWith(".mihoyo.com") || oS.host.EndsWith(".bhsr.com")) {
            oS.oRequest.headers.UriScheme = "http";
            oS.host = "localhost"; // Or your server IP:PORT if HTTP_HOST_PORT != 80
        }
    }
};
```

3. Log in with any username (if `AUTO_CREATE_ACCOUNT=true`) or an account created via `/account create <username>`. The password field can be anything.

---

## Persistent Data & Volumes

- **`mongo_data`** *(Docker named volume)*: Stores MongoDB database files (`/data/db`).
- **`lunarcore_data`** *(Docker named volume)*: Stores LunarCore's `data/` JSON files (`Banners.json`, `ActivityScheduling.json`, `RogueMapGen.json`).
- **`./client_data`** *(Bind mount)*: Read-only mount for the ~5–10 MB client design data manifests (`Persistent/DesignData`, `Persistent/NativeData`, `StreamingAssets/DesignData`).
- **`./plugins`** *(Bind mount)*: Drop LunarCore plugin `.jar` files here and restart the container to load them.
- **`./logs`** *(Bind mount)*: Server log files written on the host.

### Exporting the Generated Handbook

LunarCore generates `Lunar Core Handbook.txt` (containing item, avatar, monster, and stage IDs) inside `/opt/lunarcore`. You can copy it to your host machine at any time with:

```bash
docker cp lunarcore:"/opt/lunarcore/Lunar Core Handbook.txt" ./
```

---

## Stopping and Updating

- **Stop the containers:**
  ```bash
  docker compose down
  ```
- **Rebuild with the latest upstream commits:**
  ```bash
  docker compose build --no-cache
  docker compose up -d
  ```
- **Stop and wipe all database data:**
  ```bash
  docker compose down -v
  ```
