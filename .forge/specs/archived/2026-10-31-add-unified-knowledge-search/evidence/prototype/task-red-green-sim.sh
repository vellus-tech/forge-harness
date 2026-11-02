#!/usr/bin/env bash
# Simula vermelho/verde por task: estado(N-1)+testes(N) deve falhar com FAIL [..]; estado(N)+testes(N) deve passar.
S=/private/tmp/claude-501/-Users-milton-Documents-projects-forge-harness/115297fd-902e-467e-a31c-0ff52a521be3/scratchpad
W=/Users/milton/Documents/projects/forge-harness/.forge/worktrees/unified-knowledge-search
I=$S/impl; TS=$S/tests; SIM=$S/sim
rm -rf $SIM; mkdir -p $SIM/tests/fixtures/kb/eval
cp -R $W/template $SIM/template; cp $W/package.json $SIM/; cp -R $W/.forge $SIM/.forge 2>/dev/null; rm -rf $SIM/.forge/kb
ln -s $S/wsdeps/node_modules $SIM/node_modules_dev
L=$SIM/template/.forge/scripts/lib
prod() { case $1 in
  1) cp $I/kb-corpus.mjs $L/ ;;
  2) cp $I/kb-lexical.mjs $L/ ;;
  3) cp $I/kb-fuse.mjs $L/ ;;
  4) cp $I/kb.sh $SIM/template/.forge/scripts/; cp $I/kb-cli.t04.mjs $L/kb-cli.mjs ;;
  5) cp $I/kb-cli.mjs $L/kb-cli.mjs ;;
  6) cp -R $I/kb-pins $L/kb-pins; cp $S/wsdeps/package.json $SIM/package.json; rm -f $SIM/node_modules; ln -s $S/wsdeps/node_modules $SIM/node_modules ;;
  7) cp $I/kb-integrity.mjs $I/kb-install.mjs $L/ ;;
  8) cp $I/kb-semantic.mjs $L/ ;;
esac; }
tests() { case $1 in
  1) cp $TS/w284-kb-corpus-gate.sh $SIM/tests/ ;;
  2) cp $TS/w285-kb-lexical-gate.sh $SIM/tests/ ;;
  3) cp $TS/w286-kb-fuse-gate.sh $SIM/tests/ ;;
  4) cp $TS/w287-kb-cli-gate.sh $SIM/tests/ ;;
  5) cp $TS/w289-kb-eval-gate.sh $TS/w288-kb-offline-lexical-gate.sh $SIM/tests/; cp $TS/fixtures/kb/{semantic-env.sh,serve.mjs,no-network.cjs,net-canary.mjs,fake-git.sh} $SIM/tests/fixtures/kb/; cp $W/.forge/specs/active/add-unified-knowledge-search/evidence/prototype/queries.json $SIM/tests/fixtures/kb/eval/calibration.json; cp $W/.forge/specs/active/add-unified-knowledge-search/evidence/prototype/holdout.json $SIM/tests/fixtures/kb/eval/holdout.json ;;
  6) cp $TS/w290-kb-pins-gate.sh $SIM/tests/ ;;
  7) cp $TS/w291-kb-install-gate.sh $SIM/tests/; cp $TS/fixtures/kb/{make-semantic-fixture.mjs,fake-npm.sh,semantic-env.sh} $SIM/tests/fixtures/kb/ ;;
  8) cp $TS/w292-kb-semantic-gate.sh $TS/w293-kb-offline-semantic-gate.sh $SIM/tests/ ;;
esac; }
cmd() { case $1 in
  1) echo "bash tests/w284-kb-corpus-gate.sh";; 2) echo "bash tests/w285-kb-lexical-gate.sh";; 3) echo "bash tests/w286-kb-fuse-gate.sh";;
  4) echo "bash tests/w287-kb-cli-gate.sh";; 5) echo "bash tests/w289-kb-eval-gate.sh && bash tests/w288-kb-offline-lexical-gate.sh";;
  6) echo "bash tests/w290-kb-pins-gate.sh";; 7) echo "bash tests/w291-kb-install-gate.sh";; 8) echo "bash tests/w292-kb-semantic-gate.sh && bash tests/w293-kb-offline-semantic-gate.sh";;
esac; }
for n in 1 2 3 4 5 6 7 8; do
  tests $n
  out="$(cd $SIM && bash -c "$(cmd $n)" 2>&1)"; rc=$?
  red_ok=no; [ $rc -ne 0 ] && grep -qE '^FAIL \[[^]]+\]' <<<"$out" && red_ok=yes
  prod $n
  out2="$(cd $SIM && bash -c "$(cmd $n)" 2>&1)"; rc2=$?
  echo "TASK-0$n red: rc=$rc fail_line=$red_ok ($(grep -m1 -E '^FAIL' <<<"$out" | cut -c1-90)) | green: rc=$rc2 $(tail -1 <<<"$out2" | cut -c1-80)"
done
