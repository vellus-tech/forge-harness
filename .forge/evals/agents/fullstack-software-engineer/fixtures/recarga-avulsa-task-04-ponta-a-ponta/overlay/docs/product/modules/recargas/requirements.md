# Requisitos — módulo recargas

- **REQ-01** — O usuário consulta o histórico de recargas do cartão (entregue).
- **REQ-02** — O usuário solicita uma recarga avulsa informando o valor. Valor mínimo R$ 1,00 e máximo R$ 500,00. Valor fora da faixa é rejeitado com mensagem clara.
- **REQ-03** — Um mesmo pedido de recarga reenviado (duplo clique, retry de rede) não pode gerar duas recargas.
- **REQ-04** — Enquanto a solicitação está em andamento o formulário fica bloqueado; erros são exibidos de forma acessível a leitores de tela.
