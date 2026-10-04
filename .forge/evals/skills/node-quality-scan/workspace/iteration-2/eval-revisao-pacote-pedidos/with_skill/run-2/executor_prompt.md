# Execução de um pedido

Você vai atender um pedido de usuário num projeto de software. Trabalhe de verdade no projeto, como faria numa sessão normal.

## Ambiente

- Projeto: `<RUN>/work`. O shell não guarda o diretório entre chamadas: comece toda chamada Bash com `cd <RUN>/work && `.
- Escreva apenas dentro de `<RUN>/work`, `<RUN>/outputs` e `<RUN>/tmp`. Não leia, não liste e não busque nada fora desses três diretórios.
- Arquivos temporários: onde o pedido, o projeto ou qualquer instrução citar um caminho em `/tmp/`, use `<RUN>/tmp/` no lugar (por exemplo, `/tmp/x.log` vira `<RUN>/tmp/x.log`). Não grave em `/tmp` diretamente.
- Política desta execução:
  - git local no projeto é permitido (branch, worktree, commit, merge local); push só para remotes que já apontem para dentro do projeto, nunca para a rede.
  - build e testes locais são permitidos, desde que não precisem de rede (nada de instalar ou baixar dependências).
  - rede é proibida (curl, gh, npm install, restore com download, fetch de remote externo).
  - subagentes são permitidos se o fluxo pedir: use a ferramenta Agent com `model: "sonnet"` e `subagent_type: "general-purpose"`, e repasse a eles esta seção Ambiente inteira.
  - docker e `sleep` em foreground são proibidos.
- Não há humano disponível durante a execução. Quando o fluxo exigir decisão do usuário, faça o que o fluxo manda nesse caso e diga isso na resposta final.

## Skill disponível

Este projeto tem a skill `node-quality-scan` instalada em `<RUN>/work/.forge/skills/node-quality-scan/`. Antes de agir, leia integralmente `<RUN>/work/.forge/skills/node-quality-scan/SKILL.md` e aplique-a a este pedido, como faria com uma skill carregada na sessão.

## Registro obrigatório

Ao terminar, grave:

1. `<RUN>/outputs/transcript.md`: o passo a passo do que fez, com cada comando relevante e o resultado resumido, cada arquivo lido ou escrito e as decisões tomadas.
2. `<RUN>/outputs/final_response.md`: a sua resposta final ao usuário, literal, exatamente como a daria no chat.

Grave também em `<RUN>/outputs/` qualquer entregável que não fique dentro do projeto. A sua resposta a quem o chamou é só a linha `OK` (ou `FALHA: <motivo>`): o conteúdo vai nos arquivos.

## Pedido do usuário

Estou na branch feat/listagem-pedidos do nosso monorepo da loja. Mexi só no packages/pedidos (listagem por status e a rota da nota fiscal). Antes de abrir a PR, faz um code review de qualidade das minhas mudanças e salva o relatório em outputs/revisao-pedidos.md.
