# Resposta ao usuário — impact-scan do change 2026-09-webhook-adquirente

Não dá para gerar a análise de impacto agora: o grafo de código deste projeto (`.forge/graph/graph.json`) não existe — nunca foi construído, ou foi removido. A skill `impact-scan` consome o grafo, não o reconstrói, então rodar o scan neste estado ou fabricaria um `impact.json` sem base real, ou falharia silenciosamente — nenhuma das duas serve para anexar ao PR.

## O que falta antes do scan

1. Rode `/forge:codegraph` na raiz do projeto para construir `.forge/graph/graph.json` (determinístico, sem custo de LLM — nodes de arquivo/camada + edges de import).
2. Depois disso, rode o impact-scan de fato:
   ```
   node .forge/scripts/lib/impact-scan.mjs \
     --change 2026-09-webhook-adquirente \
     --graph .forge/graph/graph.json \
     --files "src/webhooks/"
   ```
   Isso grava `.forge/specs/active/2026-09-webhook-adquirente/impact.json` com `affected_files`, `graph_fingerprint` e `summary` — é esse arquivo que deve ir para o PR, não uma estimativa manual minha.

## O que dá para adiantar, sem o grafo

Fiz uma varredura textual (grep) em `src/`, só para você ter uma ideia enquanto o grafo não sobe — isto **não substitui** o impact-scan real e não deve ir para o PR como análise de impacto formal:

- `src/webhooks/signature.ts` exporta `verifySignature`, usado por `src/webhooks/acquirer.ts`.
- Import direto de `src/webhooks/` encontrado em:
  - `src/settlement/reconcile.ts`
  - `src/api/routes/webhooks.ts`

Isso já sinaliza que o alcance mínimo passa por liquidação (`settlement`) e pela rota HTTP de webhooks — mas grep não pega reachability transitiva (quem importa quem importa `settlement`, por exemplo), que é exatamente o que o impact-scan real resolve. Como o change é scale 3 e mexe em assinatura HMAC (superfície de segurança), recomendo não anexar nada ao PR como "impact scan" até rodar `/forge:codegraph` + o scan de verdade — mesmo com o prazo de hoje.
