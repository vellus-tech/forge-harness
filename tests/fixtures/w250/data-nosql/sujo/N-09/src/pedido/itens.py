tabela.update_item(Key=chave, UpdateExpression="SET itens = list_append(itens, :novo)")
