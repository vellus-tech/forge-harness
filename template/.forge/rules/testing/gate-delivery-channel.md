---
title: Prova de gate exercita o canal de entrega, não só o alvo
applies_to:
  - all
priority: high
last_reviewed: 2026-08-19
---

# Prova de gate exercita o canal de entrega, não só o alvo

Um gate tem duas metades: **o que ele decide** e **como ele chega até onde a decisão importa**. A prática comum prova só a primeira — monta uma fixture com a violação, roda o gate contra ela, vê a recusa, declara o gate vivo. A segunda metade fica sem prova nenhuma, e é onde o defeito mora com mais frequência, porque ela não aparece no diff.

O caso que originou esta rule: um gate foi ancorado corretamente no alvo real, testado contra a violação, aprovado — e entregue por um canal (`core.hooksPath` relativo) que sofria exatamente da doença que o gate curava. O teste de alvo passava nas duas versões do canal. Só a exigência de observar uma **recusa real, pelo caminho pelo qual o gate roda em produção**, distinguiu o gate vivo do gate morto.

## O que a regra exige

**A prova acontece pelo canal real.** Se o gate roda num hook, o teste faz o `git commit`/`git push` de verdade numa fixture e observa o bloqueio — não invoca o script do gate diretamente e só. Se o gate roda no CI, existe um cenário que reproduz a invocação do CI. Se o gate roda a partir de um worktree, o teste cria um worktree.

**A prova distingue "não encontrei violação" de "não rodei".** Um gate que não foi invocado produz o mesmo silêncio de um gate que aprovou. Toda prova de canal precisa de um sinal positivo de execução — um marcador que só o gate certo emite, um arquivo que só ele escreve —, nunca a mera ausência de erro. Ver [quality-gates](./quality-gates.md), item de vacuidade.

**A prova de mutação vale para o canal também.** Além de "quebro o alvo e o gate acusa", vale "quebro o canal e a prova acusa": desative o apontamento, aponte para a cópia antiga, rode a partir do lugar errado. Se o teste continua verde, ele não estava medindo o canal.

**Um gate cujo canal é config local não versionada exige backstop.** Config de máquina some num clone novo e num runner de CI. Onde a entrega depende dela, existe uma verificação independente de máquina — tipicamente no CI —, ou o gate é, na prática, opcional.

Ver também: [regression-red-first](./regression-red-first.md), [quality-gates](./quality-gates.md) e [conventions/machinery-propagation](../conventions/machinery-propagation.md).
