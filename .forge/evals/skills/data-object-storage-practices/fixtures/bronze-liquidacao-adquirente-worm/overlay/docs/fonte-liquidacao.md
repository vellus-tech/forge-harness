# Fonte nova — arquivo de liquidação da adquirente

A adquirente entrega diariamente, via SFTP dela, um arquivo posicional (layout v4) com as transações liquidadas do dia anterior. Registro tipo 1 é o header do lote. Registro tipo 2 é a transação: NSU, data e hora, valor em centavos, bandeira, PAN completo (16 a 19 dígitos, sem máscara), data de validade do cartão, código de autorização e nome do portador. Registro tipo 9 é o trailer.

O jurídico pede que o arquivo original seja guardado exatamente como chegou por 18 meses, para contestação de chargeback; depois desse prazo ele deve ser eliminado. Não há obrigação legal de retenção maior que isso registrada para esta fonte.

O export diário do cadastro de passageiros (`bronze/cadastro/`) contém nome, CPF, e-mail e telefone.
