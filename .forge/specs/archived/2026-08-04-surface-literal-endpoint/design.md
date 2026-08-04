# Design — surface-literal-endpoint

## O que a medição mudou

O `LDG-0010` supunha uma sequência: existe o oráculo → o `SRF-01` distingue defeito de código de defeito de declaração → promove. A medição contra o repositório de referência mostrou que a segunda etapa não acontece para a maioria dos casos: 7 dos 11 achados não têm endpoint literal na célula, e sobre prosa não há cruzamento possível.

Então a ordem certa é outra: primeiro o insumo (a célula citar o endpoint), depois a distinção, depois a promoção. `SRF-03` é a primeira etapa.

## Por que aviso e não bloqueio

7 dos 26 changes do repositório de referência receberiam o achado hoje. Um check que chega bloqueando o passado é desligado — e desligado ele não coleta o insumo que justifica a promoção seguinte. Como aviso, ele muda o que se escreve daqui para frente sem travar o que já existe.

## Por que não cobrar de toda célula

Pedir `VERB /path` numa linha cuja superfície é uma tela ou uma flag de config transformaria o check em formulário: a pessoa preencheria qualquer coisa para calar o aviso, e o insumo ficaria pior do que está. O gatilho é `namesApiSurface`, o mesmo oráculo que o `SRF-01` já usa para decidir se a linha é de API.

## O que fica registrado para a decisão futura

O ledger passa a carregar a medição inteira — rotas, irresolúveis por kind e por escopo, veredito do `SUR-01`, classificação dos achados. Quem retomar o item decide com números, não com a memória de quem mediu.
