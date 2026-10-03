# Despacho de Subagentes (simulado)

O artefato `template/.forge/agents/architecture/module-generator.md` não instrui o Module Generator a spawnar subagentes — ele é um agente de execução direta (Read/Write/Edit/Glob/Grep), sem orquestração de outros agentes em seu processo. Por isso, nenhum despacho real ou simulado foi necessário para cumprir o `SKILL.md`/definição do agente nesta execução.

Registro exigido pelas regras do run mesmo assim, para deixar explícito o raciocínio: se este agente tivesse mandato para delegar (por exemplo, um passo de validação cruzada dos READMEs gerados), o despacho que seria feito é:

| Agente | Modelo | Prompt resumido |
|---|---|---|
| module-generator-reviewer (hipotético, não existe como agente formal no harness) | sonnet | "Revise os READMEs de módulo e os diagramas gerados em docs/product/modules/ contra ddd-segmentation.md, frd.md e nfrd.md: confira se nenhum módulo foi criado sem evidência, se o tipo de notificacao-motoristas permanece 'Ponto a Validar' (não decidido), se PCI DSS foi corretamente marcado como não aplicável e se LGPD cobre CPF/CNH/telefone." |

Nenhum subagente foi de fato spawnado, conforme a regra do run.
