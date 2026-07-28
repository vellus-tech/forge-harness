---
title: Contrato mínimo de testes por mudança
applies_to:
  - all
priority: high
last_reviewed: 2026-07-22
---

# Contrato mínimo de testes por mudança

O conjunto de testes é definido pelo risco e pela superfície alterada, não por meta de cobertura. A task deve apontar qual destes itens é aplicável e fornecer a evidência correspondente.

- Lógica de domínio ou aplicação: teste de comportamento/invariante; TDD e PBT quando houver propriedade verificável.
- Persistência ou migration: teste de integração contra banco real quando o ambiente estiver disponível; a migration deve fazer parte do caminho exercitado.
- Endpoint com recurso do usuário/tenant: teste positivo e teste negativo de autorização/ownership (IDOR quando aplicável).
- API ou evento: teste de contrato para o consumidor/produtor afetado e cenário de incompatibilidade quando houver versão.
- Tela orientada a dados: loading, sucesso, vazio e erro, além da interação/validação do formulário quando existir.

Mocks substituem fronteiras que o teste não controla, como gateway externo, relógio ou fila. Não usar mock para transformar banco, domínio ou contrato interno em um teste verde sem valor. Se a infraestrutura não puder rodar, registrar explicitamente a evidência pendente; nunca declarar esse nível de teste aprovado.

Em change de tipo `bugfix`, este contrato é complementado por [`regression-red-first.md`](./regression-red-first.md): o teste de reprodução precisa ter sido observado falhando na árvore pré-correção, com evidência replicável.
