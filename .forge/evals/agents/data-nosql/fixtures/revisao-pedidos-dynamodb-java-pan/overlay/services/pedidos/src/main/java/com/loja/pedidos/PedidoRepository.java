package com.loja.pedidos;

import java.util.List;
import java.util.Map;
import software.amazon.awssdk.services.dynamodb.DynamoDbClient;
import software.amazon.awssdk.services.dynamodb.model.AttributeValue;
import software.amazon.awssdk.services.dynamodb.model.PutItemRequest;
import software.amazon.awssdk.services.dynamodb.model.QueryRequest;
import software.amazon.awssdk.services.dynamodb.model.ScanRequest;

public class PedidoRepository {
    private final DynamoDbClient dynamo;

    public PedidoRepository(DynamoDbClient dynamo) {
        this.dynamo = dynamo;
    }

    public void salvar(Pedido p) {
        dynamo.putItem(PutItemRequest.builder()
            .tableName("pedidos")
            .item(Map.of(
                "status", AttributeValue.fromS(p.status()),
                "pedidoId", AttributeValue.fromS(p.id()),
                "clienteId", AttributeValue.fromS(p.clienteId()),
                "valorCentavos", AttributeValue.fromN(Long.toString(p.valorCentavos())),
                "numeroCartao", AttributeValue.fromS(p.numeroCartao())))
            .build());
    }

    // Chamado pelo endpoint GET /pedidos?clienteId=... a cada abertura do app.
    public List<Map<String, AttributeValue>> ultimosDoCliente(String clienteId) {
        return dynamo.query(QueryRequest.builder()
            .tableName("pedidos")
            .indexName("por-cliente")
            .keyConditionExpression("clienteId = :c")
            .expressionAttributeValues(Map.of(":c", AttributeValue.fromS(clienteId)))
            .consistentRead(true)
            .scanIndexForward(false)
            .limit(20)
            .build()).items();
    }

    // Tela de operação: pedidos pendentes, chamada a cada 5 segundos pelo painel.
    public List<Map<String, AttributeValue>> pendentes() {
        return dynamo.scan(ScanRequest.builder()
            .tableName("pedidos")
            .filterExpression("#s = :p")
            .expressionAttributeNames(Map.of("#s", "status"))
            .expressionAttributeValues(Map.of(":p", AttributeValue.fromS("PENDENTE")))
            .build()).items();
    }
}
