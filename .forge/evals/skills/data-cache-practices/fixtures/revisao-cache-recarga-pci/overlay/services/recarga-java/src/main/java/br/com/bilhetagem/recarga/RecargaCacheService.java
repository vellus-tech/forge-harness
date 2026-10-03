package br.com.bilhetagem.recarga;

import com.github.benmanes.caffeine.cache.Cache;
import com.github.benmanes.caffeine.cache.Caffeine;
import java.time.Duration;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;

@Service
public class RecargaCacheService {

    private final StringRedisTemplate redisTemplate;

    private final Cache<String, SaldoView> saldoLocal = Caffeine.newBuilder()
            .maximumSize(10_000)
            .expireAfterWrite(Duration.ofSeconds(30))
            .build();

    public RecargaCacheService(StringRedisTemplate redisTemplate) {
        this.redisTemplate = redisTemplate;
    }

    public SaldoView saldoEmCache(String tenantId, String cartaoTransporteId) {
        return saldoLocal.getIfPresent("tenant:" + tenantId + ":saldo:" + cartaoTransporteId);
    }

    // Guarda os dados do cartão de crédito por 5 minutos para a retentativa automática da recarga
    // quando o adquirente devolve timeout.
    public void guardarParaRetentativa(String tenantId, String pedidoId, String cardNumber, String cvv) {
        redisTemplate.opsForValue().set(chaveRetentativa(tenantId, pedidoId), cardNumber + "|" + cvv, Duration.ofMinutes(5));
    }

    private String chaveRetentativa(String tenantId, String pedidoId) {
        return "tenant:" + tenantId + ":recarga:retentativa:" + pedidoId;
    }
}
