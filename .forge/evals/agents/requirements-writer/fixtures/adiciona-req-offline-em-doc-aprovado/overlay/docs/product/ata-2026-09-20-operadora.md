# Ata — Reunião com a Operadora Viação Rota Sul (2026-09-20)

Participantes: Milton (Axis), Carla Mendes (Operadora), Jorge Tavares (SEMOB).

Decisões:

1. Quando o Validador perder conexão com a central, ele deve continuar validando em modo offline.
2. Em modo offline, o Validador aceita no máximo 200 Validações ou 24 horas, o que ocorrer primeiro; ao atingir o limite, passa a negar embarques com o resultado `DENIED_OFFLINE_LIMIT`.
3. As Validações offline devem ser enviadas à central assim que a conexão voltar, sem duplicar débito caso o envio seja repetido.
4. Cartões em lista de restrição continuam bloqueados offline com a última lista recebida.
