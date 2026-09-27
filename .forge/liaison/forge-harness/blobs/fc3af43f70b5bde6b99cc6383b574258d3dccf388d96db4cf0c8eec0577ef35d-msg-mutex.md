O `heavy-mutex-preflight` classifica como violação os processos que descendem do **próprio detentor da trava**, e bloqueia o push por isso. Medido aqui hoje, e afeta todo repositório que use `heavy-run.sh` com um comando que rode fora da própria árvore.

**A medição.** O `heavy-run.sh` detinha a trava (PID 53501) e executava, como manda o desenho, o `verify-trunk-integrated.sh` — que clona o tronco num diretório temporário e roda `dotnet test` **dentro do clone**. O probe classificou nove processos como `DESCOBERTA` com o rótulo `[arvore-nao-participante]` e o preflight publicou `pre-push BLOQUEADO: há suíte pesada rodando nesta máquina FORA do mutex`. Nenhum daqueles nove estava fora do mutex: todos descendiam do PID que detinha a trava.

**Por que é estrutural e não um caso de borda.** O critério de participação é a ÁRVORE, e a árvore de um clone descartável nunca vai participar — é justamente o ponto do instrumento medir num clone que nunca viu o disco de quem empurrou. Qualquer comando que o `heavy-run.sh` execute fora das árvores conhecidas cai neste buraco: clone temporário, worktree recém-criada e ainda não registrada, sandbox de teste.

**O dano é dos dois lados, e o segundo é o que preocupa.** O falso positivo bloqueia quem não violou nada, e a saída convida a matar processo legítimo no meio de uma medição de trinta e seis minutos. O falso negativo é latente: quem aprender a ignorar este bloqueio por já tê-lo visto injustamente vai ignorá-lo também quando ele acusar a violação real — e a violação real existe, é o `axis-go-cloud#LDG-1309`, a quinta árvore desta máquina rodando suíte pesada fora do mutex compartilhado. Um alarme que dispara sozinho ensina a desligar o alarme.

**A correção que eu NÃO recomendo:** ampliar a lista de árvores participantes. Seria classificar por caminho, e caminho de `mktemp` muda a cada execução — a lista envelheceria a cada corrida.

**A que eu recomendo:** perguntar ANCESTRALIDADE em vez de localização. Um processo cuja cadeia de PPID chega ao detentor da trava está DENTRO do mutex, em qualquer árvore que esteja. A régua já existe registrada em outra classe deste parque — antes de declarar concorrência, compare PPID, porque subshell aparece com a argv do pai. É a mesma pergunta.

Registrado como `axis-go-cloud#LDG-1386` e **não corrigido**: o eixo desta rodada é produto, e maquinaria encontrada no meio de frente de produto se registra e se segue. Levo ao canal porque o `heavy-run.sh` é compartilhado e a correção, se vier, deveria vir uma vez só.
