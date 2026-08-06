#!/usr/bin/env node
// gen-banner.mjs — gera o banner do README (docs/assets/banner.png).
//
// Pipeline: este script emite um HTML autocontido e o Chrome headless o fotografa em 2x. Não é
// SVG puro porque SVG depende das fontes instaladas em quem renderiza — no GitHub, num CI Linux
// ou num rsvg local, uma família ausente cai em fallback silencioso e o título vira Helvetica sem
// ninguém perceber. O PNG congela a tipografia; o HTML fica versionado como fonte.
//
// Determinístico: PRNG de semente fixa, sem Math.random e sem Date — rodar de novo produz o mesmo
// arquivo. Mesma disciplina dos demais geradores do harness.
//
// Direção de arte: a forja como fonte de luz física, não como "pop de cor" sobre fundo escuro. A
// barra incandescente sobre a bigorna e o portal ao fundo são as duas únicas fontes luminosas da
// cena; tudo que é visível é visível porque elas iluminam. O neutro é aço azulado — viés frio
// deliberado, para a brasa ler como calor e não como um laranja qualquer sobre cinza.
//
// Uso: node tools/gen-banner.mjs [--out docs/assets/banner.png] [--html-only]
import { writeFileSync, mkdirSync, existsSync } from 'node:fs';
import { dirname, resolve, join, basename } from 'node:path';
import { tmpdir } from 'node:os';
import { execFileSync } from 'node:child_process';

const W = 1600, H = 500;

const C = {
  night:    '#04060A',
  rock:     '#0B111A',
  rockNear: '#121A26',
  steel:    '#1A2432',
  steelLit: '#2A3646',
  ember:    '#FF6A1A',
  spark:    '#FFB454',
  core:     '#FFF0CE',
  silver:   '#B6C1CE',
  dim:      '#5A6675',
};

function rng(seed) {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6D2B79F5) >>> 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
const rand = rng(0x464F5247); // "FORG"
const r = (min, max) => min + rand() * (max - min);
const n = (v, d = 2) => Number(v.toFixed(d));

// Faíscas: partículas pequenas com rastro NA DIREÇÃO CONTRÁRIA ao movimento (sobem, o rastro
// fica abaixo). Tamanho e opacidade caem com a altura; a cor esfria de branco-quente para brasa.
// Cabeça pequena é o que separa faísca de alfinete.
function sparks() {
  const ox = 1112, oy = 292;
  const out = [];
  for (let i = 0; i < 150; i++) {
    const t = rand();
    const x = ox + r(-1, 1) * (14 + t * 190);
    const y = oy - t * r(110, 250) - r(0, 16);
    if (y < 30 || x < 900 || x > 1560) continue;
    const size = n(Math.max(0.45, 1.6 * (1 - t * 0.8) + r(-0.2, 0.4)));
    const op = n(Math.max(0.06, (1 - t * 0.95) * r(0.4, 1)));
    const hue = t < 0.22 ? C.core : (t < 0.6 ? C.spark : C.ember);
    const tail = n(size * r(2.2, 5));
    out.push(
      `<line x1="${n(x)}" y1="${n(y)}" x2="${n(x + r(-1.2, 1.2))}" y2="${n(y + tail)}" stroke="${hue}" stroke-width="${n(size * 0.85)}" stroke-linecap="round" opacity="${n(op * 0.38)}"/>`,
      `<circle cx="${n(x)}" cy="${n(y)}" r="${size}" fill="${hue}" opacity="${op}"/>`,
    );
  }
  return out.join('\n      ');
}

// Poeira de brasa fora de foco: dá profundidade atmosférica sem competir com as faíscas — é o que
// separa "cena iluminada" de "fundo preto com pontinhos".
function motes() {
  const out = [];
  for (let i = 0; i < 40; i++) {
    out.push(`<circle cx="${n(r(700, 1570))}" cy="${n(r(40, 400))}" r="${n(r(1.6, 5))}" fill="${rand() > 0.5 ? C.ember : C.spark}" opacity="${n(r(0.025, 0.085))}"/>`);
  }
  return out.join('\n      ');
}

// Perfil de montanha irregular: vértices sorteados dentro de faixas, para não cair no zigue-zague
// regular de origami que denuncia forma gerada.
function ridge(y0, amp, step, seedShift) {
  const pts = [];
  for (let x = -40; x <= W + 40; x += step) {
    pts.push(`${x} ${n(y0 + r(-amp, amp) + Math.sin((x + seedShift) / 210) * amp * 0.7)}`);
  }
  return `M${pts.join(' L')} L${W + 40} ${H} L-40 ${H} Z`;
}

const scene = `
<svg class="scene" viewBox="0 0 ${W} ${H}" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
  <defs>
    <radialGradient id="forgeGlow" cx="50%" cy="50%" r="50%">
      <stop offset="0" stop-color="${C.core}" stop-opacity="0.55"/>
      <stop offset="0.24" stop-color="${C.ember}" stop-opacity="0.4"/>
      <stop offset="0.6" stop-color="${C.ember}" stop-opacity="0.12"/>
      <stop offset="1" stop-color="${C.ember}" stop-opacity="0"/>
    </radialGradient>
    <radialGradient id="portalGlow" cx="50%" cy="50%" r="50%">
      <stop offset="0" stop-color="${C.core}" stop-opacity="0.7"/>
      <stop offset="0.26" stop-color="${C.spark}" stop-opacity="0.33"/>
      <stop offset="1" stop-color="${C.ember}" stop-opacity="0"/>
    </radialGradient>
    <linearGradient id="portalCore" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="${C.core}"/>
      <stop offset="0.55" stop-color="${C.spark}"/>
      <stop offset="1" stop-color="${C.ember}"/>
    </linearGradient>
    <linearGradient id="billet" x1="0" y1="0" x2="1" y2="0">
      <stop offset="0" stop-color="${C.ember}" stop-opacity="0.3"/>
      <stop offset="0.28" stop-color="${C.spark}"/>
      <stop offset="0.52" stop-color="${C.core}"/>
      <stop offset="0.76" stop-color="${C.spark}"/>
      <stop offset="1" stop-color="${C.ember}" stop-opacity="0.35"/>
    </linearGradient>
    <linearGradient id="anvilFace" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="${C.steelLit}"/>
      <stop offset="0.5" stop-color="${C.steel}"/>
      <stop offset="1" stop-color="#131B27"/>
    </linearGradient>
    <filter id="soft" x="-70%" y="-70%" width="240%" height="240%">
      <feGaussianBlur stdDeviation="30"/>
    </filter>
    <filter id="tight" x="-50%" y="-50%" width="200%" height="200%">
      <feGaussianBlur stdDeviation="9"/>
    </filter>
    <filter id="hair" x="-50%" y="-50%" width="200%" height="200%">
      <feGaussianBlur stdDeviation="2.5"/>
    </filter>
  </defs>

  <ellipse cx="1105" cy="316" rx="470" ry="290" fill="url(#forgeGlow)"/>

  <path d="${ridge(322, 30, 104, 0)}" fill="#050911" opacity="0.95"/>
  <path d="${ridge(438, 16, 140, 640)}" fill="${C.rock}" opacity="0.96"/>

  <g>
    <ellipse cx="1452" cy="196" rx="132" ry="132" fill="url(#portalGlow)"/>
    <rect x="1436" y="140" width="32" height="104" rx="16" fill="url(#portalCore)" filter="url(#tight)" opacity="0.85"/>
    <rect x="1443" y="148" width="18" height="88" rx="9" fill="${C.core}" opacity="0.92"/>
    <g fill="${C.ember}" opacity="0.16">
      <rect x="1330" y="322" width="78" height="6" rx="3"/>
      <rect x="1348" y="304" width="72" height="6" rx="3"/>
      <rect x="1366" y="286" width="66" height="6" rx="3"/>
      <rect x="1384" y="270" width="58" height="5" rx="2.5"/>
    </g>
  </g>

  <g>
    ${motes()}
  </g>

  <!-- bigorna: perfil London pattern (chifre, face, talão, cintura, base) -->
  <g transform="translate(958 292) scale(1.02)">
    <ellipse cx="170" cy="154" rx="200" ry="24" fill="${C.ember}" opacity="0.16" filter="url(#soft)"/>
    <path d="M0 12 C18 4 40 0 66 0 L300 0 L314 7 L314 25 L300 34 L252 34 L246 47 L100 47 L94 34 L66 34 C40 34 18 24 0 12 Z" fill="url(#anvilFace)"/>
    <path d="M100 47 L246 47 L226 106 L120 106 Z" fill="#0B1119"/>
    <path d="M88 106 L258 106 L270 140 L76 140 Z" fill="#141C29"/>
    <path d="M76 140 L270 140 L270 154 L76 154 Z" fill="#090F18"/>
    <path d="M0 12 C18 4 40 0 66 0 L300 0 L314 7 L314 25 L300 34 L252 34 L246 47 L100 47 L94 34 L66 34 C40 34 18 24 0 12 Z" fill="none" stroke="#4E5F74" stroke-width="1.2" opacity="0.55"/>
    <path d="M100 47 L246 47 L226 106 L120 106" fill="none" stroke="#3E4C5E" stroke-width="1" opacity="0.4"/>
    <path d="M88 106 L258 106 L270 140 L76 140 Z" fill="none" stroke="#3E4C5E" stroke-width="1" opacity="0.35"/>
    <path d="M0 12 C18 4 40 0 66 0 L300 0" stroke="${C.ember}" stroke-width="2.6" fill="none" opacity="0.62"/>
    <path d="M88 106 L258 106" stroke="${C.ember}" stroke-width="1.6" fill="none" opacity="0.2"/>
  </g>

  <!-- tarugo incandescente sobre a face -->
  <g>
    <ellipse cx="1112" cy="292" rx="112" ry="30" fill="${C.ember}" opacity="0.5" filter="url(#tight)"/>
    <rect x="1042" y="280" width="146" height="14" rx="7" fill="url(#billet)"/>
    <rect x="1070" y="283" width="90" height="7" rx="3.5" fill="${C.core}" opacity="0.92"/>
    <rect x="1042" y="280" width="146" height="14" rx="7" fill="none" stroke="${C.core}" stroke-width="1" opacity="0.35" filter="url(#hair)"/>
  </g>

  <g>
    ${sparks()}
  </g>
</svg>`;

// A régua de gates encoda algo verdadeiro — a suíte determinista que roda a cada push — em vez de
// decorar com marcadores sem referente.
const rule = Array.from({ length: 34 }, (_, i) => {
  const on = i < 26;
  return `<i class="${on ? 'on' : 'off'}" style="opacity:${on ? n(0.5 + (1 - i / 26) * 0.5) : 0.8}"></i>`;
}).join('');

const html = `<!doctype html>
<meta charset="utf-8">
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  html, body { width: ${W}px; height: ${H}px; }
  body {
    position: relative; overflow: hidden;
    background:
      radial-gradient(120% 140% at 78% 68%, rgba(255,106,26,0.10), transparent 62%),
      linear-gradient(160deg, #070B12 0%, ${C.night} 52%, #02040A 100%);
    font-kerning: normal;
  }
  .scene { position: absolute; inset: 0; width: ${W}px; height: ${H}px; }
  .copy { position: absolute; left: 92px; top: 58px; width: 800px; }

  h1 {
    font-family: "Avenir Next Condensed", "Futura", sans-serif;
    font-weight: 700; font-size: 112px; line-height: 0.94; letter-spacing: 0.055em;
    text-transform: uppercase;
    /* metal frio com a base pegando a luz da brasa: o tipo pertence à cena, não está colado sobre ela */
    background: linear-gradient(178deg, #F2F6FA 0%, #9FADBD 30%, #E2EAF3 48%, #74828F 70%, #C08F55 90%, #7A5530 100%);
    -webkit-background-clip: text; background-clip: text; color: transparent;
    filter: drop-shadow(0 3px 14px rgba(0,0,0,0.65)) drop-shadow(0 0 34px rgba(255,106,26,0.16));
  }
  h1 span { display: block; }

  .bar { width: 92px; height: 3px; border-radius: 2px; background: ${C.ember}; margin: 34px 0 22px; }

  .lede {
    font-family: "Avenir Next Condensed", "Futura", sans-serif;
    font-weight: 500; font-size: 31px; color: ${C.silver}; letter-spacing: 0.005em;
  }
  .pillars {
    font-family: "Avenir Next Condensed", "Futura", sans-serif;
    font-weight: 600; font-size: 20px; color: ${C.dim};
    letter-spacing: 0.16em; text-transform: uppercase; margin-top: 12px;
  }

  .gates { position: absolute; left: 94px; bottom: 40px; display: flex; align-items: flex-end; gap: 10px; }
  .ticks { display: flex; align-items: flex-end; gap: 10.5px; }
  .ticks i { display: block; width: 3px; border-radius: 2px; }
  .ticks i.on  { height: 15px; background: ${C.ember}; }
  .ticks i.off { height: 9px;  background: ${C.steel}; }
  .gates b {
    font-family: "Avenir Next Condensed", "Futura", sans-serif;
    font-weight: 600; font-size: 16px; color: ${C.dim};
    letter-spacing: 0.14em; text-transform: uppercase; margin-left: 14px; line-height: 1;
  }
</style>
${scene}
<div class="copy">
  <h1><span>Forge</span><span>Harness</span></h1>
  <div class="bar"></div>
  <p class="lede">Spec-Driven Development como fonte única</p>
  <p class="pillars">Determinista · Multi-agente · Code graph nativo</p>
</div>
<div class="gates"><span class="ticks">${rule}</span><b>Gates deterministas</b></div>
`;

const outIdx = process.argv.indexOf('--out');
const out = resolve(outIdx > -1 ? process.argv[outIdx + 1] : 'docs/assets/banner.png');
mkdirSync(dirname(out), { recursive: true });

// O HTML é intermediário, não entregável: fica em tmp para não versionar derivado ao lado do PNG.
const htmlPath = join(tmpdir(), basename(out).replace(/\.png$/, "") + ".html");
writeFileSync(htmlPath, html);
console.log(`OK html → ${htmlPath}`);

if (process.argv.includes('--html-only')) process.exit(0);

const CHROME = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
if (!existsSync(CHROME)) {
  console.error(`FAIL: Chrome não encontrado em ${CHROME} — rode com --html-only e fotografe o HTML manualmente`);
  process.exit(1);
}
execFileSync(CHROME, [
  '--headless', '--disable-gpu', '--hide-scrollbars',
  `--screenshot=${out}`,
  `--window-size=${W},${H}`,
  '--force-device-scale-factor=2',
  '--default-background-color=00000000',
  `file://${htmlPath}`,
], { stdio: 'pipe' });
console.log(`OK banner ${W * 2}x${H * 2} → ${out}`);
