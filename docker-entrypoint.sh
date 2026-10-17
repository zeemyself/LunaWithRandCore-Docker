#!/usr/bin/env bash
set -euo pipefail

cd /opt/lunarcore

CONFIG_FILE="${CONFIG_FILE:-./config.json}"

# If config.json does not exist or is empty, initialize a default structure
if [ ! -s "${CONFIG_FILE}" ]; then
    echo "[entrypoint] Initializing default ${CONFIG_FILE}..."
    cat <<'EOF' > "${CONFIG_FILE}"
{
  "accountDatabase": {
    "uri": "mongodb://mongo:27017",
    "collection": "lunarcore",
    "useInternal": false
  },
  "gameDatabase": {
    "uri": "mongodb://mongo:27017",
    "collection": "lunarcore",
    "useInternal": false
  },
  "internalMongoServer": {
    "address": "localhost",
    "port": 27017,
    "filePath": "database.mv"
  },
  "useSameDatabase": true,
  "keystore": {
    "path": "./keystore.p12",
    "password": ""
  },
  "httpServer": {
    "useSSL": false,
    "regionListRefresh": 60000,
    "bindAddress": "0.0.0.0",
    "bindPort": 80,
    "publicAddress": "127.0.0.1",
    "publicPort": null
  },
  "gameServer": {
    "id": "lunar_rail_test",
    "name": "Lunar Core",
    "description": "A LunarCore server",
    "kcpInterval": 40,
    "kcpTimeout": 30,
    "bindAddress": "0.0.0.0",
    "bindPort": 23301,
    "publicAddress": "127.0.0.1",
    "publicPort": null
  },
  "serverOptions": {
    "autoCreateAccount": true,
    "sceneMaxEntites": 500,
    "maxCustomRelicLevel": 15,
    "unlockAllChallenges": true,
    "spendStamina": true,
    "staminaRecoveryRate": 300,
    "staminaReserveRecoveryRate": 1080,
    "startTrailblazerLevel": 1,
    "autoUpgradeWorldLevel": true,
    "language": "EN",
    "defaultPermissions": [
      "*"
    ],
    "maxPlayers": -1
  },
  "resourceDir": "./resources",
  "dataDir": "./data",
  "clientDataDir": ""
}
EOF
fi

# Auto-detect mounted client design data directory if not explicitly provided
CLIENT_DATA_DIR_EFFECTIVE="${CLIENT_DATA_DIR:-}"
if [ -z "${CLIENT_DATA_DIR_EFFECTIVE}" ]; then
    if [ -d "/opt/lunarcore/client_data/Persistent" ] || [ -d "/opt/lunarcore/client_data/StreamingAssets" ]; then
        CLIENT_DATA_DIR_EFFECTIVE="/opt/lunarcore/client_data"
        echo "[entrypoint] Auto-detected client design data at ${CLIENT_DATA_DIR_EFFECTIVE}"
    fi
fi

# Apply environment variable overrides to config.json using jq
if [ "${SKIP_CONFIG_SYNC:-false}" != "true" ]; then
    HTTP_PUB_PORT_JSON="null"
    if [ -n "${HTTP_PUBLIC_PORT:-}" ]; then
        HTTP_PUB_PORT_JSON="${HTTP_PUBLIC_PORT}"
    fi

    GAME_PUB_PORT_JSON="null"
    if [ -n "${GAME_PUBLIC_PORT:-}" ]; then
        GAME_PUB_PORT_JSON="${GAME_PUBLIC_PORT}"
    fi

    TMP_CONFIG="$(mktemp)"
    jq \
        --arg mongo_uri "${MONGO_URI:-mongodb://mongo:27017}" \
        --arg db_collection "${DB_COLLECTION:-lunarcore}" \
        --argjson use_internal "${USE_INTERNAL_MONGO:-false}" \
        --arg http_bind_addr "${HTTP_BIND_ADDRESS:-0.0.0.0}" \
        --argjson http_port "${HTTP_PORT:-80}" \
        --arg http_pub_addr "${HTTP_PUBLIC_ADDRESS:-${PUBLIC_HOST:-127.0.0.1}}" \
        --argjson http_pub_port "${HTTP_PUB_PORT_JSON}" \
        --argjson http_ssl "${HTTP_USE_SSL:-false}" \
        --arg game_bind_addr "${GAME_BIND_ADDRESS:-0.0.0.0}" \
        --argjson game_port "${GAME_PORT:-23301}" \
        --arg game_pub_addr "${GAME_PUBLIC_ADDRESS:-${PUBLIC_HOST:-127.0.0.1}}" \
        --argjson game_pub_port "${GAME_PUB_PORT_JSON}" \
        --argjson auto_account "${AUTO_CREATE_ACCOUNT:-true}" \
        --arg language "${SERVER_LANGUAGE:-EN}" \
        --arg client_data_dir "${CLIENT_DATA_DIR_EFFECTIVE}" \
        '
        .accountDatabase.uri = $mongo_uri |
        .accountDatabase.collection = $db_collection |
        .accountDatabase.useInternal = $use_internal |
        .gameDatabase.uri = $mongo_uri |
        .gameDatabase.collection = $db_collection |
        .gameDatabase.useInternal = $use_internal |
        .httpServer.bindAddress = $http_bind_addr |
        .httpServer.bindPort = $http_port |
        .httpServer.publicAddress = $http_pub_addr |
        .httpServer.publicPort = $http_pub_port |
        .httpServer.useSSL = $http_ssl |
        .gameServer.bindAddress = $game_bind_addr |
        .gameServer.bindPort = $game_port |
        .gameServer.publicAddress = $game_pub_addr |
        .gameServer.publicPort = $game_pub_port |
        .serverOptions.autoCreateAccount = $auto_account |
        .serverOptions.language = $language |
        .clientDataDir = (if $client_data_dir != "" then $client_data_dir else (.clientDataDir // "") end)
        ' "${CONFIG_FILE}" > "${TMP_CONFIG}" && mv "${TMP_CONFIG}" "${CONFIG_FILE}"
fi

echo "[entrypoint] Starting LunarCore..."
# shellcheck disable=SC2086
exec java ${JAVA_OPTS:-} -jar /opt/lunarcore/LunarCore.jar "$@"
