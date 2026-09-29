package com.exemplo.pagamentos;

import com.exemplo.pagamentos.eventos.PagamentoAprovado;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.stereotype.Component;

@Component
public class PagamentoAprovadoPublisher {

    private final RabbitTemplate rabbitTemplate;

    public PagamentoAprovadoPublisher(RabbitTemplate rabbitTemplate) {
        this.rabbitTemplate = rabbitTemplate;
    }

    public void publicar(Pagamento pagamento) {
        PagamentoAprovado evento = PagamentoAprovado.newBuilder()
            .setPagamentoId(pagamento.getId())
            .setPan(pagamento.getCartao().getNumero())
            .setNomeTitular(pagamento.getCartao().getNomeTitular())
            .setCpfTitular(pagamento.getCliente().getCpf())
            .setValor(pagamento.getValor().doubleValue())
            .setAprovadoEm(System.currentTimeMillis())
            .build();
        rabbitTemplate.convertAndSend("pagamentos", "pagamento.aprovado", evento);
    }
}
