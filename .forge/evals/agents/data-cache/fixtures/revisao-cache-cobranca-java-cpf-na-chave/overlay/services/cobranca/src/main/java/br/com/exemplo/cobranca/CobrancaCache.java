package br.com.exemplo.cobranca;

import com.github.benmanes.caffeine.cache.Cache;
import com.github.benmanes.caffeine.cache.Caffeine;
import org.springframework.data.redis.core.StringRedisTemplate;

public class CobrancaCache {

    private final StringRedisTemplate redis;

    private final Cache<String, Titular> titulares = Caffeine.newBuilder()
            .maximumSize(50_000)
            .recordStats()
            .build();

    public CobrancaCache(StringRedisTemplate redis) {
        this.redis = redis;
    }

    public void guardarTitular(String tenant, String cpf, Titular titular) {
        String chave = "tenant:" + tenant + ":titular:" + cpf;
        redis.opsForValue().set(chave, titular.toJson());
        titulares.put(chave, titular);
    }

    public Titular lerTitular(String tenant, String cpf) {
        String chave = "tenant:" + tenant + ":titular:" + cpf;
        Titular local = titulares.getIfPresent(chave);
        if (local != null) {
            return local;
        }
        String json = redis.opsForValue().get(chave);
        return json == null ? null : Titular.fromJson(json);
    }
}
