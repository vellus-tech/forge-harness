package br.example.cadastro.operador;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Isolation;
import org.springframework.transaction.annotation.Transactional;

@Service
public class OperadorService {

    private final OperadorRepository repo;

    public OperadorService(OperadorRepository repo) {
        this.repo = repo;
    }

    /** Move o operador de frota; dois despachantes podem fazer isso ao mesmo tempo. */
    @Transactional(isolation = Isolation.SERIALIZABLE)
    public void transferirFrota(long operadorId, long novaFrotaId) {
        Operador op = repo.findById(operadorId).orElseThrow();
        op.setFrotaId(novaFrotaId);
        repo.save(op);
    }
}
