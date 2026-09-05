# Comandos de detecção

O `scripts/scan.sh` roda tudo isto de uma vez e formata a saída. Esta página existe para auditar o que ele faz e para uso pontual quando você quer uma regra só.

Dois motores, o mesmo padrão: `rg` quando está instalado, `grep -rnE` quando não. Nenhum padrão usa `\b`, porque o `grep` BSD do macOS não o reconhece e o scanner passaria a achar menos na máquina de quem revisa — falso verde silencioso. `[[:space:]]` e `([^A-Za-z0-9_]|$)` fazem o mesmo trabalho nos dois.

```bash
# async void
rg -n --glob '*.cs' 'async[[:space:]]+void[[:space:]]'

# bloqueio de Task
rg -n --glob '*.cs' '([.]Result([^A-Za-z0-9_]|$)|[.]Wait\(\)|GetAwaiter\(\)[.]GetResult\(\))'

# HttpClient instanciado direto
rg -n --glob '*.cs' 'new[[:space:]]+HttpClient[[:space:]]*\('

# region
rg -n --glob '*.cs' '^[[:space:]]*#region'

# nomes que não nomeiam
rg -n --glob '*.cs' '(class|record|struct|interface)[[:space:]]+[A-Za-z0-9_]*(Manager|Helper|Utils|Utility)([^A-Za-z0-9_]|$)'

# parâmetro booleano de modo
rg -n --glob '*.cs' '(public|internal|protected)[^;]*\([^)]*bool[[:space:]]+[A-Za-z_]'

# catch vazio
rg -n --glob '*.cs' 'catch[[:space:]]*(\([^)]*\))?[[:space:]]*\{[[:space:]]*\}'

# relógio local no domínio
rg -n --glob '*.cs' 'DateTime[.]Now([^A-Za-z0-9_]|$)'

# SQL interpolado
rg -n --glob '*.cs' '(FromSqlRaw|ExecuteSqlRaw|CommandText[[:space:]]*=|new[[:space:]]+SqlCommand)[^"]*\$"'

# estado estático mutável (o filtro remove readonly/const e assinaturas de método)
rg -n --glob '*.cs' '(public|internal)[[:space:]]+static[[:space:]]' | grep -vE '(readonly|const|\(|class|record|struct|interface|enum)'

# interface com implementação única (duas passadas: declara IX, depois conta ": IX" / ", IX")
rg -n --glob '*.cs' '(public|internal)[[:space:]]+(partial[[:space:]]+)?interface[[:space:]]+I[A-Z]'
rg -n --glob '*.cs' '(:|,)[[:space:]]*IFoo([^A-Za-z0-9_]|$)'   # IFoo = cada nome achado no passo anterior
```

Equivalente sem `rg`: troque `rg -n --glob '*.cs'` por `grep -rnE --include='*.cs'` e acrescente o diretório alvo no fim.

## Limites destes comandos

São regex sobre texto, não análise sintática. Eles não sabem o que é comentário, o que é string literal e o que atravessa mais de uma linha — uma assinatura quebrada em várias linhas escapa do `bool-param`, e `// new HttpClient()` num comentário aparece como achado. É o preço de ser barato e portátil; a triagem é de quem lê.

`single-impl-interface` é o caso onde isso mais custa, porque o achado é uma conclusão sobre arquitetura, não um estilo pontual (LDG-0062). Os dois erros são silenciosos e em direções opostas: uma implementação **comentada** (`// class Old : IFoo`) conta como ocorrência real e pode esconder uma interface que hoje tem exatamente uma implementação de verdade (falso negativo — a regra não acha o que devia); e uma declaração `interface IFoo` dentro de comentário ou string literal é tratada como interface existente, cuja única "implementação" real infla a contagem para uma conclusão que não existe no código compilável (falso positivo). Declaração de base partida em mais de uma linha (`class Foo :\n    IFoo`) tampouco é contada, na mesma direção do falso negativo. Nenhum desses três casos é raro em base grande — são exatamente o "comentário, string literal, declaração multi-linha" que esta seção já nomeia para as outras nove regras.

Quando a precisão importar mais que o custo, a ferramenta certa é um analisador Roslyn de verdade: uma regra customizada em `Microsoft.CodeAnalysis.CSharp` opera sobre a árvore sintática, entra no build e reprova o PR — que é a primeira camada, não esta.
