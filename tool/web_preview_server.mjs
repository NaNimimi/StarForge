import { createReadStream, existsSync, statSync } from 'node:fs';
import { createServer, request as httpRequest } from 'node:http';
import { request as httpsRequest } from 'node:https';
import { extname, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';
import { randomUUID } from 'node:crypto';

const host = process.env.STARFORGE_PREVIEW_HOST || '0.0.0.0';
const port = Number(process.env.STARFORGE_PREVIEW_PORT || 8081);
const upstreamUrl = new URL(
  process.env.STARFORGE_API_UPSTREAM || 'http://127.0.0.1:8000',
);
const upstreamHost = process.env.STARFORGE_API_HOST || 'demo.localhost';
const upstreamRequest = upstreamUrl.protocol === 'https:'
  ? httpsRequest
  : httpRequest;
const staticRoot = resolve(
  fileURLToPath(new URL('../build/web/', import.meta.url)),
);

const hopByHopHeaders = new Set([
  'connection',
  'keep-alive',
  'proxy-authenticate',
  'proxy-authorization',
  'te',
  'trailer',
  'transfer-encoding',
  'upgrade',
]);

const mimeTypes = {
  '.css': 'text/css; charset=utf-8',
  '.html': 'text/html; charset=utf-8',
  '.ico': 'image/x-icon',
  '.js': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.map': 'application/json; charset=utf-8',
  '.png': 'image/png',
  '.svg': 'image/svg+xml',
  '.ttf': 'font/ttf',
  '.wasm': 'application/wasm',
  '.webp': 'image/webp',
};

function requestId(headers) {
  const supplied = headers['x-request-id'];
  return typeof supplied === 'string' && supplied.trim()
    ? supplied
    : `preview-${randomUUID().replaceAll('-', '')}`;
}

function safeRequestHeaders(headers, id) {
  const result = {};
  for (const [name, value] of Object.entries(headers)) {
    const key = name.toLowerCase();
    if (
      value == null ||
      hopByHopHeaders.has(key) ||
      key === 'host' ||
      key === 'origin' ||
      key === 'referer' ||
      key.startsWith('sec-fetch-')
    ) {
      continue;
    }
    result[key] = value;
  }
  result.host = upstreamHost;
  result['x-request-id'] = id;
  if (result['content-length']) delete result['transfer-encoding'];
  return result;
}

function safeResponseHeaders(headers, localOrigin) {
  const result = {};
  for (const [name, value] of Object.entries(headers)) {
    const key = name.toLowerCase();
    if (value == null || hopByHopHeaders.has(key)) continue;
    if (key === 'location' && typeof value === 'string') {
      result[key] = value.replace(
        upstreamUrl.origin,
        localOrigin,
      );
    } else {
      result[key] = value;
    }
  }
  result['cache-control'] = 'no-store';
  return result;
}

function proxyApi(req, res) {
  const id = requestId(req.headers);
  const started = Date.now();
  const upstream = upstreamRequest(
    {
      hostname: upstreamUrl.hostname,
      port: upstreamUrl.port || (upstreamUrl.protocol === 'https:' ? 443 : 80),
      method: req.method,
      path: req.url,
      headers: safeRequestHeaders(req.headers, id),
      rejectUnauthorized: upstreamUrl.protocol === 'https:',
    },
    (upstreamResponse) => {
      const localOrigin = `http://${req.headers.host || `${host}:${port}`}`;
      res.writeHead(
        upstreamResponse.statusCode || 502,
        safeResponseHeaders(upstreamResponse.headers, localOrigin),
      );
      upstreamResponse.pipe(res);
      upstreamResponse.on('end', () => {
        console.log(
          `${req.method} ${req.url} -> ${upstreamResponse.statusCode} ` +
            `${Date.now() - started}ms ${id}`,
        );
      });
    },
  );

  upstream.setTimeout(30000, () => {
    upstream.destroy(new Error('Upstream request timed out'));
  });
  upstream.on('error', (error) => {
    if (res.headersSent) {
      res.destroy(error);
      return;
    }
    const body = JSON.stringify({
      success: false,
      error: {
        code: 'preview_proxy_error',
        message: 'API proxy could not reach the upstream server.',
      },
      request_id: id,
    });
    res.writeHead(502, {
      'content-type': 'application/json; charset=utf-8',
      'content-length': Buffer.byteLength(body),
      'cache-control': 'no-store',
      'x-request-id': id,
    });
    res.end(body);
    console.error(`${req.method} ${req.url} -> 502 ${id}: ${error.message}`);
  });
  req.pipe(upstream);
}

function staticFileFor(requestUrl) {
  let pathname;
  try {
    pathname = decodeURIComponent(new URL(requestUrl, 'http://preview').pathname);
  } catch {
    return null;
  }
  const relative = pathname === '/' ? 'index.html' : pathname.replace(/^\/+/, '');
  const candidate = resolve(staticRoot, relative);
  if (candidate !== staticRoot && !candidate.startsWith(`${staticRoot}${sep}`)) {
    return null;
  }
  if (existsSync(candidate) && statSync(candidate).isFile()) return candidate;
  return resolve(staticRoot, 'index.html');
}

function serveStatic(req, res) {
  if (req.method !== 'GET' && req.method !== 'HEAD') {
    res.writeHead(405, { allow: 'GET, HEAD', 'cache-control': 'no-store' });
    res.end();
    return;
  }
  const file = staticFileFor(req.url);
  if (!file || !existsSync(file)) {
    res.writeHead(404, { 'cache-control': 'no-store' });
    res.end('Not found');
    return;
  }
  const size = statSync(file).size;
  res.writeHead(200, {
    'content-type': mimeTypes[extname(file).toLowerCase()] ||
      'application/octet-stream',
    'content-length': size,
    'cache-control': 'no-store',
  });
  if (req.method === 'HEAD') {
    res.end();
  } else {
    createReadStream(file).pipe(res);
  }
}

const server = createServer((req, res) => {
  if (req.url === '/api' || req.url?.startsWith('/api/')) {
    proxyApi(req, res);
  } else {
    serveStatic(req, res);
  }
});

server.listen(port, host, () => {
  console.log(`StarForge web preview: http://${host}:${port}`);
  console.log(`Static root: ${staticRoot}`);
  console.log(`API proxy: ${upstreamUrl.origin} (Host: ${upstreamHost})`);
});
