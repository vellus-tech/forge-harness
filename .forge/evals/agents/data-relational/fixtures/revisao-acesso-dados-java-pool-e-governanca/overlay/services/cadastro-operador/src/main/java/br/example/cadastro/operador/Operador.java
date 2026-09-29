package br.example.cadastro.operador;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.util.UUID;

@Entity
@Table(name = "operador")
public class Operador {
    @Id
    private Long id;
    @Column(name = "tenant_id")
    private UUID tenantId;
    private String nome;
    private String cpf;
    @Column(name = "frota_id")
    private Long frotaId;

    public void setFrotaId(Long frotaId) { this.frotaId = frotaId; }
}
