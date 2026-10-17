# syntax=docker/dockerfile:1

# ==============================================================================
# Stage 1: Build LunarCore from source
# ==============================================================================
FROM eclipse-temurin:21-jdk-noble AS builder

ARG LUNARCORE_REPO=https://github.com/KuraXR/LunarCore-4.6.git
ARG LUNARCORE_BRANCH=main
ARG GENERATE_PROTO=false

RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src

RUN git clone --depth 1 --branch "${LUNARCORE_BRANCH}" "${LUNARCORE_REPO}" . \
    && chmod +x gradlew \
    && GENERATE_PROTO="${GENERATE_PROTO}" ./gradlew jar --no-daemon

# ==============================================================================
# Stage 2: Fetch required game resources (Config, ExcelOutput, TextMap)
# ==============================================================================
FROM alpine/git:latest AS resources

ARG RESOURCE_REPO=https://gitlab.com/Dimbreath/turnbasedgamedata.git
ARG RESOURCE_BRANCH=main

WORKDIR /resources

RUN git clone \
    --depth 1 \
    --filter=blob:none \
    --sparse \
    --branch "${RESOURCE_BRANCH}" \
    "${RESOURCE_REPO}" . \
    && git sparse-checkout set Config ExcelOutput TextMap \
    && rm -rf .git

# ==============================================================================
# Stage 3: Runtime Image
# ==============================================================================
FROM eclipse-temurin:21-jre-noble AS runtime

RUN apt-get update && apt-get install -y --no-install-recommends \
    jq \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/lunarcore

# Copy compiled server jar and static data files
COPY --from=builder /src/LunarCore.jar /opt/lunarcore/LunarCore.jar
COPY --from=builder /src/data /opt/lunarcore/data

# Copy game resources
COPY --from=resources /resources/Config /opt/lunarcore/resources/Config
COPY --from=resources /resources/ExcelOutput /opt/lunarcore/resources/ExcelOutput
COPY --from=resources /resources/TextMap /opt/lunarcore/resources/TextMap

# Create directories for plugins, logs, and optional client design data
RUN mkdir -p /opt/lunarcore/plugins /opt/lunarcore/logs /opt/lunarcore/client_data

# Copy entrypoint script
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Environment defaults
ENV MONGO_URI="mongodb://mongo:27017" \
    DB_COLLECTION="lunarcore" \
    USE_INTERNAL_MONGO="false" \
    CLIENT_DATA_DIR="" \
    HTTP_BIND_ADDRESS="0.0.0.0" \
    HTTP_PORT="80" \
    HTTP_PUBLIC_ADDRESS="127.0.0.1" \
    HTTP_PUBLIC_PORT="" \
    HTTP_USE_SSL="false" \
    GAME_BIND_ADDRESS="0.0.0.0" \
    GAME_PORT="23301" \
    GAME_PUBLIC_ADDRESS="127.0.0.1" \
    GAME_PUBLIC_PORT="" \
    AUTO_CREATE_ACCOUNT="true" \
    SERVER_LANGUAGE="EN" \
    JAVA_OPTS="-Xms1G -Xmx4G"

# Expose HTTP dispatch server (TCP) and KCP game server (UDP)
EXPOSE 80/tcp
EXPOSE 23301/udp

ENTRYPOINT ["docker-entrypoint.sh"]
