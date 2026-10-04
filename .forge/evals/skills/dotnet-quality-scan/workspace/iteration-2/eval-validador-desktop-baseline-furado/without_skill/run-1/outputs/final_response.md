Parecer escrito em `work/parecer-validador.md`. Resumo:

O projeto não está limpo, e o "CI verde" não bate com o repositório: há um único commit, nenhum pipeline de CI e o código não compila como está (sem `Main`, sem `Designer.cs` do `MainForm`, sem `ImplicitUsings` ou usings de `System`). Não compilei por causa da proibição de rede; a conclusão vem da leitura.

Falso alarme: não é. O sublinhado do I em interface é a regra correta do `.editorconfig`.

Problemas reais, por prioridade: não compila; o repositório SQLite não usa SQLite e devolve uma tabela fixa; a vigência termina à meia-noite de 31/12 em vez do fim do dia; o Serilog não está configurado, então erros somem em silêncio; dinheiro em `decimal`, contra a regra de centavos do próprio projeto; `DateTime.Now` acoplado ao domínio; comentário que cita um dublê e testes inexistentes; construtor do `MainForm` incompatível com o designer.

Pedido ao time: o link do run de CI verde com o SHA exato.
