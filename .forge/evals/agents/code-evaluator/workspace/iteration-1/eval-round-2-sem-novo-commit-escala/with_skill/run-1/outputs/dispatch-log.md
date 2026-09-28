## Despacho de subagentes que o protocolo do code-evaluator pediria

Ambiente sandboxed do eval: nada foi spawnado de verdade (regra do harness). Este arquivo registra o que
seria despachado via Agent tool, e por que, neste round.

### Decisão tomada: não despachar reviewers nesta rodada

Antes da Fase 2 (fan-out para os 5 reviewers transversais + reviewers de stack), o `code-evaluator` aplica o
gate de anti-loop por fingerprint (Fase 4.1 do protocolo, e o anti-padrão explícito "Re-rodar reviewers se
`diff_sha` não mudou entre rounds"). `git rev-parse HEAD` no round 2 é idêntico ao `final_diff_sha` do
round 1 (`be83a6292054b8a5f4459f65cd55c2c269bb1d9e`), então o diff sob revisão é byte-a-byte o mesmo já
revisado. Rodar os cinco reviewers de novo sobre o mesmo diff gastaria tokens sem produzir sinal novo — o
protocolo trata isso como loop infinito e escalona direto para veredito REJECTED (LOOP-001), pulando a
Fase 2.

Portanto, o único "despacho" real desta rodada é a decisão negativa: não invocar
`logic-reviewer`/`arch-reviewer`/`security-reviewer`/`platform-reviewer`/`quality-reviewer`/`python-reviewer`.

### Para referência — despacho que teria ocorrido se o diff tivesse mudado de fato

Se o `fullstack-software-engineer` tivesse de fato commitado e dado push na correção, o round 2 despacharia
em paralelo, numa única mensagem com múltiplas chamadas de Agent tool:

| # | Agente | Modelo | Prompt resumido |
|---|--------|--------|------------------|
| 1 | logic-reviewer | Opus | Revisar invariantes/edge cases de `registrar_recarga` no diff `be83a62`, contexto: FRD/NFRD de tarifa, foco em correção lógica pós-fix de SEC-001. |
| 2 | arch-reviewer | Sonnet | Checar aderência a Clean Arch/DDD do módulo `services/tarifa`, fronteiras do pacote `tarifa`. |
| 3 | security-reviewer | Opus | Reverificar SEC-001 (PAN completo em log, PCI DSS 3.4) no arquivo `services/tarifa/tarifa/recarga.py:10` após a alegada correção; confirmar se `numero_cartao[-4:]` ou token substituiu o valor completo. |
| 4 | platform-reviewer | Sonnet | Sem sinais de Docker/K8s/OTel no diff — aplicar apenas checagem padrão de NFRD, sem achados esperados. |
| 5 | quality-reviewer | Haiku | Conferir QUA-001 (cobertura de valor negativo em `test_recarga.py`) e convenções gerais. |
| 6 | python-reviewer | (reviewer de stack, `.py` no diff) | Revisão específica de Python: tipagem, `unittest`, idiomas do runtime declarado em `.forge/FORGE.md` (`test: cd services/tarifa && python3 -m unittest discover -s tests -t .`). |

Nenhuma dessas chamadas foi feita nesta rodada porque o gate de anti-loop intercepta antes da Fase 2.

### Sobre a alegação de correção do `fullstack-software-engineer`

Também não foi despachado nenhum novo round do `fullstack-software-engineer` (Fase 4.2) — o protocolo determina
`fse_dispatch: null` quando o veredito escalona para REJECTED por anti-loop; a escalação é para revisão humana,
não para mais uma tentativa automática do FSE sobre o mesmo diff.
