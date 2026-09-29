# Parecer de qualidade — Validador.Desktop

## Resumo executivo

O projeto compila e segue uma convenção de nomenclatura de interfaces (prefixo `I`) reforçada pelo `.editorconfig` com severidade `error` — por isso a IDE sublinha em vermelho quando alguém foge dessa regra. Isso é real e está funcionando, mas cobre uma fatia muito estreita da superfície de qualidade: nomenclatura de interface não diz nada sobre corretude, testabilidade ou fidelidade da implementação. "CI verde" também precisa ser lido com cuidado aqui: não há workflow de CI (`.github/workflows`) nem projeto de testes na árvore que recebi — então o que provavelmente passa verde é só a compilação, e uma compilação verde não valida comportamento algum. Encontrei quatro problemas de fundo que nem o analisador de nomes nem uma build verde teriam capacidade de pegar, e sinalizo também dois pontos que parecem suspeitos à primeira vista mas são, na minha avaliação, falsos alarmes.

## Achados reais

### 1. `SqliteTabelaTarifariaRepository` não fala com SQLite nenhum — é um stub disfarçado de implementação (severidade: alta)

`src/Validador.Desktop/Infra/SqliteTabelaTarifariaRepository.cs` implementa `ITabelaTarifariaRepository` retornando um valor fixo em código (`new TabelaTarifaria("2026.09", 4.40m, new DateTime(2026, 12, 31))`) via `Task.FromResult`, sem abrir conexão, sem query, sem nenhuma dependência de SQLite — e de fato o `.csproj` não referencia nenhum pacote de SQLite (`Microsoft.Data.Sqlite`, `System.Data.SQLite` etc.), só `Serilog`. O nome da classe promete uma integração que o corpo não entrega. Isso é o tipo de problema que nenhuma regra de nomenclatura de interface e nenhuma build verde detectam — o código compila, a interface é satisfeita, o nome "parece certo". Só aparece lendo a implementação e comparando com o que o nome promete. Se isso for um placeholder proposital de desenvolvimento, tudo bem, mas precisa estar marcado como tal (`TODO`, sufixo `Fake`/`Stub`, ou registro central no DI) para não ir parar em produção fingindo ser a integração real.

### 2. `TabelaTarifaria.EstaVigente()` depende de `DateTime.Now` direto no domínio (severidade: média-alta)

`src/Validador.Desktop/Domain/TabelaTarifaria.cs:16` chama `DateTime.Now` dentro da entidade de domínio. Duas consequências: (a) usa hora local da máquina em vez de `DateTime.UtcNow`, o que é frágil em qualquer cenário com fuso diferente do servidor/estações de campo; (b) acopla o domínio a um relógio global não injetável, então não dá para escrever um teste determinístico de "tabela expirada" sem manipular o relógio do sistema. É um smell clássico de testabilidade que passa batido em qualquer análise estática de nomenclatura, porque não é sobre nome — é sobre uma dependência implícita escondida dentro de um método aparentemente puro.

### 3. `TarifaBase` é `decimal`, não centavos inteiros — contraria a convenção que o próprio time documentou (severidade: média)

O `AGENTS.md` do repositório (seção "Boundaries") registra explicitamente: "money as integer cents". `TabelaTarifaria` (Domain/TabelaTarifaria.cs:8) declara `TarifaBase` como `decimal`. Nenhum analisador padrão do .NET pega isso — é uma convenção de negócio, não uma regra de linguagem — então só aparece comparando o código contra a própria documentação do projeto. Vale confirmar se a intenção mudou (e atualizar o `AGENTS.md`) ou se o tipo precisa migrar para inteiro em centavos antes que mais código dependa do `decimal`.

### 4. Botão de sincronizar não trava contra clique duplo / reentrância (severidade: média)

`btnSincronizar_Click` (UI/MainForm.cs:15-27) não desabilita o botão nem usa nenhum `CancellationToken` durante o `await`. Um segundo clique antes da primeira chamada terminar dispara uma segunda operação concorrente contra o mesmo repositório, e ambas escrevem em `lblStatus.Text` de forma não sincronizada — no melhor caso é só uma corrida de UI inofensiva com este stub, mas quando `CarregarVigenteAsync` virar uma chamada de rede/banco de verdade isso vira uma fonte real de estado inconsistente ou de exceções por reentrância. Sugiro desabilitar o botão no início do handler e reabilitar no `finally`.

### 5. `TreatWarningsAsErrors=false` com `Nullable=enable` (severidade: baixa, mas vale registrar)

`Directory.Build.props` liga nullable reference types mas desliga `TreatWarningsAsErrors`. Isso significa que qualquer violação de nulabilidade vira warning silencioso, não erro de build — o "CI verde" citado pelo time não teria como pegar um `null` indevido nem se alguém introduzir um, porque o compilador está configurado para deixar passar. É uma configuração, não um bug funcional, mas explica por que a build verde dá uma falsa sensação de segurança de tipos que ela não está de fato garantindo.

## Falsos alarmes (para não virar lista que o time ignora)

- **`catch (Exception ex)` genérico em `btnSincronizar_Click`.** Em um manipulador de evento de UI que é a borda externa da aplicação (top-level exception boundary), capturar `Exception`, logar com Serilog e mostrar uma mensagem amigável é o padrão correto — não capturar deixaria a exceção matar a aplicação inteira ou virar um popup críptico do runtime. Isso só seria um problema real se o mesmo padrão de captura ampla aparecesse em camadas internas (domínio, repositório), escondendo erros que quem chama precisa tratar diferente. Aqui, no limite da UI, está certo.
- **`async void` no handler do botão.** É comum apontarem "async void é anti-padrão" de forma automática, mas para manipuladores de evento do WinForms é a única assinatura válida — o framework não dá suporte a `async Task` como assinatura de evento. Não é dívida técnica, é a forma correta de escrever isso no WinForms.

## O que eu não consegui avaliar com o que recebi

Não havia projeto de testes nem workflow de CI na árvore fornecida, então não dá para confirmar o que exatamente "CI passa verde" está checando hoje (só compilação? testes de algum outro lugar não incluído aqui?). Vale o time confirmar isso antes de decidir prioridade dos achados acima — se não há teste automatizado nenhum cobrindo `TabelaTarifaria` ou o repositório, os itens 1 e 2 deste parecer são ainda mais urgentes, porque não há rede de segurança nenhuma pegando regressão neles.
