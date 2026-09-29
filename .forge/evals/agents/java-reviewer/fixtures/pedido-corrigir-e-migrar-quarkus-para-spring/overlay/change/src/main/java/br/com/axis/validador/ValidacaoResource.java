package br.com.axis.validador;

import jakarta.ws.rs.POST;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.core.Response;
import java.sql.SQLException;

@Path("/validacoes")
public class ValidacaoResource {

    private final ListaRestritivaCache listaRestritiva;

    public ValidacaoResource(ListaRestritivaCache listaRestritiva) {
        this.listaRestritiva = listaRestritiva;
    }

    @POST
    public Response validar(Embarque embarque) throws SQLException {
        if (listaRestritiva.bloqueado(embarque.cartaoId())) {
            return Response.status(Response.Status.FORBIDDEN).build();
        }
        return Response.accepted().build();
    }
}
