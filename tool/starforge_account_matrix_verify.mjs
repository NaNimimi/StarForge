const baseUrl = process.env.STARFORGE_API_BASE_URL ?? 'https://starforge.78.111.91.113.nip.io';
const accounts = [
  {
    role: 'manager',
    username: process.env.STARFORGE_MANAGER_USERNAME,
    password: process.env.STARFORGE_MANAGER_PASSWORD,
    checks: [
      '/api/v1/students/?page=1&page_size=100',
      '/api/v1/parents/?page=1&page_size=100',
      '/api/v1/payments/?page=1&page_size=1',
      '/api/v1/finance/invoices/?page=1&page_size=1',
    ],
  },
  {
    role: 'audit',
    username: process.env.STARFORGE_AUDIT_USERNAME,
    password: process.env.STARFORGE_AUDIT_PASSWORD,
    checks: [
      '/api/v1/audit/?page_size=1',
      '/api/v1/approvals/ledger/?page=1&page_size=1',
      '/api/v1/intelligence/rules/',
    ],
  },
  {
    role: 'student',
    username: process.env.STARFORGE_STUDENT_USERNAME,
    password: process.env.STARFORGE_STUDENT_PASSWORD,
    checks: ['/api/v1/students/me/dashboard/', '/api/v1/students/me/report/'],
  },
  {
    role: 'parent',
    username: process.env.STARFORGE_PARENT_USERNAME,
    password: process.env.STARFORGE_PARENT_PASSWORD,
    checks: ['/api/v1/parents/me/children/'],
  },
];

if (accounts.some((account) => !account.username || !account.password)) {
  throw new Error('Missing account matrix credentials');
}

const delay = (milliseconds) => new Promise((resolve) => setTimeout(resolve, milliseconds));

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

function normalizeRole(value) {
  const role = `${value ?? ''}`.toLowerCase().replaceAll('-', '_').replaceAll(' ', '_');
  if (role.includes('manager') || role.includes('head_of')) return 'manager';
  if (role.includes('audit')) return 'audit';
  if (role === 'student') return 'student';
  if (['parent', 'guardian', 'caregiver'].includes(role)) return 'parent';
  return role;
}

async function request(path, { method = 'GET', token, body } = {}) {
  const headers = { accept: 'application/json', 'accept-language': 'en' };
  if (token) headers.authorization = `Bearer ${token}`;
  if (body !== undefined) headers['content-type'] = 'application/json';
  const response = await fetch(new URL(path, baseUrl), {
    method,
    headers,
    body: body === undefined ? undefined : JSON.stringify(body),
    signal: AbortSignal.timeout(45000),
  });
  const text = await response.text();
  let payload = null;
  if (text.trim()) {
    try { payload = JSON.parse(text); } catch { payload = text; }
  }
  return { status: response.status, payload };
}

async function login(account) {
  for (const path of ['/api/v1/auth/login/', '/api/v1/auth/role-login/']) {
    const response = await request(path, {
      method: 'POST',
      body: { username: account.username, password: account.password },
    });
    if ([404, 405].includes(response.status)) continue;
    if (response.status !== 200) throw new Error(`${account.role} login failed: HTTP ${response.status}`);
    const token = findScalar(unwrap(response.payload), new Set(['access', 'access_token', 'token', 'session_key', 'key']));
    if (!token) throw new Error(`${account.role} login returned no token`);
    return token;
  }
  throw new Error(`${account.role} has no working login endpoint`);
}

function listInfo(payload) {
  const data = unwrap(payload);
  const items = Array.isArray(data) ? data : data?.results ?? data?.items ?? data?.data ?? [];
  const pagination = payload?.pagination ?? data?.pagination ?? {};
  return { items: Array.isArray(items) ? items : [], total: pagination.total };
}

function isActiveRecord(record) {
  const value = findScalar(record, new Set(['is_active', 'active']));
  if (value == null) return true;
  return !['false', '0', 'no', 'inactive', 'archived', 'deleted'].includes(`${value}`.toLowerCase());
}

for (const account of accounts) {
  const token = await login(account);
  const me = await request('/api/v1/users/me/', { token });
  if (me.status !== 200) throw new Error(`${account.role} /users/me failed: HTTP ${me.status}`);
  const data = unwrap(me.payload);
  const publishedRole = findScalar(data, new Set(['account_type_slug']))
    ?? findScalar(data, new Set(['role_slug', 'role_name', 'principal_kind']));
  if (normalizeRole(publishedRole) !== account.role) {
    throw new Error(`${account.role} role mismatch: ${publishedRole ?? 'unknown'}`);
  }

  const statuses = [];
  for (const path of account.checks) {
    const response = await request(path, { token });
    if (response.status !== 200) throw new Error(`${account.role} ${path} failed: HTTP ${response.status}`);
    statuses.push({ path, status: response.status });
    if (account.role === 'manager' && path.startsWith('/api/v1/students/')) {
      const list = listInfo(response.payload);
      const activeItems = list.items.filter(isActiveRecord);
      const usernames = activeItems.map((item) => findScalar(item, new Set(['username', 'login']))).filter(Boolean);
      if (activeItems.length !== 1 || usernames.length !== 1 || usernames[0] !== 'qa.student.20260804') {
        throw new Error(`Manager active student inventory mismatch: raw_total=${list.total ?? 'none'}, active_rows=${activeItems.length}, usernames=${JSON.stringify(usernames)}`);
      }
    }
    if (account.role === 'manager' && path.startsWith('/api/v1/parents/')) {
      const list = listInfo(response.payload);
      const activeItems = list.items.filter(isActiveRecord);
      const usernames = activeItems.map((item) => findScalar(item, new Set(['username', 'login']))).filter(Boolean);
      if (activeItems.length !== 1 || usernames.length !== 1 || usernames[0] !== 'qa.parent.20260804') {
        throw new Error(`Manager active parent inventory mismatch: raw_total=${list.total ?? 'none'}, active_rows=${activeItems.length}, usernames=${JSON.stringify(usernames)}`);
      }
    }
  }
  console.log(JSON.stringify({ role: account.role, login: 200, profile: 200, checks: statuses }));
  await delay(900);
}

console.log(JSON.stringify({ complete: true, roles_verified: accounts.map((account) => account.role) }));
