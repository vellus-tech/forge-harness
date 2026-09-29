// Bootstrap da conexão AMQP: uma conexão por processo, aberta na subida do serviço.
const amqp = require('amqplib');

let conexao;

async function iniciar() {
  conexao = await amqp.connect(process.env.AMQP_URL);
  const canal = await conexao.createChannel();
  return { conexao, canal };
}

module.exports = { iniciar };
