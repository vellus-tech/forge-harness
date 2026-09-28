package br.com.axis.bilhetagem.recarga;

import br.com.axis.bilhetagem.cartao.Cartao;
import br.com.axis.bilhetagem.cartao.CartaoRepository;
import java.util.ArrayList;
import java.util.List;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class RecargaService {

    @Autowired
    private RecargaHistoricoQuery historicoQuery;

    @Autowired
    private CartaoRepository cartaoRepository;

    @Transactional
    public Recarga recarregar(RecargaRequest request) {
        return historicoQuery.inserir(request.cartaoId(), request.valorCentavos());
    }

    @Transactional(readOnly = true)
    public List<RecargaHistoricoItem> historico(long cartaoId, String status) {
        List<RecargaHistoricoItem> itens = new ArrayList<>();
        for (Recarga recarga : historicoQuery.listar(cartaoId, status)) {
            Cartao cartao = cartaoRepository.findById(recarga.cartaoId()).orElseThrow();
            itens.add(new RecargaHistoricoItem(recarga, cartao.numeroMascarado()));
        }
        return itens;
    }
}
