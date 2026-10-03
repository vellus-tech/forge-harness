# Despacho de subagente (simulado — não executado)

Regra do eval proíbe spawn real de subagentes nesta run. Registro aqui o despacho que faria caso o protocolo do `platform-reviewer` (ou o skill-creator, se acionado como orquestrador) pedisse paralelismo.

## Não houve necessidade real de subagente nesta tarefa

O `platform-reviewer.md` define um pipeline sequencial de 7 seções (Dockerfile, CI, K8s, Observabilidade, Resiliência, Config/secrets, NFRs) sobre um diff pequeno (6 arquivos, 127 linhas). Não há indicação no artefato do agente para paralelizar via subagentes — é um agente de revisão único, com tools Read/Glob/Grep/Bash, que produz um JSON de findings. Rodei o pipeline inteiro eu mesmo, sequencialmente, dentro da janela de contexto desta run.

## Se houvesse motivo para delegar (hipotético)

Caso o diff fosse maior (múltiplos serviços, múltiplos Dockerfiles/manifests em paralelo), o despacho que eu faria, seguindo a diretriz global de "uma árvore, um escritor" e model explícito por tipo de trabalho:

- **agente:** `platform-reviewer` (um por serviço/diretório de manifests, cada um lendo um subconjunto do diff)
- **modelo:** `sonnet` (conforme `model: sonnet` no frontmatter do agente — trabalho de revisão/integração, não implementação bite-sized)
- **prompt resumido:** "Revise apenas os arquivos em `deploy/k8s/*-prd.yaml` contra as regras de plataforma para namespace prd-*; não avalie stg; retorne findings no formato PLAT-NNN."
- **consolidação:** o orquestrador (eu, nesta run) juntaria os JSONs de findings de cada subagente em um único `platform-deploy-validacao.json`, sem confiar cegamente no relatório de cada um — validando contra o diff real antes de aceitar.

Como não spawnei nada, este arquivo é só o registro do que seria despachado, não uma execução.
