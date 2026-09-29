# Parecer de validação — Tarifação (Req 1 a 20)

**Documento avaliado:** `docs/product/modules/tarifacao/requirements.md`, versão 0.4.0, 2448 linhas, 170 requisitos funcionais.
**Escopo desta revisão:** Req 1 a Req 20, conforme solicitado, com leitura de amostragem do restante do arquivo (RNF, PBT, seções finais) para checar consistência global.

## Veredito

Não aprovo para seguir direto ao design nesta forma. A regra de negócio em si está clara e é implementável, mas há uma inconsistência real entre um critério de aceite e a propriedade que deveria formalizá-lo, uma lacuna de cobertura (a persona "Gestor de tarifas da operadora" não tem nenhum requisito que a exercite dentro do range revisado) e três ambiguidades de borda que, se forem para o design como estão, viram decisão de implementação não rastreável a um requisito. Nenhum desses pontos exige reescrever o catálogo de 170 linhas nem contraria a premissa de que o módulo não deve ser quebrado — são ajustes textuais localizados.

## Achados (Req 1–20)

1. **Inconsistência entre Req 1.2 e PBT-01 (bloqueante).** O critério 1.2 (repetido em todos os Req 1–20) diz que o segundo embarque em até 90 minutos "não é cobrado" — valor esperado é zero. Já a PBT-01, que declara mapear para Req 1.2, formaliza uma propriedade mais fraca: "o valor cobrado no segundo embarque é menor ou igual à tarifa cheia da linha", o que aceitaria qualquer cobrança parcial entre 0 e a tarifa cheia. Se a intenção é gratuidade total na integração, a propriedade deveria ser `valor_segundo_embarque == 0`, não `<= tarifa_cheia`. Isso precisa ser corrigido antes do design, porque um teste baseado em propriedade escrito como está passaria mesmo com uma implementação que cobra metade da tarifa — o que contradiz o texto do requisito.

2. **Persona sem requisito correspondente no range revisado.** A seção Personas lista "Gestor de tarifas da operadora — Cadastra e reajusta tarifas das linhas da própria operadora", e o RNF-02 exige que todo reajuste gere registro de auditoria. Mas nenhum dos Req 1–20 descreve o fluxo de cadastro/reajuste — todos são exclusivamente a perspectiva do passageiro pagando a tarifa vigente. Ou existe um requisito de cadastro/reajuste mais adiante no documento fora do range pedido (não descarto, não verifiquei os 170 à exaustão) e falta uma referência cruzada nos Req 1–20, ou o fluxo de escrita da tarifa simplesmente não está especificado — nesse caso o RNF-02 fica sem requisito funcional que o sustente.

3. **Borda dos 90 minutos não especificada.** "Em até 90 minutos" não deixa claro se o minuto 90 exato ainda conta como integração gratuita ou já é nova cobrança (inclusive vs. exclusive). Pequeno, mas é exatamente o tipo de ambiguidade que gera interpretações divergentes entre quem desenha e quem implementa.

4. **Borda da faixa noturna não especificada.** "23h às 5h" não define se 23:00:00 e 05:00:00 em ponto pertencem à faixa noturna ou à diurna, nem qual fuso horário rege (o módulo atende três operadoras — presumo mesmo fuso, mas isso deveria estar dito, não presumido).

5. **Uniformidade de valores entre operadoras distintas, sem explicação.** Os Req 1–20 citam origens diferentes — "Tabela tarifária Viação Leste 2026", "TransNorte 2026", "Expresso Sul 2026" — mas todos os 20 (e, por amostragem, todos os 170) resolvem para exatamente os mesmos valores: 440 centavos base, 490 na faixa noturna. Pode ser um dado real (tarifa unificada por acordo do consórcio) ou pode ser um valor placeholder que não foi de fato extraído de cada tabela de origem antes de o documento ser fechado. O texto não diz qual dos dois é o caso, e a diferença importa: se for tarifa unificada, isso deveria estar dito uma vez na Visão Geral e o catálogo poderia citar a fonte sem repetir a explicação 170 vezes; se for placeholder, o catálogo não está pronto para aprovação.

## Observação sobre a forma do documento (não bloqueante)

O documento tem 2448 linhas porque cada uma das 170 linhas do consórcio vira um bloco de requisito completo (User Story + tabela de metadados + 2 critérios de aceite), sendo que a única coisa que varia entre eles é o número da linha e, ciclicamente, a operadora. Não estou pedindo para quebrar o módulo — a premissa de que é uma regra de negócio única está correta e a revisão foi possível dentro do range pedido sem dificuldade. Mas o formato atual mistura duas coisas que deveriam ser separadas: a regra de negócio (que é uma só, e caberia num único requisito parametrizado) e o dado de catálogo (a lista de 170 linhas com seus valores), que é melhor representado como tabela/anexo de referência do que como 170 User Stories idênticas. Isso não muda o veredito de aprovação, mas vale registrar porque o formato atual torna inconsistências como o item 1 acima mais fáceis de passar despercebidas — uma alteração feita no Req 87, por exemplo, não teria motivo óbvio para propagar visualmente para os outros 169 blocos.

## Recomendação

Aprovação condicional: siga para o design apenas depois de (a) resolver a divergência entre Req 1.2 e PBT-01, e (b) confirmar se falta ou não um requisito de cadastro/reajuste de tarifa pela operadora. Os itens 3, 4 e 5 podem ser resolvidos com uma frase cada, direto no requisito ou na Visão Geral, sem nova rodada completa de revisão.

## Limitação desta revisão

Por instrução da tarefa, este parecer cobre Req 1 a 20 em profundidade; a checagem de uniformidade de valores (achado 5) e a busca por requisito de cadastro/reajuste (achado 2) usaram uma varredura por padrão (`grep`) no arquivo inteiro como amostragem de apoio, não uma leitura linha a linha dos 170 requisitos — se houver um Req fora do range 1–20 que já cobre o cadastro/reajuste, ou que rompe o padrão de valores, este parecer não capturaria.
