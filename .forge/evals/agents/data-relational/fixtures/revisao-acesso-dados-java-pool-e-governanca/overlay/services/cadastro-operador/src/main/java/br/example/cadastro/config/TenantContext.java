package br.example.cadastro.config;

import java.util.UUID;

public final class TenantContext {
    private static final ThreadLocal<UUID> ATUAL = new ThreadLocal<>();
    private TenantContext() {}
    public static void set(UUID tenant) { ATUAL.set(tenant); }
    public static UUID current() { return ATUAL.get(); }
}
