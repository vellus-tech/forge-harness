package br.com.axis.bilhetagem.recarga;

import java.util.List;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1")
public class RecargaController {

    private final RecargaService recargaService;

    public RecargaController(RecargaService recargaService) {
        this.recargaService = recargaService;
    }

    @PostMapping("/recargas")
    public ResponseEntity<Recarga> recarregar(@RequestBody RecargaRequest request) {
        return ResponseEntity.ok(recargaService.recarregar(request));
    }

    @GetMapping("/cartoes/{cartaoId}/recargas")
    public List<RecargaHistoricoItem> historico(@PathVariable long cartaoId,
                                                @RequestParam(defaultValue = "CONFIRMADA") String status) {
        return recargaService.historico(cartaoId, status);
    }
}
