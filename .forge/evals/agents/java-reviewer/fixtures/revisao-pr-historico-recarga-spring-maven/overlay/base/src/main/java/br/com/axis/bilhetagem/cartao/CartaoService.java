package br.com.axis.bilhetagem.cartao;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class CartaoService {

    private final CartaoRepository cartaoRepository;

    public CartaoService(CartaoRepository cartaoRepository) {
        this.cartaoRepository = cartaoRepository;
    }

    @Transactional(readOnly = true)
    public Cartao buscarDoTitular(long cartaoId, String titularId) {
        Cartao cartao = cartaoRepository.findById(cartaoId).orElseThrow(CartaoNaoEncontradoException::new);
        if (!cartao.titularId().equals(titularId)) {
            throw new CartaoNaoEncontradoException();
        }
        return cartao;
    }
}
