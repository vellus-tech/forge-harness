# Despacho de subagentes (simulado — não executado)

Regra do run: subagentes não podem ser spawnados neste caso de eval (baseline `without_skill`, sandbox de revisão). Nenhum artefato lido nesta tarefa (execução por conhecimento próprio, sem SKILL.md nem agent-definition) instruiu spawn de subagente — o TRD foi produzido diretamente pelo executor, sem necessidade de dispatch. Registro abaixo é apenas para conformidade com a regra do prompt: se houvesse necessidade, este seria o despacho que faria.

| Agente (hipotético) | Modelo | Prompt resumido |
|---|---|---|
| (nenhum necessário) | — | A tarefa (gerar um único documento TRD a partir de 6 artefatos pequenos, ~125 linhas no total) coube inteiramente ao executor principal; não haveria ganho de paralelismo em delegar subseções a subagentes separados, dado o tamanho do insumo e a necessidade de uma síntese coerente única entre arquitetura, APIs, eventos, dados, segurança e observabilidade. |
