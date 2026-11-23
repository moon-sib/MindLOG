// Прокси между приложением и Claude API. Node 18+.
// ANTHROPIC_API_KEY=... APP_TOKEN=... node server.mjs
import http from "node:http";

const { ANTHROPIC_API_KEY, APP_TOKEN, PORT = 8787, MODEL = "claude-sonnet-5-5" } = process.env;
if (!ANTHROPIC_API_KEY) {
  console.error("Задай ANTHROPIC_API_KEY");
  process.exit(1);
}

const hits = new Map();
function limited(ip) {
  const now = Date.now();
  const arr = (hits.get(ip) ?? []).filter((t) => now - t < 60_000);
  arr.push(now);
  hits.set(ip, arr);
  return arr.length > 20; // 20 запросов в минуту с одного IP
}

function readBody(req, limit = 100_000) {
  return new Promise((resolve, reject) => {
    let size = 0;
    const chunks = [];
    req.on("data", (c) => {
      size += c.length;
      if (size > limit) { reject(new Error("too large")); req.destroy(); return; }
      chunks.push(c);
    });
    req.on("end", () => resolve(Buffer.concat(chunks).toString("utf8")));
    req.on("error", reject);
  });
}

function send(res, code, obj) {
  res.writeHead(code, { "Content-Type": "application/json; charset=utf-8" });
  res.end(JSON.stringify(obj));
}

http.createServer(async (req, res) => {
  try {
    if (req.method !== "POST" || req.url !== "/chat") return send(res, 404, { error: "not found" });
    if (APP_TOKEN && req.headers["x-app-token"] !== APP_TOKEN) return send(res, 401, { error: "unauthorized" });
    if (limited(req.socket.remoteAddress ?? "?")) return send(res, 429, { error: "too many requests" });

    const { system, messages } = JSON.parse(await readBody(req));
    if (typeof system !== "string" || !Array.isArray(messages) || messages.length === 0)
      return send(res, 400, { error: "bad request" });

    const clean = messages
      .filter((m) => (m.role === "user" || m.role === "assistant") && typeof m.content === "string")
      .map((m) => ({ role: m.role, content: m.content.slice(0, 4000) }));
    while (clean.length && clean[0].role !== "user") clean.shift();
    if (!clean.length) return send(res, 400, { error: "no user message" });

    const r = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "x-api-key": ANTHROPIC_API_KEY,
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify({ model: MODEL, max_tokens: 400, system, messages: clean.slice(-30) }),
    });
    if (!r.ok) {
      console.error("Anthropic error", r.status, await r.text());
      return send(res, 502, { error: "upstream error" });
    }
    const data = await r.json();
    const text = (data.content ?? []).filter((b) => b.type === "text").map((b) => b.text).join("\n");
    send(res, 200, { text });
  } catch (e) {
    console.error(e);
    send(res, 500, { error: "server error" });
  }
}).listen(PORT, () => console.log(`MindLog proxy on :${PORT}`));
