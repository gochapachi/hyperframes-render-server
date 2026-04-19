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
ENV PUPPETEER_DANGEROUS_NO_SANDBOX=true

# ── Install chrome-headless-shell for BeginFrame rendering ───
RUN npx --yes @puppeteer/browsers install chrome-headless-shell@stable \
      --path /root/.cache/puppeteer \
    && SHELL_PATH=$(find /root/.cache/puppeteer/chrome-headless-shell -name "chrome-headless-shell" -type f | head -1) \
    && echo "$SHELL_PATH" > /root/.chrome-headless-shell-path

WORKDIR /app

COPY package.json package-lock.json* ./
RUN npm install --production

# ── Copy server entry point ──────────────────────────────────
COPY server.mjs ./

# ── Create runtime directories ───────────────────────────────
RUN mkdir -p /app/renders /app/outputs

# ── Runtime configuration ────────────────────────────────────
ENV NODE_ENV=production
ENV PRODUCER_PORT=9847
ENV PRODUCER_RENDERS_DIR=/app/renders
ENV PRODUCER_MAX_CONCURRENT_RENDERS=2

EXPOSE 9847

CMD ["node", "server.mjs"]
