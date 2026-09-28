# Análise pós-hoc — eval A/B da skill `release-notes-ptbr` (iteração 1)

## O que a média está escondendo

O agregado (`aggregate.json`) mostra pass-rate 0.4167 → 0.6667 (delta +0.25) e parece um ganho líquido consistente. Ele não é. Decompondo por caso (`eval-1/2/3/grading.json`), o delta por caso é +0.5, **-0.25**, +0.5. A skill não melhorou uniformemente: ela ajudou em dois casos e **regrediu** em um terceiro (TC-02), e a média de três pontos com essa variância (stddev do baseline 0.2357, do variant 0.1179) simplesmente absorve a regressão dentro do ganho dos outros dois — o "+0.25" médio nunca acontece em nenhum caso individual.

### Achado 1 — Regressão real em TC-02, não ruído
TC-02 ("notas de versão do validador v1.8.2 (hotfix) com base no diff entre as tags v1.8.1 e v1.8.2") caiu de pass-rate 0.75 (baseline) para 0.5 (variant). A causa apontada na evidência: o baseline citava corretamente "(#377)"; com a skill, o modelo citou apenas "(hotfix)", sem o número do PR. A entrada desse caso não é uma lista de PRs enumerados (como TC-01/TC-03), e sim um diff entre duas tags — a skill (`tools/claude-skills/release-notes-ptbr/SKILL.md`) só instrui "1. Liste os PRs do intervalo" e "3. Cite o número de cada PR entre parênteses", sem dizer como extrair o número do PR quando a entrada é um diff de tags em vez de um range de PRs. Isso não é uma falha aleatória do modelo — é uma lacuna de cobertura no protocolo da skill para um formato de entrada que o eval set já inclui.

### Achado 2 — Um requisito nunca passa, com ou sem skill
A expectativa "Separa breaking changes em uma seção própria 'Mudanças incompatíveis'" falha nos três casos, tanto no baseline quanto no variant (0/3 em ambas as condições). A skill não tem nenhuma instrução sobre identificar ou isolar breaking changes — os três passos do `SKILL.md` cobrem apenas listagem, agrupamento em Novidades/Correções/Interno e citação de número de PR. Esse é o maior ponto cego do conjunto, e ele é estrutural, não estatístico: nenhuma quantidade de reamostragem vai corrigi-lo, porque a skill não pede esse comportamento. É também o requisito de maior risco operacional no domínio (TC-03 é explicitamente "mandar aos operadores amanhã"; TC-02 é um hotfix que muda código de erro 422→409 sem sinalização).

### Achado 3 — Custo subiu mais que a média sugere, para um ganho desigual
Duração média subiu de 31.0s para 49.7s (+60%) e tokens de 8000 para 13200 (+65%), para um ganho de pass-rate que só é positivo em 2 dos 3 casos e negativo em 1. Isso muda o cálculo de custo-benefício: não é "mais qualidade por um pouco mais de custo", é "mais custo, com risco real de piora em subconjuntos de entrada não cobertos pela skill".

## O que fazer em seguida

1. **Não promover a skill nesta forma.** A regressão em TC-02 é reproduzível a partir da evidência registrada, não é ruído de amostra pequena — é uma lacuna identificável no texto da skill.
2. **Corrigir o `SKILL.md`** em dois pontos antes da próxima iteração:
   - instrução explícita para o caso "entrada é diff entre tags, sem lista de PRs numerados" — como localizar o número do PR associado a cada commit/merge nesse formato;
   - um passo novo cobrindo identificação de mudanças incompatíveis (remoção/renomeação de campo, mudança de contrato de erro, mudança de protocolo) e isolamento em seção própria "Mudanças incompatíveis".
3. **Rodar uma nova iteração (N maior que 3)** depois da correção, focada nesses dois pontos, antes de decidir promoção — 3 casos por braço é amostra pequena para a variância já observada (stddev do variant 0.1179 num intervalo de 0 a 1).
4. **Reavaliar o trade-off de custo** (tempo/tokens) só depois de fechar os dois gaps acima — hoje o aumento de custo está pagando por um ganho que não existe uniformemente.

## Metodologia desta análise
Lidos apenas os arquivos de entrada fornecidos (`aggregate.json`, os três `grading.json`) e o `SKILL.md` da skill sob avaliação (`tools/claude-skills/release-notes-ptbr/SKILL.md`), presente no fixture como o artefato do usuário, não do harness de eval. Nenhum artefato de protocolo de eval do harness (`.forge/evals/**` fora do fixture, `template/.forge/skills`, `template/.forge/agents`, `plugin`) foi lido, conforme escopo do caso `without_skill`.
