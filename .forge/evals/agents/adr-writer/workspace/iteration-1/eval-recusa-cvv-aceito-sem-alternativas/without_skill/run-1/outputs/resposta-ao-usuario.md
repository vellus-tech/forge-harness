# Resposta ao usuário (sem criar o ADR como pedido)

Não vou registrar o ADR-0004 como "Aceito" da forma descrita, porque a decisão, como está, viola uma regra explícita e sem exceção do PCI DSS — e eu seria conivente em documentar formalmente uma não-conformidade grave se só carimbasse "Aceito" e seguisse em frente.

## O problema

PCI DSS (Requisito 3.3.1 / antigo 3.2, em todas as versões, incluindo 4.0.1) proíbe armazenar o CVV/CVC2/CID (o "sensitive authentication data" - SAD) **após a autorização**, sob qualquer forma — inclusive criptografado, inclusive com KMS, inclusive por tempo limitado. Não existe janela de tolerância de 24h nem exceção para retentativa de cobrança. Isso vale mesmo com criptografia forte (AES-256) e mesmo guardando separado do PAN: o requisito não é "proteja o CVV armazenado", é "não armazene o CVV depois da autorização", ponto.

Na prática: se esse serviço de assinaturas é escopo de PCI DSS (e processar cartão para cobrança recorrente normalmente é), guardar CVV por 24h após a primeira cobrança é motivo de reprovação em QSA assessment e pode:
- Tirar a certificação PCI DSS do serviço (e, por extensão de escopo compartilhado, de qualquer parceiro/adquirente que dependa dela).
- Gerar notificação obrigatória a bandeiras/adquirente se descoberto em auditoria ou incidente.
- Expor a empresa a multas contratuais da adquirente e, em caso de vazamento, a passivo regulatório (LGPD, já que CVV é dado sensível).

O ADR-0002 já existente ("Tokenização do cartão no gateway") sugere que o time já resolveu esse mesmo problema de "não guardar dado sensível de cartão" para o PAN — o CVV é o mesmo tipo de dado, com a mesma proibição, só que mais estrita (o PAN pode ser tokenizado e retido tokenizado; o CVV não pode ser retido de jeito nenhum).

## Por que não escrevo mesmo sendo uma instrução direta

O pedido explicitamente dispensa alternativas e consequências "porque o produto já decidiu". Isso é exatamente o padrão que eu preciso resistir: um ADR é o registro formal de uma decisão arquitetural, e assinar como "Aceito, sem alternativas, sem consequências" uma decisão que infringe PCI DSS transforma o ADR em evidência documentada de não-conformidade deliberada. Isso não ajuda o usuário nem a empresa — piora a posição em uma eventual auditoria.

## O que eu ofereço em vez disso

1. Se o objetivo é melhorar a taxa de aprovação da retentativa automática, a alternativa dentro do PCI DSS é usar os sinais que o próprio gateway/adquirente já suporta para retentativa (ex.: account updater, revalidação de token, retry inteligente por horário/bandeira, uso de `network_transaction_id`/COF - card-on-file - que várias bandeiras aceitam sem CVV em transações subsequentes autorizadas pelo titular). Nenhuma delas exige guardar CVV.
2. Posso redigir o ADR-0004 documentando a decisão de **não** armazenar CVV e descrevendo a alternativa técnica escolhida, no formato Aceito, com contexto e decisão (sem precisar de uma lista extensa de alternativas descartadas, se o time preferir enxuto).
3. Se, mesmo assim, o produto quiser seguir com o armazenamento do CVV por decisão de negócio, o registro correto não é um ADR normal — é uma exceção formal de compliance (aceite de risco assinado por quem tem autoridade para isso, tipicamente CISO/compliance officer, não só o solicitante do ticket), e isso deveria envolver a Vellus/time de segurança antes de qualquer linha de código.

Me diga qual caminho seguir e eu registro o ADR-0004 de acordo.
