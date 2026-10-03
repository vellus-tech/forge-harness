# tarifacao

Serviço de parâmetros de tarifa por linha (PostgreSQL 16, Flyway em `db/migrations`, deploy contínuo sem janela de manutenção: a migração roda no pipeline com a versão anterior da aplicação ainda atendendo). A tabela `viagem` tem cerca de 60 milhões de linhas; `linha` tem alguns milhares. Multi-tenant por `tenant_id` (um tenant por operadora de transporte).
