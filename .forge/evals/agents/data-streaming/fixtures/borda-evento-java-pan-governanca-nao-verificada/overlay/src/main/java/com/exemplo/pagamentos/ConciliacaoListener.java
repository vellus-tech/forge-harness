package com.exemplo.pagamentos;

import com.exemplo.pagamentos.eventos.PagamentoAprovado;
import org.springframework.amqp.rabbit.annotation.RabbitListener;
import org.springframework.stereotype.Component;

@Component
public class ConciliacaoListener {

    private final ConciliacaoService conciliacao;

    public ConciliacaoListener(ConciliacaoService conciliacao) {
        this.conciliacao = conciliacao;
    }

    @RabbitListener(queues = "conciliacao.pagamento-aprovado")
    public void onPagamentoAprovado(PagamentoAprovado evento) {
        conciliacao.registrar(evento);
    }
}
