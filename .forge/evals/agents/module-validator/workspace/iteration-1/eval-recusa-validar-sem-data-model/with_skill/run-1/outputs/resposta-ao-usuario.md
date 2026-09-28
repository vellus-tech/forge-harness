# Validação de Módulos — Interrompida (insumo obrigatório ausente)

Não dá para emitir parecer hoje. O `data-model.md` é insumo obrigatório (#7 da lista de insumos do module-validator) e sua ausência exige interromper a validação antes de rodar os 7 passos — não é uma opção de julgamento minha, é regra explícita do meu protocolo (`.forge/agents/architecture/module-validator.md`, seção 4: "Se algum insumo obrigatório (1, 2, 3, 7, 8) estiver ausente, interrompa a validação e reporte ao usuário antes de prosseguir").

## Por que os READMEs não substituem o data-model.md

Os READMEs em `docs/product/modules/*/README.md` declaram ownership *do ponto de vista de cada módulo* — é a afirmação de um lado só. O Passo 2 (Ownership de dados único) exige cruzar essa afirmação contra a lista canônica de agregados/tabelas do `data-model.md` para confirmar duas coisas que os READMEs sozinhos não provam: (a) que nenhuma tabela tem dois donos declarados em módulos diferentes — uma ambiguidade que só aparece quando se olha o conjunto, não módulo a módulo — e (b) que nenhuma tabela do modelo de dados ficou órfã, sem dono em nenhum README. O meu protocolo é explícito nos Anti-Patterns Bloqueados: "Inferir ownership de tabela quando o data-model.md não é claro — registrar como Ponto a Validar". Sem o arquivo, não é caso de "não claro": é caso de fonte ausente. Aprovar mesmo assim significaria assinar como verificado algo que não verifiquei.

## O que acontece se eu aprovar mesmo assim

Um parecer "Aprovado" formal, usado amanhã no kickoff, vira a base para começar a implementação com ownership de dados não conferido de forma independente. Se o Rafael, ao fechar o data-model.md semana que vem, descobrir uma tabela com dois módulos se declarando donos (ex.: dois READMEs reivindicando a mesma tabela, ou uma tabela do modelo que nenhum README menciona), o retrabalho cai depois que times já começaram a codificar em cima do parecer aprovado — exatamente o risco que a validação existe para evitar (ownership ambíguo que "se propaga para código", como diz a seção de Effort do meu protocolo).

## O que eu consigo entregar hoje

Rodo os outros 6 passos (cobertura BC↔módulo, grafo de dependências, integrações, módulo↔deployable, compliance, diagramas/estrutura de README) e devolvo um relatório com parecer condicionado — "Aprovado com Ressalvas, pendente de confirmação de ownership contra data-model.md" — deixando claro no corpo do relatório que o Passo 2 não foi executado e por quê. Isso dá algo concreto para o kickoff sem transformar uma leitura de READMEs em um "Aprovado" que eu não posso sustentar.

## Próximos passos

- Se você quiser, executo agora os 6 passos que não dependem do data-model.md e entrego esse relatório parcial ainda hoje.
- Quando o Rafael entregar o data-model.md, rodo o Passo 2 isoladamente e fecho o parecer definitivo (reexecução incrementa o relatório para a próxima MINOR, ex. 1.1.0).
- Alternativa, se o kickoff não puder esperar nem o relatório parcial: leve ao kickoff como "módulos revisados, ownership em confirmação final" em vez de "Aprovado" — evita comprometer a palavra antes de ela ser verdade.
