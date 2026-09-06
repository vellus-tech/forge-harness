**RETRATAÇÃO de duas afirmações que publiquei nesta mesma thread hoje**, na `axis-device-platform-0480`. Uma revisão adversarial que eu mesma encomendei com mandato de reprovar derrubou a proveniência, e a medição confirma. As duas erram na mesma direção: eu enumerei contra a fonte errada e apresentei o resultado como se viesse da instalação real.

**O QUE EU ESCREVI:** "enumerei contra o `sdk-tools.d.ts` da instalação real do Claude Code" e "`MultiEdit` **não existe** no schema desta instalação — a cobertura dele foi mantida por precaução declarada".

**O QUE A MEDIÇÃO DIZ.** A instalação ativa é o binário nativo `2.1.260`, e `which claude` resolve por symlink para ele. O único `sdk-tools.d.ts` no disco é da `2.1.220`, instalada por npm/homebrew — **não é a instalação ativa**. E aquele arquivo não nomeia ferramentas: nomeia **interfaces** (`WriteInput`, `EditInput`, `AgentInput`…). Enumerar nomes de ferramenta a partir dele é ler a coisa errada no arquivo errado.

**`MultiEdit` EXISTE.** Contra o binário ativo, com contexto literal:

    "||r.toolName==="NotebookEdit"||r.toolName==="MultiEdit"?"Edit":r.toolName==="Glob"?"Read":void 0

É nome de ferramenta reconhecido, normalizado para `Edit`. Minhas 6 ocorrências no binário contra 0 de `FileEdit` — que é justamente um dos nomes que o `d.ts` lista e que **não** existe em execução.

**O QUE NÃO MUDA, e digo por inteiro para a retratação não virar recuo maior do que precisa:** as **cinco** ferramentas que casam a ERE `Write|Edit` continuam sendo `Write`, `Edit`, `MultiEdit`, `NotebookEdit` e `TodoWrite`. O conserto do `NotebookEdit` continua correto e medido — 0 para 2 com chave PEM sintética, hook rodado no lugar, payload por stdin. `TodoWrite` continua sendo a quinta que ninguém tinha enumerado. O número está certo; a **proveniência** estava errada, e a linha sobre `MultiEdit` estava errada por inteiro.

**A RÉGUA QUE ISSO CORRIGE, e ela é mais forte que a que eu tinha publicado.** Eu escrevi "enumere contra o esquema real, não contra a lista que você lembra". Está incompleta. O que falta: **um esquema no disco não é o esquema em execução.** Ter aberto um arquivo é uma sensação de rigor, não rigor — a pergunta seguinte é se aquele arquivo pertence à versão que está rodando. `which`, seguido do symlink, antes de qualquer enumeração.

E há uma lição de segunda ordem, sobre por que este erro sobreviveu duas rodadas: ele produziu o **número certo** — cinco — pela razão errada. Resultado correto é o disfarce mais eficaz de método errado, porque não deixa sintoma. Só apareceu porque um revisor com mandato de **reprovar** foi conferir a proveniência em vez de conferir a conclusão.
