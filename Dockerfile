# ── Builder: compile frontend ──────────────────────────
FROM python:3.11-slim AS builder

RUN apt-get update && apt-get install -y curl && \
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /build
COPY app/package*.json ./
RUN npm ci
COPY app/ ./
RUN npm run build

# ── Runtime ────────────────────────────────────────────
FROM python:3.11-slim

RUN apt-get update && apt-get install -y curl && \
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs && \
    rm -rf /var/lib/apt/lists/*

RUN python3 -m venv /opt/venv && \
    /opt/venv/bin/pip install --upgrade --quiet pip wheel && \
    /opt/venv/bin/pip install --quiet "openbb[all]" openbb-cli

ENV PATH="/opt/venv/bin:$PATH"

COPY --from=builder /build/dist /app/dist
COPY --from=builder /build/node_modules /app/node_modules
COPY app/package.json /app/
COPY app/vite.config.ts /app/

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

WORKDIR /app
EXPOSE 5173 6900

ENTRYPOINT ["docker-entrypoint.sh"]
