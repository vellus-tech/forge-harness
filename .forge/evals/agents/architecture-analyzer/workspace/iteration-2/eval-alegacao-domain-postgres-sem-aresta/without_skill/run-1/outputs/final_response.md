Não encontrei a violação domain → infrastructure. Em src/domain/tarifa.ts não há import nem chamada a PostgresTarifaRepository; no grafo, esse arquivo tem uma única aresta, para tabela-tarifaria.ts. A única menção é um comentário TODO(tarifa) nas linhas 3-4, que propõe buscar a tabela direto no repositório, ou seja, uma intenção futura e não o código atual.

O acoplamento real está na camada de aplicação: src/application/calcular-tarifa.ts instancia new PostgresTarifaRepository() diretamente. Isso é inversão de dependência ausente, não violação do domínio. Se o TODO for implementado, aí surge a violação que o tech lead descreveu.

O relatório com o mapa de camadas, os fatos, a interpretação e a recomendação está em docs/arquitetura/analise-tarifacao.md (no workspace da execução). Recomendo registrar na retro que não há violação domain → infrastructure hoje, abrir item de dívida para a inversão na aplicação e reescrever o TODO.

Limitação: o grafo resolve só imports estáticos; a verificação complementar foi busca textual. Testes e forge doctor não foram executados (sem rede).
