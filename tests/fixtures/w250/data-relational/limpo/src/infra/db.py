listener = criar_listener()
cursor.execute("SELECT id, nome FROM parametro WHERE chave = %s", (chave,))
