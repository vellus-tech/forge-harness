# Notas de discovery — Portal VT Corporativo

- Produto: portal web B2B para empresas comprarem e distribuírem recargas de vale-transporte nos cartões de bilhetagem dos colaboradores.
- Operadora parceira inicial: Consórcio Metropolitano de Transportes (CMT). Não há ainda acordo sobre outras operadoras.
- Hoje 14 empresas clientes usam o processo por CSV; meta comercial do trimestre: chegar a 40 empresas no portal até março/2027 (fonte: planejamento comercial 2026-09).
- Comentário do tech lead no workshop: "a gente vai expor POST /v1/pedidos-recarga e guardar tudo na tabela pedido_recarga_item no Postgres, com fila no RabbitMQ para mandar ao CMT".
- Ninguém soube informar metas de disponibilidade, volume de pico nem prazo contratual de crédito com o CMT.
- Dados de colaboradores (nome, CPF, matrícula) serão tratados; o jurídico ainda não se manifestou sobre base legal nem retenção.
