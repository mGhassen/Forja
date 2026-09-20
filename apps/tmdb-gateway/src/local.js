import http from "node:http";
import { handleRequest } from "./proxy.js";

const port = Number(process.env.PORT || 3000);

const server = http.createServer(async (req, res) => {
  try {
    const host = req.headers.host || `localhost:${port}`;
    const url = new URL(req.url || "/", `http://${host}`);
    const request = new Request(url, {
      method: req.method || "GET",
      headers: req.headers,
    });
    const response = await handleRequest(request);
    res.statusCode = response.status;
    response.headers.forEach((value, key) => {
      res.setHeader(key, value);
    });
    const buf = Buffer.from(await response.arrayBuffer());
    res.end(buf);
  } catch (err) {
    console.error("[tmdb-gateway]", err);
    res.statusCode = 500;
    res.setHeader("Content-Type", "application/json");
    res.end(JSON.stringify({ error: "Internal error" }));
  }
});

server.listen(port, () => {
  console.log(`TMDB gateway listening on http://localhost:${port}`);
  console.log(`  health: GET /health`);
  console.log(`  api:    GET /3/movie/550`);
  console.log(`  image:  GET /t/p/w500/{poster_path}`);
});
