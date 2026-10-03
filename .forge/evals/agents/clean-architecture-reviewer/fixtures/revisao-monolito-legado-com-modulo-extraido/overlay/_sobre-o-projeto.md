
## Sobre o Projeto

Plataforma de bilhetagem eletrônica do transporte coletivo. O repositório convive com dois formatos. O legado `src/Legacy.Bilhetagem` é um monolito .NET (um único projeto com `Models/` e `Services/`, EF Core com data annotations nas entidades) que **não** segue Clean Architecture pura: ele é regido pela ADR-0007 (migração estrangulada), que congela o legado — só correção de bug, sem refatoração estrutural, entidades anêmicas e atributos de mapeamento são aceitos ali até a extração. Todo código novo nasce em módulos extraídos no formato canônico por serviço (`Api`/`Application`/`Domain`/`Infrastructure`/`Contracts`), hoje apenas `src/Validacao` (validação de embarque no validador embarcado).
