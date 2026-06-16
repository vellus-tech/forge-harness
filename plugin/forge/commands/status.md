---
description: Mostra o estado do harness Forge - specs ativas, baseline, graph e adapters - em formato curto. Use para retomar contexto no inicio de uma sessao ou conferir onde o projeto esta.
---

# /forge:status

Responda em poucas linhas, lendo APENAS arquivos de estado (nunca releia artefatos inteiros):

1. **Harness:** `.forge/forge.yaml` existe? `template_version`, adapters instalados, e resultado-resumo do último doctor se disponível.
2. **Specs ativas:** liste `.forge/specs/active/*/` (id + `status` do `manifest.yaml` de cada uma). Se o diretório não existe ainda, diga "nenhuma spec ativa (lifecycle chega no MVP2)".
3. **Baseline:** `.forge/product/current/capabilities/` — quantidade de capabilities (ou "baseline ainda não criado — MVP3").
4. **Graph:** `.forge/graph/graph.json` presente? staleness se o manifest indicar (ou "graph ainda não construído — MVP4").
5. **Próximo passo lógico:** uma linha objetiva.

Formato de saída: bloco curto estilo `/forge:progress` (§17.3) — sem dumps de JSON, sem tabelas longas.
