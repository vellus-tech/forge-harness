---
name: scaffold-tdd
description: Gera o esqueleto de um teste seguindo o ciclo Red-Green-Refactor, com estrutura AAA (Arrange-Act-Assert) e placeholder de PBT quando aplicável.
arguments:
  - name: test-name
    description: "Nome da classe testada em PascalCase (ex: Money, PaymentCommandHandler)"
    required: true
---

# /forge:scaffold-tdd

Gera o esqueleto de uma classe de teste xUnit seguindo TDD (Red-Green-Refactor) com estrutura AAA.

## Passos a Executar

1. **Inferir projeto de teste**
   - Se `test-name` contém `CommandHandler` ou `QueryHandler` → `Application.Tests`
   - Se `test-name` é objeto de valor ou entidade → `Domain.Tests`
   - Se `test-name` contém `Repository` → `Integration.Tests`
   - Perguntar ao usuário se não for possível inferir

2. **Gerar classe de teste**

```csharp
using FluentAssertions;
using FsCheck;
using FsCheck.Xunit;
using Xunit;

namespace <Namespace>.Tests;

public class {{TEST_NAME}}Tests
{
    // ─── Testes de exemplo (Red → Green → Refactor) ────────────────────────

    [Fact]
    public void <Method>_<Scenario>_<ExpectedResult>()
    {
        // Arrange
        // TODO: configurar estado inicial

        // Act
        // TODO: invocar o comportamento sob teste

        // Assert
        // TODO: verificar resultado esperado
    }

    [Theory]
    [InlineData(/* caso 1 */)]
    [InlineData(/* caso 2 */)]
    public void <Method>_MultipleScenarios_<ExpectedResult>(/* parâmetros */)
    {
        // TODO: implementar
    }

    // ─── Property-Based Tests (quando há propriedades matemáticas) ─────────

    // Descomente se aplicável (ex: para objetos de valor com operações aritméticas):
    // [Property]
    // public Property <Operation>_IsSomeMathProperty(/* geradores */)
    // {
    //     return (/* propriedade */).ToProperty();
    // }
}
```

3. **Adicionar ao projeto de teste correto** (criar arquivo no diretório certo)

4. **Verificar que o teste compila mas falha** (Red confirmado)

## Validações Pós-Execução

- [ ] Arquivo de teste criado no projeto correto
- [ ] Classe com sufixo `Tests`
- [ ] Pelo menos um `[Fact]` placeholder
- [ ] Estrutura AAA presente (comentários Arrange/Act/Assert)
- [ ] Placeholder de PBT incluído se `test-name` é objeto de valor numérico
