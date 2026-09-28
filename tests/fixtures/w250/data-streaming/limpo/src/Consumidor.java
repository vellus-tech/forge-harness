channel.basicConsume("pagamentos", false, consumidor);
channel.basicQos(50);
channel.basicNack(tag, false, false);
argumentos.put("x-queue-type", "quorum");
channel.queueDeclare("pagamentos", true, false, false, argumentos);
producer.send(new ProducerRecord<>("pedidos", chave, valor));
