canal.confirm_delivery()
canal.basic_publish(exchange="dominio.eventos", routing_key="pedido.criado", body=corpo, properties=pika.BasicProperties(delivery_mode=2))
canal.basic_nack(tag, requeue=False)
canal.basic_consume(queue="pagamentos", on_message_callback=tratar, auto_ack=False)
