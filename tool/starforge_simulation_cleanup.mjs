import { mkdir, writeFile } from 'node:fs/promises';

const baseUrl = process.env.STARFORGE_API_BASE_URL ?? 'https://starforge.78.111.91.113.nip.io';
const username = process.env.STARFORGE_API_USERNAME;
const password = process.env.STARFORGE_API_PASSWORD;
const branch = process.env.SF_SIM_BRANCH;
const dryRun = process.env.SF_DRY_RUN !== '0';
const simulationPrefix = 'sim.sfpeak.20260810.v1.';

if (!username || !password || !['3', '4', '5'].includes(branch ?? '')) {
  throw new Error('Missing API credentials or invalid SF_SIM_BRANCH');
}

const delay = (milliseconds) => new Promise((resolve) => setTimeout(resolve, milliseconds));
let token = '';
let lastRequestAt = 0;
let requestNumber = 0;

async function api(method, path, { body, authenticated = true, retries = 8, pace = 400 } = {}) {
  const elapsed = Date.now() - lastRequestAt;
  if (elapsed < pace) await delay(pace - elapsed);
  lastRequestAt = Date.now();
  requestNumber++;
  const headers = {
    accept: 'application/json',
    'accept-language': 'en',
    'x-request-id': `sim-cleanup-b${branch}-${Date.now()}-${requestNumber}`,
  };
  if (authenticated && token) headers.authorization = `Bearer ${token}`;
  if (body !== undefined) headers['content-type'] = 'application/json';

  let response;
  try {
    response = await fetch(new URL(path, baseUrl), {
      method,
      headers,
      body: body === undefined ? undefined : JSON.stringify(body),
      redirect: 'manual',
      signal: AbortSignal.timeout(45000),
    });
  } catch (error) {
    if (retries <= 0) throw error;
    await delay(Math.min(15000, (9 - retries) * 1500));
    return api(method, path, { body, authenticated, retries: retries - 1, pace });
  }

  const responseText = await response.text();
  let payload = null;
  if (responseText.trim()) {
    try {
      payload = JSON.parse(responseText);
    } catch {
      payload = responseText;
    }
  }

  if ((response.status === 429 || response.status >= 500) && retries > 0) {
    const retryAfter = Number.parseInt(response.headers.get('retry-after') ?? '', 10);
    const wait = Number.isFinite(retryAfter)
      ? Math.max(1000, retryAfter * 1000 + 250)
      : Math.min(30000, (9 - retries) * 3000);
    console.log(JSON.stringify({ retry: true, status: response.status, wait_ms: wait, retries_left: retries - 1 }));
    await delay(wait);
    return api(method, path, { body, authenticated, retries: retries - 1, pace: Math.max(pace, 500) });
  }
  return { status: response.status, payload };
}

function unwrap(payload) {
  if (payload && typeof payload === 'object' && !Array.isArray(payload) && payload.success === true && 'data' in payload) {
    return payload.data;
  }
  return payload;
}

function findScalar(value, keys, depth = 0) {
  if (value == null || depth > 8) return null;
  if (Array.isArray(value)) {
    for (const child of value) {
      const found = findScalar(child, keys, depth + 1);
      if (found != null) return found;
    }
    return null;
  }
  if (typeof value !== 'object') return null;
  for (const [key, child] of Object.entries(value)) {
    if (keys.has(key.toLowerCase()) && ['string', 'number', 'boolean'].includes(typeof child)) {
      const text = `${child}`.trim();
      if (text) return text;
    }
  }
  for (const child of Object.values(value)) {
    const found = findScalar(child, keys, depth + 1);
    if (found != null) return found;
  }
  return null;
}

function recordId(record) {
  return `${record?.id ?? record?.pk ?? record?.profile_id ?? ''}`.trim();
}

function pageData(payload) {
  const envelope = payload && typeof payload === 'object' && !Array.isArray(payload) ? payload : {};
  const value = unwrap(payload);
  if (Array.isArray(value)) return { items: value, pagination: envelope.pagination ?? {} };
  if (!value || typeof value !== 'object') return { items: [], pagination: {} };
  return {
    items: [value.results, value.items, value.data].find(Array.isArray) ?? [],
    pagination: value.pagination ?? envelope.pagination ?? value,
  };
}

async function login() {
  for (const path of ['/api/v1/auth/login/', '/api/v1/auth/role-login/']) {
    const response = await api('POST', path, {
      body: { username, password },
      authenticated: false,
      pace: 600,
    });
    if (response.status === 404 || response.status === 405) continue;
    if (response.status !== 200) throw new Error(`Login failed: HTTP ${response.status}`);
    token = findScalar(unwrap(response.payload), new Set(['access', 'access_token', 'token', 'session_key', 'key'])) ?? '';
    if (!token) throw new Error('Login returned no bearer token');
    return;
  }
  throw new Error('No working login endpoint');
}

async function listAll(path) {
  const records = new Map();
  for (let page = 1; page <= 100; page++) {
    const response = await api('GET', `${path}?page=${page}&page_size=100`, { pace: 500 });
    if (response.status !== 200) throw new Error(`List ${path} page ${page} failed: HTTP ${response.status}`);
    const parsed = pageData(response.payload);
    let added = 0;
    for (const record of parsed.items) {
      const id = recordId(record);
      if (!id || records.has(id)) continue;
      records.set(id, record);
      added++;
    }
    const pagination = parsed.pagination ?? {};
    const hasNext = pagination.has_next === true
      || pagination.next != null
      || page < Number(pagination.pages ?? pagination.total_pages ?? 0);
    console.log(JSON.stringify({ inventory: path, page, rows: parsed.items.length, total_unique: records.size, has_next: hasNext }));
    if (!hasNext || parsed.items.length === 0 || added === 0) break;
  }
  return [...records.values()];
}

function partition(records) {
  const simulation = [];
  const preserved = [];
  for (const record of records) {
    const loginName = `${findScalar(record, new Set(['username', 'login'])) ?? ''}`.toLowerCase();
    (loginName.startsWith(simulationPrefix) ? simulation : preserved).push(record);
  }
  return { simulation, preserved };
}

async function deleteRecords(path, records, label) {
  const summary = { requested: records.length, deleted: 0, missing: 0, blocked: 0, failed: 0 };
  for (let index = 0; index < records.length; index++) {
    const id = recordId(records[index]);
    const response = await api('DELETE', `${path}${id}/`, { pace: 450 });
    if (response.status >= 200 && response.status < 300) summary.deleted++;
    else if (response.status === 404) summary.missing++;
    else if ([400, 409, 423].includes(response.status)) summary.blocked++;
    else {
      summary.failed++;
      if ([401, 403].includes(response.status)) {
        throw new Error(`${label} delete permission failed on ID ${id}: HTTP ${response.status}`);
      }
    }
    if ((index + 1) % 25 === 0 || index + 1 === records.length) {
      console.log(JSON.stringify({ progress: label, branch, completed: index + 1, total: records.length, ...summary }));
    }
  }
  return summary;
}

await login();
const me = await api('GET', '/api/v1/users/me/', { pace: 600 });
if (me.status !== 200) throw new Error(`/users/me failed: HTTP ${me.status}`);
const role = findScalar(unwrap(me.payload), new Set(['account_type_slug']))
  ?? findScalar(unwrap(me.payload), new Set(['role_slug', 'role_name']));
if (`${role ?? ''}`.toLowerCase() !== 'manager') throw new Error(`Role mismatch: ${role ?? 'unknown'}`);

const students = await listAll('/api/v1/students/');
const parents = await listAll('/api/v1/parents/');
const studentPartition = partition(students);
const parentPartition = partition(parents);
const backupDirectory = '/home/mitsu/Downloads/mob/backups';
const backupPath = `${backupDirectory}/starforge_simulation_branch_${branch}_before_cleanup_20260811.json`;
await mkdir(backupDirectory, { recursive: true });
await writeFile(backupPath, JSON.stringify({
  captured_at: new Date().toISOString(),
  branch,
  students,
  parents,
}, null, 2), { mode: 0o600 });

console.log(JSON.stringify({
  dry_run: dryRun,
  branch,
  students: students.length,
  simulation_students: studentPartition.simulation.length,
  preserved_students: studentPartition.preserved.length,
  parents: parents.length,
  simulation_parents: parentPartition.simulation.length,
  preserved_parents: parentPartition.preserved.length,
  backup: backupPath,
}));

let parentSummary = null;
let studentSummary = null;
if (!dryRun) {
  parentSummary = await deleteRecords('/api/v1/parents/', parentPartition.simulation, 'parents');
  studentSummary = await deleteRecords('/api/v1/students/', studentPartition.simulation, 'students');
}
console.log(JSON.stringify({ complete: true, dry_run: dryRun, branch, parent_summary: parentSummary, student_summary: studentSummary }));
