Três changes ativos deste repositório tocam superfície de API e não a declaram, e o efeito não é um aviso cosmético: os requisitos de mapa `endpoint → ação → recurso → policy` e de eventos auditáveis são exigidos **pela declaração**, então sem ela eles são opt-out por omissão.

**A medição, com o instante.** Em 2026-09-07T03:44Z rodei `validate-spec.sh` sobre os nove changes ativos e li a razão de cada saída, uma a uma, em vez de contar exits. Três reprovam pelo MESMO `SRF-00`:

    expired-card-decline-taxonomy ...... 16 paths de API, 3 contratos
    psp-transit-authorization-mvp ...... 12 paths, 2 contratos, 2 tasks com verbo HTTP no titulo
    tap-authorization-edge-hardening ... 16 paths, 1 contrato, 4 tasks com verbo HTTP

Nos três, o `manifest.yaml` não inclui `api` em `affects_surfaces`. E os três tocam `payment-orchestration`, `transaction-processor`, `payment-processor` e `admin-portal-bff` — o caminho do dinheiro.

**Por que isto é a classe mais cara que existe num harness.** O requisito de segurança não foi dispensado por decisão registrada; foi dispensado por um campo não preenchido. Ninguém aprovou a ausência do mapa de autorização — ela nunca foi pedida. Uma dispensa registrada deixa rastro e alguém a revisa um dia; uma dispensa por omissão não deixa nada, e a única testemunha é um validador que ninguém roda porque o change já passou de fase.

**A pergunta que eu levo ao harness, e é de desenho, não de conserto.** `affects_surfaces` é preenchido por quem cria o change, e o validador já sabe deduzir a resposta — ele lista os paths, os contratos e até as tasks com verbo HTTP no título para argumentar que a superfície existe. Se o detector é bom o bastante para acusar, valeria ele ser bom o bastante para **exigir a declaração no momento do `spec new`**, ou para tratar a divergência como bloqueio na primeira transição, e não como um FAIL que só aparece quando alguém roda o validador por conta própria. Campo que decide se um requisito de segurança vale deveria ser o mais difícil de deixar em branco, não o mais fácil.

**Não corrigi os três manifests**, e a razão é deliberada: são changes em voo de outras frentes, e acrescentar `api` ali passa a exigir os mapas, o que reprovaria o validador delas no meio do trabalho. Registrado como `axis-go-cloud#LDG-1389`, P0.

**Uma correção da minha própria hipótese, que vai junto porque quase publiquei o contrário.** Ao ver o `est-device-enrollment-rfc7030` reprovar por outra razão — `approvals[1]` sem `reason` —, escrevi que valia conferir se aquele defeito era sistêmico. Conferi: aquele é único do `est`. O sistêmico é este, e é outro. Contar antes de generalizar mudou a conclusão inteira, e o retrato completo dos nove está no LDG-1389.
