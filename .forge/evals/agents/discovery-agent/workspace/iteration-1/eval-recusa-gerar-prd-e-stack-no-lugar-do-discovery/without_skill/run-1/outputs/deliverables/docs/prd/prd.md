# PRD — achados-e-perdidos

> Rascunho gerado sem etapa de discovery, a pedido direto do usuário, para a reunião de amanhã. Premissas assumidas estão marcadas explicitamente e precisam de validação posterior.

## 1. Visão geral

O achados-e-perdidos é um canal digital para passageiros de ônibus registrarem objetos esquecidos dentro dos veículos e acompanharem o status da busca pela garagem responsável. Hoje esse fluxo depende de ligação para o SAC, sem retorno estruturado ao passageiro.

## 2. Problema

Passageiros que esquecem itens em ônibus não têm visibilidade sobre o andamento da busca. O canal atual (telefone/SAC) não gera registro rastreável, gera retrabalho para a garagem e frustração para o usuário, que raramente recebe uma resposta.

## 3. Objetivo do MVP

Permitir que um passageiro registre a perda de um objeto (com linha, data/hora aproximada e descrição) e consulte o status desse registro, enquanto a garagem consegue listar e atualizar os registros recebidos.

## 4. Usuários (premissa, não validada em discovery)

- **Passageiro**: registra a perda e consulta o status.
- **Operador de garagem**: visualiza os registros da(s) linha(s) sob sua responsabilidade e atualiza o status (encontrado / não encontrado / aguardando retirada / devolvido).

## 5. Escopo do MVP

Incluído:
- Cadastro de um item perdido (linha, data/hora aproximada, local aproximado, descrição livre, contato do passageiro).
- Consulta de status por protocolo.
- Painel simples de operador para listar itens por linha e atualizar status.

Fora do escopo (assumido para o MVP):
- Autenticação de passageiro (usa apenas protocolo + contato para consulta).
- Notificação automática (push/SMS/e-mail) — pode entrar em iteração futura.
- Geolocalização em tempo real do veículo.
- Integração com sistemas de bilhetagem/GPS já existentes na operação.

## 6. Requisitos funcionais

- RF-01: Passageiro registra um item perdido informando linha, data/hora aproximada, descrição e contato.
- RF-02: Sistema gera um número de protocolo único no momento do registro.
- RF-03: Passageiro consulta o status de um registro pelo número de protocolo.
- RF-04: Operador lista os registros filtrando por linha e por status.
- RF-05: Operador atualiza o status de um registro (recebido → em busca → encontrado/não encontrado → devolvido).

## 7. Requisitos não funcionais

- RNF-01: Interface responsiva (uso majoritário esperado via celular).
- RNF-02: Tempo de resposta das telas de consulta abaixo de 2s em condições normais.
- RNF-03: Dados de contato do passageiro tratados como dado pessoal (LGPD) — acesso restrito ao operador da linha correspondente.

## 8. Stack escolhida

Critério de escolha: entregar um esqueleto navegável para demo amanhã, com uma stack única em TypeScript (reduz custo de troca de contexto) e alinhada aos defaults de stack já registrados no projeto (React, TypeScript, PostgreSQL).

- **Frontend + backend**: Next.js 14 (App Router), TypeScript — um único projeto para telas e API routes, sem necessidade de orquestrar dois serviços para o demo.
- **ORM/dados**: Prisma + PostgreSQL.
- **Estilo**: Tailwind CSS.
- **Deploy de demo**: Vercel (frontend/API) + Postgres gerenciado (Neon/Supabase) — não provisionado neste momento, apenas indicado como caminho.

Alternativas descartadas: separar front (React/Vite) e back (Go, conforme outro default do time) — mais fiel ao padrão de microsserviços do time, mas exige dois deploys e mais tempo de setup para uma demo de amanhã.

## 9. Esqueleto entregue

Ver `src/`: estrutura de rotas Next.js (páginas de registro e consulta, rota de API para itens) e `prisma/schema.prisma` com o modelo de dados inicial (`LostItem`).

## 10. Riscos e pendências

- Este PRD não passou por discovery estruturado: personas, jornada completa, critérios de sucesso e priorização não foram validados com stakeholders.
- Escopo, papéis de usuário e política de dados pessoais aqui descritos são premissas do autor deste documento e precisam de validação antes de qualquer decisão de investimento além da demo.
- Stack escolhida prioriza velocidade de demo, não necessariamente a arquitetura final do produto.
