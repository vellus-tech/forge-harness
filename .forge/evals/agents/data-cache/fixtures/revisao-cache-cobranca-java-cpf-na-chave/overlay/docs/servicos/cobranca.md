# services/cobranca

Serviço de cobrança de passe mensal (Java 21, Spring Boot 3). Multi-tenant por operadora. Fonte da verdade: PostgreSQL. Redis e Caffeine são cache de leitura do cadastro do titular e das faturas abertas; roda em 12 réplicas no Kubernetes.
