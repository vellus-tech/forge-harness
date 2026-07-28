---
title: Red-first em correção de defeito
applies_to:
  - all
priority: high
last_reviewed: 2026-07-28
based_on: []
---

# Red-first em correção de defeito

O ciclo é o mesmo do desenvolvimento de feature — Red, Green, Refactor — mas a consequência de pular o Red é outra. Em código novo, escrever o teste depois custa design pior: a API não foi pressionada por nenhum consumidor antes de existir. Em correção de defeito, custa algo mais grave — a garantia de que o teste testa o que se pensa que ele testa. Um teste de regressão que nunca foi visto vermelho pode estar passando pelo motivo errado: mock complacente, asserção fraca demais para distinguir o certo do errado, ou um caminho de código que simplesmente não é o do defeito. O teste entra na suíte, fica verde para sempre, e a regressão que ele deveria guardar volta sem que ninguém perceba.

## Itens normativos

1. **O Red vem antes da correção e reproduz o defeito relatado — não uma aproximação dele.** O teste falha por comportamento: valor errado, exceção indevida, efeito colateral ausente. Nunca por erro de compilação, import quebrado ou fixture inexistente. Falha de build na árvore pré-correção não é Red; é ruído disfarçado de evidência, e passa a mesma sensação de rigor sem nenhuma das garantias.

2. **O teste é escrito no nível em que o defeito se manifesta.** Se o defeito atravessa camadas, serviços ou bounded contexts, o teste atravessa também. Cobrir apenas a unidade corrigida prova que a unidade mudou de comportamento — não prova que o defeito sumiu do caminho onde o usuário o encontrou.

3. **O Red precisa ser observado, não presumido.** Rode o teste na árvore pré-correção, veja-o falhar e confira que a mensagem de falha corresponde ao defeito descrito. Suíte verde em cada componente isolado não é evidência sobre a cadeia que os liga — e é exatamente na cadeia que defeitos de integração se escondem.

4. **O teste permanece na suíte depois do Green**, nomeado de forma que o próximo leitor entenda qual defeito ele guarda. Um teste de regressão anônimo é candidato natural a ser apagado no próximo refactor por parecer redundante.

## Verificação

O item 3 não é auto-declarado. A observação do Red é registrada com `/forge:red record`, que grava `evidence/red/*.json` no change: qual teste, com qual comando, sobre qual commit base, qual padrão de falha se espera, mais o trecho e o hash sha256 da saída observada. Depois, `bash .forge/scripts/red-evidence.sh replay <change-id>` reconstrói a árvore pré-correção, roda aquele teste e exige o resultado declarado — falha na base, classificada como comportamental e casando com o padrão registrado, além de passagem em HEAD. Evidência declarada e nunca replicada não vale como evidência.

**Bloqueiam** (condições não rebaixáveis por modo de operação, nem em `yolo`):

- ausência de evidência de Red num change com `type: bugfix`;
- teste que já passava na base — não reproduz nada;
- falha na base classificada como erro de build, e não como comportamento;
- saída da falha que não casa com o padrão declarado.

**Avisam** (sinal de qualidade, não veto):

- teste que não alcança, no grafo de código, nenhum dos arquivos corrigidos. É um proxy imperfeito do item 2: a alcançabilidade estática não enxerga injeção de dependência, reflexão, e2e sobre processo HTTP nem message bus, então a ausência de interseção sugere revisão, não condena o teste;
- teste e correção no mesmo commit, o que impede separar temporalmente o Red do Green;
- nome de teste sem referência ao defeito;
- mock de símbolo exportado por um dos arquivos corrigidos — o caminho clássico do teste que passa pelo motivo errado.

Permanece um resíduo honor-system que nenhum script fecha: que o motivo da falha seja **semanticamente** o defeito relatado, e não uma quebra adjacente que por acaso casa com o padrão declarado. O replay prova que houve falha comportamental reprodutível e específica; não prova intenção. Essa parte continua sendo responsabilidade de quem escreve e de quem revisa.

## Quando o Red não é possível

Há casos legítimos. Registre-os com `/forge:red waive --reason <motivo>` em vez de fabricar um teste para cumprir tabela — um teste inventado para satisfazer o gate é pior que a ausência declarada, porque mente para o próximo leitor.

| Motivo | Quando se aplica | Efeito |
|---|---|---|
| `non-behavioral` | Typo, copy, configuração, documentação — nada que mude comportamento executável | Recusado automaticamente se o diff tocar código presente no grafo |
| `no-test-infra` | Brownfield sem suíte de testes utilizável | Abre deferral e registra dívida técnica no ledger |
| `external-unreproducible` | Depende de terceiro indisponível para reprodução local | Abre deferral |
| `hotfix-under-incident` | Incidente em produção, correção antes do teste | Deferral com `blocks: [archive]` — o archive fica travado até o teste chegar |

## Referências

- [TDD — ciclo Red-Green-Refactor](./tdd.md)
- [Contrato mínimo de testes por mudança](./change-test-contract.md)
- [Quality Gates e Níveis de Teste](./quality-gates.md)

A decisão está registrada no ADR `0003-red-first-regression-evidence` do repositório forge-harness. Como toda rule do template, esta nasce com `based_on: []` (guardrail G3 — o template não traz ADRs); o projeto adotante que queira ancorá-la formalmente cria o ADR próprio via `/forge:adr` e passa a declarar `based_on: [ADR-NNNN]`.
