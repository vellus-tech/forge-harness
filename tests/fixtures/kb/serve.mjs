// Servidor HTTP estático mínimo, só em 127.0.0.1, para os gates do /forge:kb servirem modelos de
// fixture ao instalador real. Imprime a porta na primeira linha e registra cada GET em <dir>/.requests.
import { createServer } from 'node:http';
import { readFile, appendFile } from 'node:fs/promises';
import { join, normalize } from 'node:path';
const dir = process.argv[2];
const srv = createServer(async (req, res) => {
  const p = normalize(decodeURIComponent(new URL(req.url, 'http://x').pathname)).replace(/^\/+/, '');
  if (p.includes('..')) { res.writeHead(400); res.end(); return; }
  try { const b = await readFile(join(dir, p)); await appendFile(join(dir, '.requests'), `${p}\n`); res.writeHead(200, { 'content-length': b.length }); res.end(b); }
  catch { res.writeHead(404); res.end(); }
});
srv.listen(0, '127.0.0.1', () => console.log(srv.address().port));
