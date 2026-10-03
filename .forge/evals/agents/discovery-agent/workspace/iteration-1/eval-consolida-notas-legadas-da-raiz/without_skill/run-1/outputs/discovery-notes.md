# Discovery Notes — Pátio Digital

> Retomado em setembro/2026 a partir do rascunho de março. Duas lacunas do rascunho original (stack e monetização) foram confirmadas pelo cliente; o restante permanece como estava até nova validação.

## Problema

Os fiscais de pátio da Viação Norte anotam em prancheta a saída de cada ônibus da garagem e depois digitam tudo numa planilha no fim do turno. Atrasos na saída só são percebidos no dia seguinte.

## Usuário

Fiscal de pátio, trabalha em pé no pátio da garagem, possivelmente com luva e sol forte na tela.

## Stack

**Confirmado:** PWA com React, por pedido explícito da TI da Viação Norte. Isso decide a dúvida em aberto no rascunho de março (app nativo vs. PWA) a favor de PWA.

Consequências que essa escolha traz para o discovery, ainda sem validação:

- Uso em pátio a céu aberto, possivelmente com conectividade instável — importa confirmar se a PWA precisa funcionar offline (fila de eventos local com sincronização posterior) ou se cobertura de rede no pátio é suficiente hoje.
- Uso com luva e sol forte pede alvos de toque grandes e alto contraste; isso é viável em PWA, mas vale confirmar em qual(is) dispositivo(s) físico(s) a TI pretende rodar (celular corporativo, tablet fixo no pátio, etc.), já que isso muda decisões de layout e de instalação (add-to-home-screen vs. navegador aberto).
- Não há, até aqui, decisão sobre stack de backend/API — só o front foi pedido pela TI. Precisa entrar no discovery.

## Monetização

**Confirmado:** uso interno, sem cobrança. Não há modelo de receita a desenhar; o discovery de negócio se resume a custo de desenvolvimento/operação e a valor interno (redução de atraso, visibilidade em tempo real), não a precificação ou billing.

## Lacunas que continuam abertas (não confirmadas nesta retomada)

1. **Fluxo de dados fim a fim** — quem consome a informação de saída do ônibus depois do fiscal registrar (despacho? gestão de frota? um dashboard?). O rascunho de março só cobre a ponta do fiscal.
2. **Volume e concorrência** — quantos fiscais e quantos pátios simultâneos, para dimensionar se o backend é trivial ou precisa de fila/eventos.
3. **Integração com sistemas existentes** — a Viação Norte já tem algum sistema de gestão de frota ou bilhetagem com o qual o pátio digital precisa conversar, ou a planilha atual é o único sistema hoje?
4. **Papel exato da TI da Viação Norte** — pediram PWA/React como requisito de arquitetura já decidido, ou como preferência a validar contra as restrições de uso em campo (luva, sol, offline)? Vale confirmar se a decisão é negociável caso o discovery de campo (item 1 do rascunho de março, sol/luva) apontar para um approach diferente.
5. **Critério de sucesso** — o rascunho de março descreve o problema (atraso só percebido no dia seguinte) mas não define a métrica que o pátio digital precisa mover (ex.: tempo entre saída real e registro, taxa de atrasos detectados no mesmo turno).

## Próximos passos sugeridos

- Validar com a TI da Viação Norte: dispositivo-alvo, necessidade de offline, e se já existe API/sistema de frota para integrar.
- Uma visita ou entrevista curta com um fiscal de pátio para validar as condições de uso (luva, sol, prancheta atual) antes de fechar decisões de UI da PWA.
- Definir a métrica de sucesso do projeto antes de avançar para requirements.
