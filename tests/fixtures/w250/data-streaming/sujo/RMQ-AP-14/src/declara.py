canal.queue_declare(queue="pagamentos", arguments={"x-dead-letter-exchange": "pagamentos.dlx"})
