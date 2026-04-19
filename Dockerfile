# ──────────────────────────────────────────────────────────────
# HyperFrames Render Server — Self-Contained Docker Image
# Runs on Coolify as a self-hosted HTML-to-video rendering API
# ──────────────────────────────────────────────────────────────
# No external COPY needed — everything is created inline
# so Coolify can build with just this Dockerfile
# ──────────────────────────────────────────────────────────────

FROM node:22-bookworm-slim

# ── System dependencies (Chromium, FFmpeg, Fonts) ────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    unzip \
    ffmpeg \
    chromium \
    libgbm1 \
    libnss3 \
    libatk-bridge2.0-0 \
    libdrm2 \
    libxcomposite1 \
    libxdamage1 \
    libxrandr2 \
    libcups2 \
    libasound2 \
    libpangocairo-1.0-0 \
    libxshmfence1 \
    libgtk-3-0 \
    fonts-liberation \
    fonts-noto-color-emoji \
    fonts-noto-cjk \
    fonts-noto-core \
    fonts-noto-extra \
    fonts-noto-ui-core \
    fonts-freefont-ttf \
    fonts-dejavu-core \
    fontconfig \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean \
    && fc-cache -fv

# ── Chromium configuration ───────────────────────────────────
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium
ENV CONTAINER=true

# ── Install chrome-headless-shell for BeginFrame rendering ───
RUN npx --yes @puppeteer/browsers install chrome-headless-shell@stable \
      --path /root/.cache/puppeteer \
    && SHELL_PATH=$(find /root/.cache/puppeteer/chrome-headless-shell -name "chrome-headless-shell" -type f | head -1) \
    && echo "$SHELL_PATH" > /root/.chrome-headless-shell-path

WORKDIR /app

# ── Create package.json inline ───────────────────────────────
RUN cat > package.json << 'PACKAGE_EOF'
{
  "name": "hyperframes-render-server",
  "version": "1.0.0",
  "description": "Self-hosted HyperFrames HTML-to-video rendering API",
  "type": "module",
  "main": "server.mjs",
  "dependencies": {
    "@hyperframes/producer": "^0.4.6",
    "@hyperframes/core": "^0.4.6",
    "@hono/node-server": "^1.13.0",
    "hono": "^4.6.0",
    "puppeteer": "^24.0.0",
    "puppeteer-core": "^24.39.1"
  },
  "engines": {
    "node": ">=22"
  }
}
PACKAGE_EOF

# ── Install npm dependencies ────────────────────────────────
RUN npm install --production

# ── Create server entry point inline ─────────────────────────
RUN cat > server.mjs << 'SERVER_EOF'
/**
 * HyperFrames Render Server — Entry Point
 * Starts the @hyperframes/producer HTTP server.
 *
 * API Endpoints:
 *   POST /render         — Blocking render (html, projectDir, or previewUrl)
 *   POST /render/stream  — SSE streaming render with progress
 *   GET  /render/queue   — Current render queue status
 *   POST /lint           — Hyperframe composition lint
 *   GET  /health         — Health check
 *   GET  /outputs/:token — Download rendered MP4
 */

import { readFileSync, existsSync } from "node:fs";

// Resolve chrome-headless-shell path
const shellPathFile = "/root/.chrome-headless-shell-path";
if (existsSync(shellPathFile)) {
  const shellPath = readFileSync(shellPathFile, "utf-8").trim();
  if (shellPath && existsSync(shellPath)) {
    process.env.PRODUCER_HEADLESS_SHELL_PATH = shellPath;
    console.log(`✅ chrome-headless-shell: ${shellPath}`);
  }
}

// Import and start the producer server
const { startServer } = await import("@hyperframes/producer/server");

const port = parseInt(process.env.PRODUCER_PORT || "9847", 10);

console.log(`
╔══════════════════════════════════════════════════════════╗
║          HyperFrames Render Server                       ║
║          HTML → Video Rendering API                      ║
╠══════════════════════════════════════════════════════════╣
║  Port:           ${String(port).padEnd(38)}║
║  Renders Dir:    ${(process.env.PRODUCER_RENDERS_DIR || "/tmp").padEnd(38)}║
║  Max Concurrent: ${(process.env.PRODUCER_MAX_CONCURRENT_RENDERS || "2").padEnd(38)}║
╚══════════════════════════════════════════════════════════╝
`);

startServer({
  port,
  rendersDir: process.env.PRODUCER_RENDERS_DIR || "/app/renders",
  maxConcurrentRenders: parseInt(
    process.env.PRODUCER_MAX_CONCURRENT_RENDERS || "2",
    10,
  ),
});
SERVER_EOF

# ── Create runtime directories ───────────────────────────────
RUN mkdir -p /app/renders /app/outputs

# ── Runtime configuration ────────────────────────────────────
ENV NODE_ENV=production
ENV PRODUCER_PORT=9847
ENV PRODUCER_RENDERS_DIR=/app/renders
ENV PRODUCER_MAX_CONCURRENT_RENDERS=2

EXPOSE 9847

CMD ["node", "server.mjs"]
