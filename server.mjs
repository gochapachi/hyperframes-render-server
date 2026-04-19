/**
 * HyperFrames Render Server — Entry Point
 *
 * Starts the @hyperframes/producer HTTP server for rendering
 * HTML compositions to video. This wraps the built-in producer
 * server with production configuration.
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
import { resolve } from "node:path";

// ── Resolve chrome-headless-shell path ──────────────────────
// The Dockerfile writes the path during build
const shellPathFile = "/root/.chrome-headless-shell-path";
if (existsSync(shellPathFile)) {
  const shellPath = readFileSync(shellPathFile, "utf-8").trim();
  if (shellPath && existsSync(shellPath)) {
    process.env.PRODUCER_HEADLESS_SHELL_PATH = shellPath;
    console.log(`✅ Using chrome-headless-shell: ${shellPath}`);
  }
}

// ── Import and start the producer server ────────────────────
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
║  Container:      ${(process.env.CONTAINER || "false").padEnd(38)}║
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
