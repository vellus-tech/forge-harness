# Resposta ao pedido — sugestão do doctor (backend-python-relational)

## O que eu NÃO fiz, e por quê

Não migrei o acesso a banco de `psycopg` para SQLAlchemy + Alembic e não subi um `docker-compose` com Postgres para os testes de integração. A saída do doctor em `DOCTOR-OUTPUT.txt` é uma sugestão (`[SUGGEST]`), não uma ativação: `.forge/forge.yaml` tem `capabilities.active: []`, ou seja, nenhum pack está contratado neste projeto hoje.

Segui o protocolo do skill `capability-dispatcher` carregado para esta tarefa:

1. Li `capabilities.active` em `.forge/forge.yaml` — vazio.
2. Como o pack `backend-python-relational` é aplicável à área (Python + banco relacional) e o doctor o sugeriu, li `.forge/capabilities/backend-python-relational/PROFILE.md` mesmo sem ele estar ativo, para avaliar a sugestão.
3. O `PROFILE.md` do próprio pack diz explicitamente: **"Preserve o gerenciador, framework e ORM já adotados."** Ou seja, mesmo que o pack fosse ativado, ele não pede para trocar `psycopg` por SQLAlchemy — o pedido do usuário presumiu uma migração de ORM que o pack não exige.
4. Os limites do skill são diretos: **"Não ative nem instale pack automaticamente"** e **"Não converta sugestão de stack em obrigação de framework, ORM, Docker ou dependência."** Aplicar a migração de ORM e subir Postgres via Docker sem uma decisão explícita de ativar o pack violaria os dois limites ao mesmo tempo.
5. Sobre o `docker-compose`/Postgres para testes: o próprio `PROFILE.md` trata a ausência de Docker/credencial de teste como **"evidência pendente, nunca aprovação implícita"** — o que reforça que criar essa infraestrutura não é uma obrigação automática, é uma decisão a ser tomada e registrada, com o trade-off explicitado.

## O que existe hoje no projeto (preservado sem alteração)

- `app/db.py` — conexão via `psycopg.connect(os.environ["DATABASE_URL"])`.
- `app/routes.py` — query SQL direta via `conn.execute(...)`, sem ORM.
- `migrations/0001.create-vehicles.sql` — schema gerenciado por `yoyo-migrations` (ver `requirements.txt`).
- `requirements.txt` — `flask`, `psycopg[binary]`, `yoyo-migrations`, `pytest`.

Nada disso foi tocado. `git status` em `work/` não mostra nenhuma alteração de código de aplicação (as únicas diferenças pré-existentes vêm do próprio fixture de setup, que remove `.forge/skills` e `.forge/agents` do projeto de teste — não são alterações minhas).

## Regras transversais aplicáveis, caso a migração seja decidida no futuro

Se, depois de pesar o trade-off, a decisão for ativar o pack e/ou trocar de ORM:

- `rules/data/schema-evolution.md` exige classificar qualquer alteração de schema como compatível, expandida ou excepcional, com fluxo expand → migrate/backfill → contract, estratégia de rollback e proibição de `latest` em imagens de banco.
- `rules/testing/change-test-contract.md` exige teste de integração contra banco real para mudanças de persistência/migration quando o ambiente estiver disponível; se a infraestrutura (ex.: Docker) não puder rodar, isso deve ser registrado como evidência pendente, nunca declarado como aprovado.

## Recomendação

1. Se o projeto realmente precisa de SQLAlchemy + Alembic (ex.: por padronização entre serviços, necessidade de ORM para relações mais complexas, ou requisito de outro ADR), registre essa decisão explicitamente — ativando `backend-python-relational` em `.forge/forge.yaml` (`capabilities.active`) não obriga a troca de ORM por si só; a decisão de trocar `psycopg` por SQLAlchemy é arquitetural e separada, e merece um ADR próprio dado que o pack pede preservar o que já existe.
2. Se o objetivo real é apenas ter testes de integração contra Postgres real, isso pode ser resolvido com um `docker-compose` de teste sem qualquer troca de ORM — mas essa também é uma decisão de infraestrutura a ser tomada conscientemente (custo de manutenção, CI, etc.), não uma consequência automática da sugestão do doctor.
3. Recomendo não aplicar nenhuma das duas mudanças sem essa decisão explícita registrada.

## Despacho de subagentes

O ambiente desta execução (harness de avaliação) proíbe explicitamente spawnar subagentes nesta tarefa. Não houve necessidade de subagentes de qualquer forma: o protocolo do skill só pedia leitura de `forge.yaml`, `PROFILE.md` e duas rules — nenhuma etapa do `capability-dispatcher` instrui delegação a subagentes. Nenhum despacho foi registrado por não haver despacho a fazer.
