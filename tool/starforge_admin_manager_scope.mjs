const baseUrl = process.env.SF_ADMIN_BASE_URL ?? 'https://starforge.78.111.91.113.nip.io';
const adminUsername = process.env.SF_DJANGO_ADMIN_USER;
const adminPassword = process.env.SF_DJANGO_ADMIN_PASSWORD;
const mode = process.env.SF_SCOPE_MODE;
const requestedBranch = process.env.SF_SCOPE_BRANCH ?? '';
const branchDepartment = { '1': '1', '3': '2', '4': '3', '5': '4' };

if (!adminUsername || !adminPassword || !['branch', 'restore'].includes(mode)) {
  throw new Error('Missing admin credentials or invalid SF_SCOPE_MODE');
}
if (mode === 'branch' && !['3', '4', '5'].includes(requestedBranch)) {
  throw new Error('SF_SCOPE_BRANCH must be one of 3, 4, 5');
}

const branch = mode === 'restore' ? '1' : requestedBranch;
const department = branchDepartment[branch];
const cookieJar = new Map();
const cookies = () => [...cookieJar].map(([key, value]) => `${key}=${value}`).join('; ');

function absorbCookies(response) {
  for (const raw of response.headers.getSetCookie()) {
    const pair = raw.split(';', 1)[0];
    const separator = pair.indexOf('=');
    if (separator > 0) cookieJar.set(pair.slice(0, separator), pair.slice(separator + 1));
  }
}

async function request(path, options = {}) {
  const response = await fetch(new URL(path, baseUrl), {
    redirect: 'manual',
    signal: AbortSignal.timeout(45000),
    ...options,
    headers: {
      accept: 'text/html',
      cookie: cookies(),
      ...(options.headers ?? {}),
    },
  });
  absorbCookies(response);
  return { response, html: await response.text() };
}

function csrfFrom(html) {
  return html.match(/name=["']csrfmiddlewaretoken["'][^>]*value=["']([^"']+)/i)?.[1] ?? '';
}

function formErrors(html) {
  return [...html.matchAll(/<ul[^>]*class=["'][^"']*errorlist[^"']*["'][^>]*>([\s\S]*?)<\/ul>/gi)]
    .map((match) => match[1].replace(/<[^>]+>/g, ' ').replace(/\s+/g, ' ').trim())
    .filter(Boolean);
}

async function login() {
  const page = await request('/admin/login/?next=/admin/');
  const csrf = csrfFrom(page.html);
  if (!csrf) throw new Error('Admin login CSRF token is missing');
  const result = await request('/admin/login/?next=/admin/', {
    method: 'POST',
    headers: {
      'content-type': 'application/x-www-form-urlencoded',
      referer: new URL('/admin/login/?next=/admin/', baseUrl).toString(),
      'x-csrftoken': cookieJar.get('csrftoken') ?? csrf,
    },
    body: new URLSearchParams({
      csrfmiddlewaretoken: csrf,
      username: adminUsername,
      password: adminPassword,
      next: '/admin/',
    }),
  });
  if (result.response.status !== 302) throw new Error(`Admin login failed: HTTP ${result.response.status}`);
}

async function updateForm(path, values) {
  const page = await request(path);
  if (page.response.status !== 200) throw new Error(`Cannot open ${path}: HTTP ${page.response.status}`);
  const csrf = csrfFrom(page.html);
  if (!csrf) throw new Error(`CSRF token is missing for ${path}`);
  const result = await request(path, {
    method: 'POST',
    headers: {
      'content-type': 'application/x-www-form-urlencoded',
      referer: new URL(path, baseUrl).toString(),
      'x-csrftoken': cookieJar.get('csrftoken') ?? csrf,
    },
    body: new URLSearchParams({ csrfmiddlewaretoken: csrf, ...values, _save: 'Saqlash' }),
  });
  if (result.response.status !== 302) {
    throw new Error(`Update ${path} failed: HTTP ${result.response.status}; ${formErrors(result.html).join('; ')}`);
  }
}

await login();
await updateForm('/admin/users/rolemembership/2006/change/', {
  staff_account: '10',
  teacher_account: '',
  student_account: '',
  parent_account: '',
  account_type: '14',
  branch,
  department,
  revoked_at_0: '',
  revoked_at_1: '',
});
await updateForm('/admin/org/staffprofile/10/change/', {
  username: 'qa.manager.20260811',
  is_active: 'on',
  first_name: 'QA',
  last_name: 'Manager',
  middle_name: '',
  gender: '',
  phone: '',
  email: 'qa.manager.20260811@starforge.local',
  birthdate: '',
  account_type: '2',
  branch,
  department,
  password1: '',
  password2: '',
});

console.log(JSON.stringify({ updated: true, mode, branch, department }));
