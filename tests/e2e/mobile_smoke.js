// Teste de ponta a ponta no navegador, emulando um celular na horizontal com toque.
// Abre a versão Web e percorre consentimento → título → opções/privacidade → escolha do bot → tutorial (pular) → partida;
// na partida arrasta o analógico, escolhe o saque flutuante, saca e confere (pelos pixels da tela) que o jogador
// azul realmente se moveu; registra o fps; depois pausa e sai para o menu. Por fim abre uma partida 2v2.
// O jogo publica a tela atual e a posição dos botões em window.__vs (scripts/ui/e2e_hooks.gd).
//
//   node tests/e2e/mobile_smoke.js <url-ou-pasta-export/web> [pasta-dos-prints]
//
// Precisa do pacote "playwright" (npm i playwright && npx playwright install chromium).
// Sai com código 1 se algo falhar.

const { chromium } = require('playwright');
const http = require('http');
const fs = require('fs');
const path = require('path');

const target = process.argv[2] || 'export/web';
const outDir = process.argv[3] || 'export/e2e';
const W = 915, H = 412; // Galaxy S20 deitado

let fails = 0;
function check(ok, what) {
  console.log((ok ? '  ok     ' : '  FALHA  ') + what);
  if (!ok) fails++;
}

// serve a pasta export/web se não for uma URL
function serve(dir) {
  const types = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm',
    '.pck': 'application/octet-stream', '.png': 'image/png' };
  return new Promise((resolve) => {
    const srv = http.createServer((req, res) => {
      const file = path.join(dir, decodeURIComponent(req.url.split('?')[0]).replace(/^\/$/, '/index.html'));
      fs.readFile(file, (err, data) => {
        if (err) { res.writeHead(404); res.end(); return; }
        res.writeHead(200, { 'Content-Type': types[path.extname(file)] || 'application/octet-stream' });
        res.end(data);
      });
    });
    srv.listen(0, () => resolve(srv));
  });
}

// centro dos pixels do jogador (azul forte) num print PNG, decodificado no próprio navegador
async function playerCenter(decoder, png) {
  return decoder.evaluate(async (b64) => {
    const img = new Image();
    img.src = 'data:image/png;base64,' + b64;
    await img.decode();
    const c = document.createElement('canvas');
    c.width = img.width; c.height = img.height;
    const g = c.getContext('2d');
    g.drawImage(img, 0, 0);
    const d = g.getImageData(0, 0, c.width, c.height).data;
    let sx = 0, sy = 0, n = 0;
    for (let i = 0; i < d.length; i += 4) {
      const r = d[i], gr = d[i + 1], b = d[i + 2];
      if (r < 70 && gr > 100 && gr < 190 && b > 180) {
        const p = i / 4;
        sx += p % c.width; sy += Math.floor(p / c.width); n++;
      }
    }
    return n > 30 ? { x: sx / n, y: sy / n, n } : null;
  }, png.toString('base64'));
}

(async () => {
  fs.mkdirSync(outDir, { recursive: true });
  let url = target, srv = null;
  if (!/^https?:/.test(target)) {
    srv = await serve(target);
    url = `http://localhost:${srv.address().port}/index.html`;
  }
  console.log('== celular (toque) em ' + url + ' ==');

  const browser = await chromium.launch({ args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });
  const ctx = await browser.newContext({ viewport: { width: W, height: H }, hasTouch: true, isMobile: true });
  const page = await ctx.newPage();
  const errors = [];
  page.on('pageerror', (e) => errors.push(e.message));
  page.on('console', (m) => { if (m.type() === 'error' || /SCRIPT ERROR/.test(m.text())) errors.push(m.text()); });
  const decoder = await (await browser.newContext()).newPage();

  await page.goto(url);
  await page.waitForFunction(() => document.querySelector('canvas') && window.Engine !== undefined, null, { timeout: 30000 });
  await page.waitForTimeout(6000); // engine + cena

  const cdp = await ctx.newCDPSession(page);
  const touch = (type, pts) => cdp.send('Input.dispatchTouchEvent', {
    type, touchPoints: pts.map(([x, y, id]) => ({ x, y, id })) });

  const shot = async (name) => {
    const png = await page.screenshot({ path: path.join(outDir, name + '.png') });
    return playerCenter(decoder, png);
  };

  // toca no botão que o jogo publicou com esta chave (ex.: "title/play")
  const tap = async (key) => {
    const pos = await page.waitForFunction((k) => window.__vs && window.__vs[k], key, { timeout: 15000 })
      .then((h) => h.jsonValue()).catch(() => null);
    check(pos !== null, `botão ${key} na tela`);
    if (!pos) return;
    await touch('touchStart', [[pos.x, pos.y, 5]]);
    await page.waitForTimeout(80);
    await touch('touchEnd', []);
    await page.waitForTimeout(300);
  };
  const screenIs = async (name) => {
    const ok = await page.waitForFunction((n) => window.__vs && window.__vs.screen === n, name, { timeout: 15000 })
      .then(() => true).catch(() => false);
    check(ok, `tela "${name}"`);
    return ok;
  };

  // 1ª abertura: estatísticas anônimas → "Não enviar"
  await screenIs('consent');
  await shot('0a-consentimento');
  await tap('consent/no');

  // menus
  await screenIs('title');
  await shot('0-titulo');
  await tap('title/options');
  await screenIs('options');
  await shot('0b-opcoes');
  await tap('options/privacy');
  await screenIs('privacy');
  await shot('0c-privacidade');
  await tap('privacy/back');
  await screenIs('options');
  await tap('options/back');
  await screenIs('title');
  await tap('title/play');
  await screenIs('level');
  await shot('1-escolha-do-bot');
  await tap('level/0');
  await screenIs('tutorial');          // save novo: a 1ª partida passa pelo tutorial
  await page.waitForTimeout(800);
  await shot('2-tutorial');
  await tap('tutorial/skip');
  await screenIs('match');
  await page.waitForTimeout(1500);

  const p0 = await shot('3-partida');
  check(p0 !== null, 'partida carregou e o jogador aparece na tela');

  // analógico: polegar na esquerda, arrasta para a direita e segura
  const jx = W * 0.15, jy = H * 0.75;
  await touch('touchStart', [[jx, jy, 0]]);
  for (let i = 1; i <= 8; i++) {
    await touch('touchMove', [[jx + i * 10, jy, 0]]);
    await page.waitForTimeout(30);
  }
  await page.waitForTimeout(1200);
  const p1 = await shot('4-analogico-direita');
  await touch('touchEnd', []);
  const dx = p0 && p1 ? p1.x - p0.x : 0;
  check(dx > 15, `analógico para a direita move o jogador (${dx.toFixed(0)} px)`);

  // e para a esquerda
  await touch('touchStart', [[jx, jy, 0]]);
  for (let i = 1; i <= 8; i++) {
    await touch('touchMove', [[jx - i * 10, jy, 0]]);
    await page.waitForTimeout(30);
  }
  await page.waitForTimeout(1200);
  const p2 = await shot('5-analogico-esquerda');
  await touch('touchEnd', []);
  const dx2 = p1 && p2 ? p2.x - p1.x : 0;
  check(dx2 < -15, `analógico para a esquerda move o jogador (${dx2.toFixed(0)} px)`);

  // seletor de saque (topo direito, só no seu saque): escolhe FLUTUANTE
  await tap('hud/serve/1');
  await shot('6a-saque-flutuante');

  // botão de ação: segura (lança a bola), arrasta a mira, solta (saque)
  const bx = W * 0.85, by = H * 0.75;
  await touch('touchStart', [[bx, by, 1]]);
  await page.waitForTimeout(300);
  await touch('touchMove', [[bx - 30, by - 20, 1]]);
  await page.waitForTimeout(300);
  await shot('6-mirando');
  await touch('touchEnd', []);
  await page.waitForTimeout(1500);
  await shot('7-depois-do-saque');

  // desempenho: o medidor da partida publica fps médio e p1 (no swiftshader é só registro)
  await page.waitForTimeout(1200);
  const perf = await page.evaluate(() => window.__vs && window.__vs.fps);
  console.log('  fps (registro): ' + (perf ? `médio ${perf.avg} · p1 ${perf.p1} · ${perf.frames} quadros` : 'sem dado'));
  check(perf && perf.frames > 30, 'medidor de fps publicou os quadros da partida');

  // pausa e volta ao menu
  await tap('hud/pause');
  await screenIs('pause');
  await shot('8-pausa');
  await tap('pause/quit');
  await screenIs('title');
  await shot('9-de-volta-ao-titulo');

  // 2v2: alternador na escolha do bot, partida com a dica da troca de controle
  await tap('title/play');
  await screenIs('level');
  await tap('level/2v2');
  await shot('10-escolha-2v2');
  await tap('level/0');
  await screenIs('match');
  await page.waitForTimeout(1500);
  const duo = await shot('11-partida-2v2');
  check(duo !== null, 'partida 2v2 carregou e o seu jogador aparece');
  await tap('hud/pause');
  await screenIs('pause');
  await tap('pause/quit');
  await screenIs('title');

  // idioma: Opções → Idioma troca para inglês e o título fica em inglês
  await tap('title/options');
  await screenIs('options');
  const lang0 = await page.evaluate(() => window.__vs.lang);
  await tap('options/lang');
  await screenIs('options');
  await tap('options/back');
  await screenIs('title');
  await shot('12-titulo-outro-idioma');
  const lang1 = await page.evaluate(() => window.__vs.lang);
  check(lang0 && lang1 && lang0 !== lang1 && /^(en|pt_BR)$/.test(lang1), `idioma trocado (${lang0} → ${lang1})`);
  if (lang1 !== 'en') {          // navegador em inglês começa em en: volta uma vez para pt e outra para en
    await tap('title/options'); await screenIs('options'); await tap('options/lang'); await screenIs('options');
    await tap('options/back'); await screenIs('title');
  }
  const play = await page.evaluate(() => window.__vs['title/play.text']);
  check(play === 'PLAY', `título em inglês (JOGAR → ${play})`);

  check(errors.length === 0, 'sem erros no console' + (errors.length ? ': ' + errors.slice(0, 3).join(' | ') : ''));
  console.log('prints em ' + outDir);
  console.log('falhas: ' + fails);
  await browser.close();
  if (srv) srv.close();
  process.exit(fails > 0 ? 1 : 0);
})().catch((e) => { console.error(e); process.exit(1); });
