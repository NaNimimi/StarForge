import { mkdir, writeFile } from 'node:fs/promises';

const baseUrl = process.env.SF_ADMIN_BASE_URL ?? 'https://starforge.78.111.91.113.nip.io';
const adminUsername = process.env.SF_DJANGO_ADMIN_USER;
const adminPassword = process.env.SF_DJANGO_ADMIN_PASSWORD;
const dryRun = process.env.SF_DRY_RUN !== '0';
const keepStudent = { id: 4, username: 'qa.student.20260804' };
const keepParent = { id: 2, username: 'qa.parent.20260804' };
const simulationPrefix = 'sim.sfpeak.20260810.v1.';

if (!adminUsername || !adminPassword) throw new Error('Missing Django admin credentials');

const delay = (milliseconds) => new Promise((resolve) => setTimeout(resolve, milliseconds));
const cookieJar = new Map();
let lastRequestAt = 0;

function cookies() {
  return [...cookieJar].map(([key, value]) => `${key}=${value}`).join('; ');
}

function absorbCookies(response) {
  for (const raw of response.headers.getSetCookie()) {
    const pair = raw.split(';', 1)[0];
    const separator = pair.indexOf('=');
    if (separator > 0) cookieJar.set(pair.slice(0, separator), pair.slice(separator + 1));
  }
}

async function request(path, options = {}) {
  const elapsed = Date.now() - lastRequestAt;
  if (elapsed < 200) await delay(200 - elapsed);
  lastRequestAt = Date.now();
  const response = await fetch(new URL(path, baseUrl), {
    redirect: 'manual',
    signal: AbortSignal.timeout(45000),
    ...options,
    headers: { accept: 'text/html', cookie: cookies(), ...(options.headers ?? {}) },
  });
  absorbCookies(response);
  return { response, html: await response.text() };
}

function csrfFrom(html) {
  return html.match(/name=["']csrfmiddlewaretoken["'][^>]*value=["']([^"']+)/i)?.[1] ?? '';
}

function decodeHtml(value) {
  return value
    .replaceAll('&amp;', '&')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&#x27;', "'")
    .replace(/<[^>]+>/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function inputAttributes(html, name) {
  return [...html.matchAll(/<input\b([^>]*)>/gi)]
    .map((match) => match[1])
    .find((attributes) => attributes.match(/\bname=["']([^"']+)/i)?.[1] === name);
}

function inputValue(html, name) {
  return inputAttributes(html, name)?.match(/\bvalue=["']([^"']*)/i)?.[1] ?? '';
}

function isChecked(html, name) {
  const attributes = inputAttributes(html, name);
  return attributes != null && /\bchecked\b/i.test(attributes);
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

function rowsFrom(html, modelPath) {
  const result = [];
  const escapedPath = modelPath.replaceAll('/', '\\/');
  for (const match of html.matchAll(/<tr\b[^>]*>([\s\S]*?)<\/tr>/gi)) {
    const row = match[1];
    const id = Number(row.match(new RegExp(`${escapedPath}(\\d+)\\/change\\/`, 'i'))?.[1]);
    if (!Number.isFinite(id)) continue;
    const fieldText = (field) => decodeHtml(
      row.match(new RegExp(`<t[dh][^>]*class=["'][^"']*field-${field}[^"']*["'][^>]*>([\\s\\S]*?)<\\/t[dh]>`, 'i'))?.[1] ?? '',
    );
    if (process.env.SF_DEBUG_ROWS === '1' && [1, 2, 4, 7, 602, 1204, 1326].includes(id)) {
      console.log(JSON.stringify({
        debug_model: modelPath,
        debug_row_id: id,
        classes: [...row.matchAll(/class=["']([^"']+)["']/gi)].map((item) => item[1]),
        boolean_alts: [...row.matchAll(/alt=["']([^"']+)["']/gi)].map((item) => item[1]),
        username: fieldText('username'),
        status: fieldText('status'),
        attribution_status: fieldText('attribution_status'),
      }));
    }
    const activeCell = row.match(/<t[dh][^>]*class=["'][^"']*field-is_active[^"']*["'][^>]*>([\s\S]*?)<\/t[dh]>/i)?.[1] ?? '';
    result.push({
      id,
      active: /alt=["']True["']/i.test(activeCell),
      username: fieldText('username'),
      status: fieldText('status'),
    });
  }
  return result;
}

async function allRows(modelPath) {
  const first = await request(modelPath);
  if (first.response.status !== 200) throw new Error(`Cannot list ${modelPath}: HTTP ${first.response.status}`);
  const pageValues = [...first.html.matchAll(/[?&](?:amp;)?p=(\d+)/g)].map((match) => Number(match[1]));
  const maxPage = Math.max(1, ...pageValues);
  const rows = new Map(rowsFrom(first.html, modelPath).map((row) => [row.id, row]));
  for (let page = 2; page <= maxPage; page++) {
    const response = await request(`${modelPath}?p=${page}`);
    if (response.response.status !== 200) throw new Error(`Cannot list ${modelPath} page ${page}: HTTP ${response.response.status}`);
    for (const row of rowsFrom(response.html, modelPath)) rows.set(row.id, row);
  }
  return [...rows.values()];
}

function serializeForm(html) {
  const body = new URLSearchParams();
  const omitted = new Set(['csrfmiddlewaretoken', 'password1', 'password2', 'photo', 'is_active']);
  for (const match of html.matchAll(/<input\b([^>]*)>/gi)) {
    const attributes = match[1];
    const name = attributes.match(/\bname=["']([^"']+)/i)?.[1];
    const type = (attributes.match(/\btype=["']([^"']+)/i)?.[1] ?? 'text').toLowerCase();
    if (!name || name.startsWith('_') || omitted.has(name) || ['submit', 'button', 'file', 'password'].includes(type)) continue;
    if (['checkbox', 'radio'].includes(type) && !/\bchecked\b/i.test(attributes)) continue;
    body.append(name, attributes.match(/\bvalue=["']([^"']*)/i)?.[1] ?? (type === 'checkbox' ? 'on' : ''));
  }
  for (const match of html.matchAll(/<select\b([^>]*)>([\s\S]*?)<\/select>/gi)) {
    const name = match[1].match(/\bname=["']([^"']+)/i)?.[1];
    if (!name) continue;
    const selected = [...match[2].matchAll(/<option\b([^>]*)>([\s\S]*?)<\/option>/gi)]
      .filter((option) => /\bselected\b/i.test(option[1]));
    if (selected.length === 0) body.append(name, '');
    for (const option of selected) body.append(name, option[1].match(/\bvalue=["']([^"']*)/i)?.[1] ?? '');
  }
  for (const match of html.matchAll(/<textarea\b([^>]*)>([\s\S]*?)<\/textarea>/gi)) {
    const name = match[1].match(/\bname=["']([^"']+)/i)?.[1];
    if (name) body.append(name, decodeHtml(match[2]));
  }
  return body;
}

async function activeDetails(modelPath, rows, kind) {
  const details = [];
  for (let index = 0; index < rows.length; index++) {
    const row = rows[index];
    const page = await request(`${modelPath}${row.id}/change/`);
    if (page.response.status !== 200) throw new Error(`Cannot open ${kind} ${row.id}: HTTP ${page.response.status}`);
    const username = decodeHtml(inputValue(page.html, 'username'));
    const active = isChecked(page.html, 'is_active');
    if (active) details.push({ id: row.id, username, html: page.html });
    if ((index + 1) % 25 === 0 || index + 1 === rows.length) {
      console.log(JSON.stringify({ active_details: kind, completed: index + 1, total: rows.length }));
    }
  }
  return details;
}

function safeBackup(details) {
  return details.map(({ id, username, html }) => ({
    id,
    username,
    fields: Object.fromEntries([...html.matchAll(/<input\b([^>]*)>/gi)]
      .map((match) => {
        const attributes = match[1];
        const name = attributes.match(/\bname=["']([^"']+)/i)?.[1];
        if (!name || name.startsWith('_') || ['csrfmiddlewaretoken', 'password1', 'password2'].includes(name)) return null;
        return [name, {
          value: attributes.match(/\bvalue=["']([^"']*)/i)?.[1] ?? '',
          checked: /\bchecked\b/i.test(attributes),
        }];
      })
      .filter(Boolean)),
  }));
}

async function deactivate(modelPath, details, kind) {
  const summary = { requested: details.length, deactivated: 0, blocked: 0 };
  for (let index = 0; index < details.length; index++) {
    const detail = details[index];
    const path = `${modelPath}${detail.id}/change/`;
    const csrf = csrfFrom(detail.html);
    const body = serializeForm(detail.html);
    body.set('csrfmiddlewaretoken', csrf);
    body.set('_save', 'Saqlash');
    const response = await request(path, {
      method: 'POST',
      headers: {
        'content-type': 'application/x-www-form-urlencoded',
        referer: new URL(path, baseUrl).toString(),
        'x-csrftoken': cookieJar.get('csrftoken') ?? csrf,
      },
      body,
    });
    if (response.response.status === 302) summary.deactivated++;
    else summary.blocked++;
    if ((index + 1) % 10 === 0 || index + 1 === details.length) {
      console.log(JSON.stringify({ progress: kind, completed: index + 1, total: details.length, ...summary }));
    }
  }
  return summary;
}

await login();
const studentPath = '/admin/students/studentprofile/';
const parentPath = '/admin/parents/parentprofile/';
const studentRows = await allRows(studentPath);
const parentRows = await allRows(parentPath);
if (process.env.SF_SAMPLE_ONLY === '1') {
  for (const [kind, path, ids] of [
    ['students', studentPath, [1, 2, 4, 1204, 1326]],
    ['parents', parentPath, [1, 2, 602]],
  ]) {
    for (const id of ids) {
      const page = await request(`${path}${id}/change/`);
      console.log(JSON.stringify({
        sample: kind,
        id,
        status: page.response.status,
        username: decodeHtml(inputValue(page.html, 'username')),
        is_active: isChecked(page.html, 'is_active'),
        enrollment_inputs: process.env.SF_SAMPLE_FIELDS === '1'
          ? [...page.html.matchAll(/<input\b([^>]*)>/gi)]
              .map((match) => ({
                name: match[1].match(/\bname=["']([^"']+)/i)?.[1] ?? '',
                value: match[1].match(/\bvalue=["']([^"']*)/i)?.[1] ?? '',
              }))
              .filter((input) => input.name.startsWith('enrollment_events-'))
          : undefined,
        enrollment_selects: process.env.SF_SAMPLE_FIELDS === '1'
          ? [...page.html.matchAll(/<select\b([^>]*)>([\s\S]*?)<\/select>/gi)]
              .map((match) => {
                const name = match[1].match(/\bname=["']([^"']+)/i)?.[1] ?? '';
                const selected = [...match[2].matchAll(/<option\b([^>]*)>([\s\S]*?)<\/option>/gi)]
                  .filter((option) => /\bselected\b/i.test(option[1]))
                  .map((option) => ({
                    value: option[1].match(/\bvalue=["']([^"']*)/i)?.[1] ?? '',
                    label: decodeHtml(option[2]),
                  }));
                return { name, selected };
              })
              .filter((select) => select.name.startsWith('enrollment_events-'))
          : undefined,
      }));
    }
  }
  process.exit(0);
}
const studentCandidates = studentRows.filter((row) =>
  row.id <= 6
  || (row.username.toLowerCase().startsWith(simulationPrefix) && row.status.toLowerCase() === 'lead'),
);
const parentCandidates = parentRows.filter((row) => row.id <= 2);
const activeStudents = await activeDetails(studentPath, studentCandidates, 'students');
const activeParents = await activeDetails(parentPath, parentCandidates, 'parents');

const keeperStudents = activeStudents.filter((profile) => profile.id === keepStudent.id && profile.username === keepStudent.username);
const keeperParents = activeParents.filter((profile) => profile.id === keepParent.id && profile.username === keepParent.username);
if (keeperStudents.length !== 1) throw new Error('Active keeper student verification failed');
if (keeperParents.length !== 1) throw new Error('Active keeper parent verification failed');

const studentExtras = activeStudents.filter((profile) => profile.id !== keepStudent.id || profile.username !== keepStudent.username);
const parentExtras = activeParents.filter((profile) => profile.id !== keepParent.id || profile.username !== keepParent.username);
const backupDirectory = '/home/mitsu/Downloads/mob/backups';
const backupPath = `${backupDirectory}/starforge_active_profiles_before_final_deactivation_20260811.json`;
await mkdir(backupDirectory, { recursive: true });
await writeFile(backupPath, JSON.stringify({
  captured_at: new Date().toISOString(),
  keeper_student: safeBackup(keeperStudents)[0],
  keeper_parent: safeBackup(keeperParents)[0],
  extra_students: safeBackup(studentExtras),
  extra_parents: safeBackup(parentExtras),
}, null, 2), { mode: 0o600 });

console.log(JSON.stringify({
  dry_run: dryRun,
  student_profiles_total: studentRows.length,
  active_students: activeStudents.length,
  active_student_extras: studentExtras.length,
  parent_profiles_total: parentRows.length,
  active_parents: activeParents.length,
  active_parent_extras: parentExtras.length,
  backup: backupPath,
}));

let parentSummary = null;
let studentSummary = null;
if (!dryRun) {
  parentSummary = await deactivate(parentPath, parentExtras, 'parents');
  studentSummary = await deactivate(studentPath, studentExtras, 'students');
}
console.log(JSON.stringify({ complete: true, dry_run: dryRun, parent_summary: parentSummary, student_summary: studentSummary }));
