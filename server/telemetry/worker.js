// Backend mínimo da telemetria (SDD-fase-5 3.2): Cloudflare Worker + D1.
//   POST /v1/events  lote JSON (até 50 eventos) → grava só os campos conhecidos
//   POST /v1/delete  {install_id}               → apaga tudo daquele id
// Não lê nem grava IP, user-agent ou qualquer cabeçalho (RNF-5.03).

export const MAX_BATCH = 50;
export const EVENTS = ['match_end', 'session_start', 'tutorial_end', 'error'];

// Campos aceitos por evento (o resto é descartado). Espelha Telemetry.MATCH_FIELDS do jogo.
const COMMON = ['v', 'install_id', 'app', 'platform', 'event'];
export const FIELDS = {
  match_end: [...COMMON, 'mode', 'level', 'won', 'sets', 'duration_s', 'rally_avg', 'rally_best', 'perfect_rate',
    'points_lost_by', 'serve_types', 'blocks', 'dives', 'options'],
  session_start: [...COMMON, 'lang'],
  tutorial_end: [...COMMON, 'skipped', 'worst_step'],
  error: [...COMMON, 'message', 'where'],
};

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;

// Evento limpo (só campos conhecidos) ou null se inválido.
export function clean(e) {
  if (!e || typeof e !== 'object' || !EVENTS.includes(e.event) || !UUID.test(String(e.install_id))) return null;
  const out = {};
  for (const k of FIELDS[e.event]) if (k in e) out[k] = e[k];
  const body = JSON.stringify(out);
  return body.length <= 4000 ? out : null;
}

function json(status, data) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'content-type': 'application/json', 'access-control-allow-origin': '*' },
  });
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: {
        'access-control-allow-origin': '*', 'access-control-allow-methods': 'POST',
        'access-control-allow-headers': 'content-type' } });
    }
    if (request.method !== 'POST') return json(405, { error: 'method' });
    let data;
    try { data = await request.json(); } catch { return json(400, { error: 'json' }); }

    if (url.pathname === '/v1/events') {
      if (!Array.isArray(data) || data.length > MAX_BATCH) return json(400, { error: 'batch' });
      const rows = data.map(clean).filter(Boolean);
      const day = new Date().toISOString().slice(0, 10);     // só o dia: sem horário exato
      if (rows.length) {
        await env.DB.batch(rows.map((r) => env.DB
          .prepare('INSERT INTO events (install_id, event, app, platform, day, body) VALUES (?, ?, ?, ?, ?, ?)')
          .bind(r.install_id, r.event, String(r.app ?? ''), String(r.platform ?? ''), day, JSON.stringify(r))));
      }
      return json(200, { stored: rows.length, dropped: data.length - rows.length });
    }
    if (url.pathname === '/v1/delete') {
      if (!data || !UUID.test(String(data.install_id))) return json(400, { error: 'install_id' });
      const r = await env.DB.prepare('DELETE FROM events WHERE install_id = ?').bind(data.install_id).run();
      return json(200, { deleted: r?.meta?.changes ?? 0 });
    }
    return json(404, { error: 'route' });
  },
};
