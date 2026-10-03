package br.com.axis.validador;

import jakarta.ws.rs.POST;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.core.Response;
import java.sql.SQLException;
import org.jboss.logging.Logger;

@Path("/validacoes")
public class ValidacaoResource {

    private static final Logger LOG = Logger.getLogger(ValidacaoResource.class);

    private final ListaRestritivaCache listaRestritiva;

    public ValidacaoResource(ListaRestritivaCache listaRestritiva) {
        this.listaRestritiva = listaRestritiva;
    }

    @POST
    public Response validar(Embarque embarque) {
        if (embarque == null || embarque.cartaoId() == null || embarque.cartaoId().isBlank()) {
            return Response.status(Response.Status.BAD_REQUEST).build();
        }
        try {
            if (listaRestritiva.bloqueado(embarque.cartaoId())) {
                return Response.status(Response.Status.FORBIDDEN).build();
            }
            return Response.accepted().build();
        } catch (SQLException e) {
            LOG.error("Falha ao consultar lista restritiva", e);
            return Response.status(Response.Status.SERVICE_UNAVAILABLE).build();
        }
    }
}
