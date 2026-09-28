channel.consume(q, async (msg) => { // w250:contexto
  catch (e) { channel.nack(msg, false) }
}); // w250:contexto
channel.reject(msg);
