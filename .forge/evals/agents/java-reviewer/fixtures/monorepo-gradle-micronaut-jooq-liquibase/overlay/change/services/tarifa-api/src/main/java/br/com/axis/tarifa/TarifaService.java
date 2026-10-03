package br.com.axis.tarifa;

import io.micronaut.transaction.annotation.Transactional;
import jakarta.inject.Singleton;
import java.util.List;

@Singleton
public class TarifaService {

    private final TarifaRepository tarifaRepository;

    public TarifaService(TarifaRepository tarifaRepository) {
        this.tarifaRepository = tarifaRepository;
    }

    @Transactional
    public List<Tarifa> tarifasIntegradas(String linha, String modal) {
        return tarifaRepository.porLinhaEModal(linha, modal);
    }
}
