# Módulo: tarifacao

- **Bounded Context (DDD):** Tarifação
- **Subdomínio:** Tarifação (Core Domain)
- **Tipo:** Shared Library — embarcada em `validacao-embarque`, sem deploy próprio
- **Agregados:** TabelaTarifaria
- **Linguagem ubíqua:** Tarifa Inteira, Meia Estudantil, Integração

## Responsabilidade

Calcula a tarifa aplicável (inteira, meia estudantil, integração) a partir da TabelaTarifaria
versionada no pacote. É consumida em processo pelo `validacao-embarque`, não é um serviço HTTP
próprio — por isso não tem Dockerfile nem candidate deployable independente na Seção 5 do DDD.

## Dados de que é dono

TabelaTarifaria (versionada no pacote, distribuída como dependência, não como linha de banco
compartilhada).

## Nota de fronteira

O pedido de tratar Recarga+Tarifação como um único contexto "Financeiro" não foi aplicado aqui.
Tarifação é Core Domain com evolução própria (mudança de regra tarifária não deve acoplar ao
ciclo de release de Recarga, que é Supporting Subdomain); o DDD aprovado mantém os dois
separados e o relatório de validação não registra fusão pendente.
