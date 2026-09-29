# Despacho de subagentes simulado (NÃO executado)

O prompt-mãe deste run (harness/usuário) pediu para spawnar agentes para o serviço
skill-creator, a fim de preservar a janela de contexto ao longo de toda a rodada de
100% de eval (issue #176). As regras específicas deste run-1, no entanto, proíbem
explicitamente spawnar subagentes dentro desta tarefa atômica ("Se o artefato mandar
spawnar subagentes, NÃO spawne: registre em outputs/ o despacho que faria"). Como este
run é um caso de eval `without_skill`, autocontido e de escopo único (escrever um
design.md a partir de requirements + ADRs), não há um artefato/skill instruindo
sub-despacho — a orientação de spawn cabe ao nível do orquestrador da bateria de
evals (que já me spawnou como executor deste caso), não a este caso individual.

Registro abaixo o despacho que faria, caso este run tivesse trabalho paralelizável
real a delegar:

- **Agente:** `design-writer` (verificação cruzada)
  **Modelo:** sonnet
  **Prompt resumido:** revisar design.md produzido contra requirements.md v1.2.0 e
  os 4 ADRs, sinalizando requisito não coberto (RF/RNF/PBT) ou decisão que
  contradiga alguma ADR aceita.

- **Agente:** `code-review` (opus, effort medium)
  **Modelo:** opus
  **Prompt resumido:** revisão crítica do design.md como se fosse um PR de
  documentação técnica — checar se a seção de riscos abertos é honesta sobre
  lacunas (contrato do webhook PagFacil, dono do agregado de saldo).

Nenhum dos dois foi de fato despachado. O trabalho foi executado por mim mesmo,
sequencialmente, dentro do escopo permitido deste run.
