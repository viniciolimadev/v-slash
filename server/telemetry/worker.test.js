// Testes do backend (node --test server/telemetry): D1 falso em memória.
import test from 'node:test';
import assert from 'node:assert/strict';
import worker, { clean, FIELDS } from './worker.js';

function fakeDB() {
  const rows = [];
  const db = {
    rows,
    prepare(sql) {
      return {
        bind: (...args) => ({
          sql, args,
          run: async () => {
            if (sql.startsWith('DELETE')) {
              const before = rows.length;
              for (let i = rows.length - 1; i >= 0; i--) if (rows[i][0] === args[0]) rows.splice(i, 1);
              return { meta: { changes: before - rows.length } };
            }
            rows.push(args);
            return { meta: { changes: 1 } };
          },
        }),
      };
    },
    async batch(stmts) { for (const s of stmts) await s.run(); },
  };
  return db;
}

const ID = '3f2a9c1e-7b4d-4e8f-9a1b-2c3d4e5f6a7b';
const match = {
  v: 1, install_id: ID, app: '1.0.0', platform: 'android', event: 'match_end', mode: '1v1', level: 1, won: true,
  sets: [[15, 12], [13, 15], [15, 9]], duration_s: 512, rally_avg: 5.1, rally_best: 14, perfect_rate: 0.42,
  points_lost_by: { 'Bola no chão': 9 }, serve_types: [12, 6, 3], blocks: 4, dives: 2,
  options: { left_handed: false, aim_sens: 1.2 },
};
const post = (path, body, headers = {}) => new Request('https://t.example' + path, {
  method: 'POST', headers: { 'content-type': 'application/json', ...headers }, body: JSON.stringify(body) });

test('POST válido grava o evento com os campos conhecidos', async () => {
  const env = { DB: fakeDB() };
  const res = await worker.fetch(post('/v1/events', [match]), env);
  assert.equal(res.status, 200);
  assert.deepEqual(await res.json(), { stored: 1, dropped: 0 });
  assert.equal(env.DB.rows.length, 1);
  assert.deepEqual(JSON.parse(env.DB.rows[0][5]), match);
});

test('campos extras são descartados e eventos inválidos ignorados', async () => {
  const env = { DB: fakeDB() };
  const extra = { ...match, device_model: 'SM-G991B', ip: '1.2.3.4' };
  const res = await worker.fetch(post('/v1/events', [extra, { event: 'match_end', install_id: 'x' }, { event: 'hack' }]), env);
  assert.deepEqual(await res.json(), { stored: 1, dropped: 2 });
  const body = JSON.parse(env.DB.rows[0][5]);
  assert.equal('device_model' in body, false);
  assert.equal('ip' in body, false);
  assert.deepEqual(Object.keys(body).sort(), [...FIELDS.match_end].sort());
});

test('sem IP nem cabeçalhos na tabela', async () => {
  const env = { DB: fakeDB() };
  await worker.fetch(post('/v1/events', [match], { 'cf-connecting-ip': '9.9.9.9', 'user-agent': 'Godot' }), env);
  const flat = JSON.stringify(env.DB.rows);
  assert.equal(flat.includes('9.9.9.9'), false);
  assert.equal(flat.includes('Godot'), false);
  assert.match(env.DB.rows[0][4], /^\d{4}-\d{2}-\d{2}$/);   // só o dia
});

test('DELETE apaga por install_id', async () => {
  const env = { DB: fakeDB() };
  const other = { ...match, install_id: 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee' };
  await worker.fetch(post('/v1/events', [match, match, other]), env);
  const res = await worker.fetch(post('/v1/delete', { install_id: ID }), env);
  assert.deepEqual(await res.json(), { deleted: 2 });
  assert.equal(env.DB.rows.length, 1);
  assert.equal(env.DB.rows[0][0], other.install_id);
});

test('lote grande, JSON ruim e rota errada são recusados', async () => {
  const env = { DB: fakeDB() };
  assert.equal((await worker.fetch(post('/v1/events', new Array(51).fill(match)), env)).status, 400);
  const bad = new Request('https://t.example/v1/events', { method: 'POST', body: '{' });
  assert.equal((await worker.fetch(bad, env)).status, 400);
  assert.equal((await worker.fetch(post('/v2/x', []), env)).status, 404);
  assert.equal(clean({ ...match, event: 'nope' }), null);
});
