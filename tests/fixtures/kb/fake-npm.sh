#!/usr/bin/env bash
# npm substituto para os gates do /forge:kb (seam de teste por PATH, como o git substituto): `ci`
# copia para ./node_modules cada pacote do package-lock.json a partir do node_modules do workspace
# (as devDependencies, nas mesmas versões dos pins). Registra a chamada em $FAKE_NPM_LOG.
set -euo pipefail
[ -n "${FAKE_NPM_LOG:-}" ] && echo "npm $*" >> "$FAKE_NPM_LOG"
case "${1:-}" in
  --version) echo "10.0.0-fixture" ;;
  ci)
    : "${FAKE_NPM_SOURCE:?FAKE_NPM_SOURCE ausente}"
    node -e '
      const fs=require("fs"),path=require("path");const lock=JSON.parse(fs.readFileSync("package-lock.json","utf8"));
      for (const k of Object.keys(lock.packages||{})) { if(!k) continue; const src=path.join(process.argv[1],k); const dst=path.join("node_modules",k.replace(/^node_modules\//,""));
        if(!fs.existsSync(src)){console.error("fake-npm: pacote ausente no workspace: "+k);process.exit(1);} fs.mkdirSync(path.dirname(dst),{recursive:true}); fs.cpSync(src,dst,{recursive:true,dereference:true}); }
    ' "$FAKE_NPM_SOURCE" ;;
  *) echo "fake-npm: subcomando não suportado: $*" >&2; exit 2 ;;
esac
