package br.com.axis.tarifa;

import static org.jooq.impl.DSL.condition;
import static org.jooq.impl.DSL.field;
import static org.jooq.impl.DSL.table;

import jakarta.inject.Singleton;
import java.util.List;
import org.jooq.DSLContext;

@Singleton
public class TarifaRepository {

    private final DSLContext dsl;

    public TarifaRepository(DSLContext dsl) {
        this.dsl = dsl;
    }

    public List<Tarifa> porLinhaEModal(String linha, String modal) {
        return dsl.select(field("id"), field("linha"), field("modal"), field("valor_centavos"), field("valor_integracao_centavos"))
                .from(table("tarifa"))
                .where(condition("linha = '" + linha + "' AND modal = '" + modal + "'"))
                .fetchInto(Tarifa.class);
    }
}
