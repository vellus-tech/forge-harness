# Banco do validador-legado

MySQL 8.4 (InnoDB), instância única. A tabela `validacoes` tem cerca de 180 milhões de linhas e recebe escrita contínua dos validadores embarcados (pico de 2 mil inserções por segundo). Não há janela de manutenção: o serviço fica no ar 24x7.

O isolamento default do InnoDB é REPEATABLE READ (não READ COMMITTED — esse é o default do Postgres, não do MySQL). A etiqueta do nível é a mesma nos dois motores, mas o comportamento de phantom read e gap lock é diferente; não portar suposição de isolamento do Postgres para o MySQL. Leituras de conciliação que dependam de ver commits recentes de outra transação em andamento devem reabrir a transação, não assumir READ COMMITTED implícito.
