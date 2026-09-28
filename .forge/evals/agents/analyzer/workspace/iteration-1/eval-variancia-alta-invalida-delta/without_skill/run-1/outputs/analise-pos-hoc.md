# Análise pós-hoc — skill `revisa-migracao-postgres`, iteração 2

## Pedido

Validar se o delta de pass-rate de **+0.25** reportado no `aggregate.json` da iteração 2 é base sólida para aprovar a skill hoje, a partir de `aggregate.json` e dos quatro `grading.json` (eval-1 a eval-4).

## Resumo executivo

O número **+0.25** é aritmeticamente correto, mas não é uma base confiável para aprovação hoje. Com apenas 4 casos de teste, o desvio-padrão do pass-rate do variant (0.4463) é **maior** que o próprio delta médio (0.25) — ou seja, o ruído entre casos é maior que o sinal medido. Um teste pareado simples (t de Student, n=4) não atinge significância estatística convencional. Além disso, metade dos casos (2 de 4) não mostra nenhum ganho, e um deles (TC-03) tem saída **idêntica** entre baseline e variant, o que sugere que a skill pode nem ter sido efetivamente acionada nesse caso — um sinal de possível problema na execução do eval, não de mérito da skill.

## O que os dados mostram, caso a caso

| Caso | Δ pass-rate | Observação |
|---|---|---|
| TC-01 | +0.50 | Baseline 2/4 expectativas; variant 4/4. Ganho real e específico (exige down, estima bloqueio). |
| TC-02 | +0.50 | Mesmo padrão de TC-01: variant cobre reversibilidade e estimativa de lock que o baseline não cobre. |
| TC-03 | 0.00 | **Baseline e variant com a mesma saída, palavra por palavra** ("a migração parece correta... horário de baixo tráfego"). Nenhuma das 4 expectativas passa em nenhum dos dois. Isso não é "a skill não ajudou neste caso" — é "não há diferença observável entre rodar com e sem a skill", o que é atípico e merece investigação antes de contar como evidência a favor ou contra. |
| TC-04 | 0.00 | Baseline e variant empatam em 1/4 expectativas (só o lock de reescrita de tabela). A skill não acrescentou nada aqui e ainda consumiu mais tokens/tempo. |

Conclusão direta: o ganho de +0.25 vem inteiramente de 2 dos 4 casos (TC-01 e TC-02). Nos outros dois, não há ganho — e num deles a saída é suspeitosamente idêntica.

## Variância e significância

- `pass_rate_stddev` do baseline: 0.2073; do variant: 0.4463. Ambos são grandes relativos ao delta de 0.25.
- Desvio-padrão dos deltas por caso ([0.5, 0.5, 0, 0]): populacional ≈ 0.25, amostral ≈ 0.289.
- Erro-padrão da média (n=4): ≈ 0.125 a 0.144, dependendo da convenção.
- Estatística t aproximada (delta médio / erro-padrão): **t ≈ 1.7–2.0**.
- Para n=4 (3 graus de liberdade), o valor crítico de t a 95% (bicaudal) é ≈ 3.18. **t observado fica abaixo do limiar** — a diferença não é estatisticamente significativa com esses dados.

Em outras palavras: com uma amostra dessa variância e desse tamanho, um delta de +0.25 é compatível com ruído — não dá para distinguir "a skill funciona" de "esses 4 casos por acaso saíram assim".

## Custo adicional não compensado

Em todos os 4 casos o variant consumiu mais tokens (delta médio +1025) e mais tempo (delta médio +4600 ms) que o baseline — inclusive nos dois casos (TC-03, TC-04) em que não houve ganho de qualidade. Ou seja, parte do "custo" pago pela skill não teve retorno mensurável nesta amostra.

## Recomendação

Não aprovar hoje com base apenas nesse número. Antes da reunião:

1. Investigar TC-03: por que baseline e variant produziram a mesma saída? Verificar se a skill foi de fato acionada nesse caso (bug no runner do eval, prompt que não dispara a skill, cache, etc.) antes de usar esse resultado como evidência de qualquer lado.
2. Aumentar n: 4 casos é pequeno demais para uma decisão de aprovação; considerar rodar mais iterações/casos antes de fechar o número.
3. Se a decisão precisar ser tomada hoje mesmo assim, apresentar o delta com a variância ao lado (não só a média) e deixar explícito que o resultado não é estatisticamente significativo com a amostra atual — é indício, não prova.

## Nota metodológica

Esta análise foi feita com conhecimento geral de estatística (média, desvio-padrão populacional vs. amostral, erro-padrão, teste t pareado aproximado) e leitura direta dos arquivos de entrada, sem uso de nenhuma skill, agente ou ferramenta especializada do harness — conforme o desenho do caso de eval (`without_skill`).
