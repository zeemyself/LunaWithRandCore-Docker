# LunarCore Docker & Docker Compose

A ready-to-use Docker and Docker Compose setup for building and running [Melledy/LunarCore](https://github.com/Melledy/LunarCore) alongside MongoDB, with game data (`Config`, `ExcelOutput`, `TextMap`) automatically fetched from [Dimbreath/turnbasedgamedata](https://gitlab.com/Dimbreath/turnbasedgamedata) during the image build.

---

## Features

- **Multi-stage Docker Build**:
  1. Clones and compiles `Melledy/LunarCore` (`lite` branch by default, Java 21) into `LunarCore.jar`.
  2. Performs a shallow sparse-checkout of `Config`, `ExcelOutput`, and `TextMap` from GitLab (`Dimbreath/turnbasedgamedata`) so unneeded assets (`Story`, `Stages`, `.git`) are excluded from the final image.
  3. Produces a clean `eclipse-temurin:21-jre-noble` runtime image.
- **External MongoDB 7 Container**: Configured with healthchecks and persistent storage (`mongo_data` volume).
- **Dynamic Configuration via Environment Variables**: `docker-entrypoint.sh` automatically initializes and updates `config.json` on startup using `jq`.
- **Interactive Console Support**: Configured with `stdin_open: true` and `tty: true` so you can attach to the server console at any time to run `/account`, `/give`, or `/help` commands.

---

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/) (20.10+)
- [Docker Compose](https://docs.docker.com/compose/install/) (v2+)
- ~4–6 GB of free disk space (for game resources and Docker layers)

---

## Quick Start

### 1. Configure Environment (Optional)

Copy `.env.example` to `.env` if you want to customize ports, memory limits, public IP/domain, or branches:

```bash
cp .env.example .env
```

### 2. Build and Start the Server

```bash
docker compose up -d --build
```

> **Note:** The first build will take several minutes as it compiles `LunarCore.jar` with Gradle and downloads `Config`, `ExcelOutput`, and `TextMap` from GitLab. Subsequent startups are fast.

### 3. View Server Logs

Watch the startup progress (resource loading, handbook generation, and database connection):

```bash
docker compose logs -f lunarcore
```

Wait until you see:
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
| `LUNARCORE_REPO` | `https://github.com/Melledy/LunarCore.git` | Git repository for LunarCore source |
| `LUNARCORE_BRANCH` | `lite` | Branch to build (`lite` for v4.2.0, `development` for v2.5.0) |
| `RESOURCE_REPO` | `https://gitlab.com/Dimbreath/turnbasedgamedata.git` | Git repository for game resources |
| `RESOURCE_BRANCH` | `main` | Branch/tag of the resource repository |
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

1. Log in to the official server at least once in your game client so all client assets are downloaded.
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
