# Validações de catraca — padrões de acesso

A tabela `validacoes-catraca` é o log de passagens registradas pelos validadores embarcados dos ônibus. O débito tarifário acontece em outro serviço; aqui é só o registro da passagem, usado pelo app do passageiro e pelo painel do operador. A tabela já existe em homologação com cerca de 40 milhões de itens; produção entra no próximo sprint.

- Escrita: pico de ~12.000 validações/s no horário de rush (6h–9h e 17h–19h), todas com a data do dia corrente.
- App do passageiro: histórico das validações de um cartão nos últimos 30 dias, ordenado por data (a maior parte do tráfego de leitura, ~3.000 req/s).
- Painel do operador: validações com status `RECEBIDA` ainda não conciliadas, por tenant (operadora); tolera alguns segundos de atraso.
- Um passageiro frequente passa de 2.000 validações por ano no mesmo cartão.
- Multi-tenant: cada operadora é um tenant.
