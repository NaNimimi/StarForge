import { writeFileSync } from 'node:fs';

const username = process.env.STARFORGE_TEST_USER || 'ceo';
const password = process.env.STARFORGE_TEST_PASSWORD || 'root';
const port = process.env.STARFORGE_FIREFOX_PORT || '9444';
const output = `/tmp/starforge_firefox_${username}.png`;
const ws = new WebSocket(`ws://127.0.0.1:${port}/session`);

await new Promise((resolve, reject) => {
  ws.addEventListener('open', resolve, { once: true });
  ws.addEventListener('error', reject, { once: true });
});

let nextId = 1;
const pending = new Map();
const responses = [];
const errors = [];
ws.addEventListener('message', (event) => {
  const message = JSON.parse(event.data);
  if (message.id && pending.has(message.id)) {
    const promise = pending.get(message.id);
    pending.delete(message.id);
    if (message.type === 'error') promise.reject(new Error(JSON.stringify(message)));
    else promise.resolve(message.result || {});
    return;
  }
  if (message.method === 'network.responseCompleted') {
    const url = message.params?.request?.url || '';
    if (url.includes('/api/')) {
      responses.push({
        path: new URL(url).pathname,
        status: message.params?.response?.status,
      });
    }
  }
  if (message.method === 'network.fetchError') {
    errors.push(message.params?.request?.url || 'unknown request');
  }
  if (message.method === 'log.entryAdded' && message.params?.level === 'error') {
    errors.push(message.params.text || 'browser log error');
  }
});

function send(method, params = {}) {
  const id = nextId++;
  ws.send(JSON.stringify({ id, method, params }));
  return new Promise((resolve, reject) => pending.set(id, { resolve, reject }));
}

const wait = (milliseconds) => new Promise((resolve) => setTimeout(resolve, milliseconds));

function click(context, x, y) {
  return send('input.performActions', {
    context,
    actions: [{
      type: 'pointer',
      id: 'mouse',
      parameters: { pointerType: 'mouse' },
      actions: [
        { type: 'pointerMove', x, y, duration: 0, origin: 'viewport' },
        { type: 'pointerDown', button: 0 },
        { type: 'pointerUp', button: 0 },
      ],
    }],
  });
}

function typeText(context, value) {
  const actions = [];
  for (const character of value) {
    actions.push({ type: 'keyDown', value: character });
    actions.push({ type: 'keyUp', value: character });
  }
  return send('input.performActions', {
    context,
    actions: [{ type: 'key', id: 'keyboard', actions }],
  });
}

await send('session.new', {
  capabilities: { alwaysMatch: { acceptInsecureCerts: true } },
});
const tree = await send('browsingContext.getTree');
const context = tree.contexts[0]?.context;
if (!context) throw new Error('Firefox has no browsing context');
await send('session.subscribe', {
  events: ['network.responseCompleted', 'network.fetchError', 'log.entryAdded'],
  contexts: [context],
});
await send('browsingContext.setViewport', {
  context,
  viewport: { width: 500, height: 900 },
  devicePixelRatio: 1,
});
await send('browsingContext.navigate', {
  context,
  url: 'http://127.0.0.1:8081/',
  wait: 'complete',
});
await wait(18000);
await click(context, 250, 440);
await typeText(context, username);
await click(context, 250, 500);
await typeText(context, password);
await click(context, 250, 560);
await wait(18000);

const screenshot = await send('browsingContext.captureScreenshot', { context });
writeFileSync(output, Buffer.from(screenshot.data, 'base64'));
const apiStatuses = Object.fromEntries(responses.map((row) => [row.path, row.status]));
process.stdout.write(JSON.stringify({ username, output, apiStatuses, errors }, null, 2));
await send('session.end');
ws.close();
