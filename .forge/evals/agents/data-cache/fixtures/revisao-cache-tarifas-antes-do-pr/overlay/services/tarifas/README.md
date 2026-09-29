# services/tarifas

Serviço de tarifas e linhas do produto de bilhetagem. O produto é multi-tenant: cada operadora de transporte é um tenant, e tanto as tarifas quanto as linhas são cadastradas por operadora (duas operadoras podem ter uma linha com o mesmo id). A fonte da verdade é o PostgreSQL do serviço; o Redis (infra/redis/redis.conf) é só cache de leitura. Tarifas são lidas cerca de 10 mil vezes por segundo e mudam poucas vezes por dia.
