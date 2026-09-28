if (msg.fields.redelivered) { ch.ack(msg); return; }
