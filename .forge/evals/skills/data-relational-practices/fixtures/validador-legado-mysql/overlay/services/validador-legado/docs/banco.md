# Banco do validador-legado

MySQL 8.4 (InnoDB), instância única. A tabela `validacoes` tem cerca de 180 milhões de linhas e recebe escrita contínua dos validadores embarcados (pico de 2 mil inserções por segundo). Não há janela de manutenção: o serviço fica no ar 24x7.

O isolamento usado é o default do InnoDB, que é READ COMMITTED como no Postgres, então as leituras de conciliação não precisam de cuidado extra.
