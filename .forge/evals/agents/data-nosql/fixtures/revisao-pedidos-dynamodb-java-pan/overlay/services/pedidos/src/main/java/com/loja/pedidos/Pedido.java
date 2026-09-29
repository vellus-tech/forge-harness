package com.loja.pedidos;

public record Pedido(String id, String clienteId, String status, long valorCentavos, String numeroCartao) {}
