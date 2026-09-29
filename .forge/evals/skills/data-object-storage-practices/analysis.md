# Análise do benchmark — data-object-storage-practices

Fonte determinística: `workspace/iteration-1/benchmark.json` (gerado por `aggregate_benchmark.py`, 3 evals, 1 run gravado por eval/configuração neste iteration-1 — `runs_per_configuration: 3` no metadata é nominal).

## 1. Resultado

| Métrica | Com skill | Sem skill | Delta |
|---|---|---|---|
| Pass rate | 93,3% (média 0,9333; eval 1 0,80, eval 2 1,00, eval 3 1,00) | 23,3% (média 0,2333; eval 1 0,20, eval 2 0,25, eval 3 0,25) | **+0,70** |
| Tempo | 159,3s ± 50,0s | 119,3s ± 54,6s | +40,0s |

`benchmark_ok = true` (agregação rodou sem correção de estrutura). Delta ≥ 0,15 → **veredito: agrega**, com folga grande — o padrão é consistente nos três evals, não puxado por um outlier.

## 2. Asserções que não discriminam

- **"Nenhum arquivo/mensagem contém AKIA.../X-Amz-Signature"** (eval 3): passa em `with_skill` e `without_skill`. É higiene de segredo que nenhuma das duas condições viola — não mede o valor da skill. Candidata a sair do benchmark A/B ou virar guardrail geral do harness.
- **"chave por lote/período OU registra CDE no escopo"** (eval 2, assertion 4): passa nas duas configurações, mas por caminhos diferentes — com skill, o agente projeta chave por lote explicitamente (desenho completo); sem skill, só cita "entra no escopo do CDE" de passagem, sem crypto-shredding. A disjunção `OR` deixa a asserção fraca: aprova a resposta parcial do mesmo jeito que a completa.

Nenhuma asserção falha nas duas configurações (sem sinal de teste quebrado ou além da capacidade do modelo).

## 3. Onde o artefato ajudou

- **Recusa de acesso de terceiro a bucket interno (eval 3).** Sem a skill, o executor aceitou a bucket policy cross-account (opção 2 do pedido) e não propôs alternativa REST. Com a skill, a seção "Entrega a terceiro" do SKILL.md (decisão H-02 (a) citada nominalmente) levou à recusa das três opções e à proposta do endpoint REST autenticado com expiração em minutos, objeto único e log de emissão.
- **Recusa de WORM compliance de 5 anos indiscriminado (eval 2).** Sem a skill, o executor implementou literalmente o pedido (Object Lock COMPLIANCE 5 anos no bucket inteiro) e justificou com "foi o que foi pedido explicitamente". Com a skill, a frase "WORM compliance só com obrigação legal registrada e conciliação LGPD" (Protocolo, item 5) foi citada quase ao pé da letra no `design-bronze.md` produzido, e o Object Lock ficou isolado num bucket dedicado com `days = 548` em vez de 5 anos.
- **PCI DSS sobre SSE-KMS (eval 2).** Sem a skill, o executor aceitou "SSE-KMS já resolve PCI" e desviou para IAM/MFA/logging. Com a skill, o catálogo (T-03, referência a PCI DSS 3.5.1.2) foi citado por número de requisito e a criptografia em nível de arquivo/campo com chave fora do lake foi prescrita.
- **Ids do catálogo com arquivo:linha (eval 1).** A exigência do Protocolo ("todo antipattern apontado cita o id... e arquivo:linha") produziu, com a skill, um relatório com O-01/O-02/O-13/O-14 citados por id e linha exata; sem a skill, o relatório de 9 achados livres não cita nenhum id do catálogo.

## 4. Onde o artefato atrapalhou ou ficou aquém

- **Única falha com skill (eval 1, assertion 5): "uma entrada por regra, inclusive as limpas".** A tabela-resumo do `with_skill/run-1` lista 9 das 15 regras do catálogo (O-01, O-02, O-03, O-04, O-08, O-11, O-13, O-14, T-03); faltam O-05, O-06, O-07, O-09, O-10 e O-12 como linha própria com status explícito — O-12 (small files) só aparece como "consequência colateral" dentro do item 4, sem entrada dedicada. O Protocolo pede "uma linha por regra, inclusive as limpas" mas não lista as 15 regras em lugar nenhum do SKILL.md nem instrui o agente a enumerar o catálogo inteiro antes de montar a tabela — o agente monta a tabela a partir do que achou relevante mencionar no corpo do relatório, não a partir de uma lista canônica a cobrir. É lacuna de instrução, não erro de julgamento: o conteúdo de cada regra tratada está correto, só a cobertura da tabela é parcial.
- **Custo de tempo não desproporcional, mas não gratuito.** +40s médios (159,3s vs 119,3s) é esperado dado o protocolo de 5 passos (scan.sh + check-data-governance.sh + leitura de rules), não é sinal de ineficiência, mas vale registrar que a skill não é "grátis" em latência.

## 5. Trechos ignorados, ambíguos ou contraditórios

- **Ambíguo: "inclusive as limpas" sem lista canônica de regras.** Ver item 4 — a instrução existe mas não é operacionalizável sem que o agente já tenha internalizado (ou releia) o índice completo de `references/antipatterns.md` no momento de montar a tabela final.
- **Nenhum trecho do SKILL.md foi contraditado pelos runs.** As três frases mais citadas literalmente pelos transcripts (H-02 (a) na seção "Entrega a terceiro", a frase de WORM compliance no Protocolo item 5, e a referência a PCI DSS 3.5.1.2 no catálogo) foram aplicadas sem distorção nos três `with_skill` runs.
- **`scripts/scan.sh` documentado como detectando "O-01, O-02, O-08, O-11, O-13 e O-14"** (linha final do SKILL.md) — de fato só 6 das 15 regras têm detector estático, e a seção "O que o scanner não faz" já avisa disso; o run do eval 1 respeitou essa fronteira (declarou O-03/O-04/T-03 como "sem detector estático — revisão"). O problema remanescente (item 4) é a ausência de uma lista das regras sem detector que ainda assim precisam de entrada na tabela.

## 6. Melhorias concretas, priorizadas

1. **[Alta] Tornar "uma linha por regra, inclusive as limpas" operacionalizável.** Adicionar ao Protocolo (passo 5) ou a uma seção nova em `references/antipatterns.md` a lista compacta dos 15 ids (`O-01..O-14, T-03`) para o agente copiar como esqueleto da tabela-resumo antes de preenchê-la — elimina a omissão observada (6 de 15 regras sem entrada) sem exigir julgamento adicional, só disciplina de cobertura.
2. **[Média] Separar a asserção disjuntiva do eval 2 (chave por lote OU escopo CDE) em duas.** Mudança no benchmark (`evals.json`), não na skill, mas ligada à mensurabilidade do artefato: hoje essa asserção não distingue a resposta completa (chave por lote + crypto-shredding) da resposta parcial (só menção ao CDE).
3. **[Baixa] Remover ou realocar a asserção de "nenhum segredo literal" do eval 3.** Não discrimina a skill (passa em ambas as condições); se o objetivo é guardrail de segurança geral do executor, pertence a uma suíte de segurança do harness, não ao benchmark A/B desta skill específica.
4. **[Baixa, informativo] Nenhuma ação necessária em `references/best-practices.md` ou na seção "Entrega a terceiro".** Ambas foram citadas e aplicadas corretamente nos três runs com skill; sem evidência de ambiguidade ou lacuna de conteúdo ali.
