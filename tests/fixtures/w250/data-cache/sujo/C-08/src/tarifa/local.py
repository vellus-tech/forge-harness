@lru_cache(maxsize=1024)
def tarifa_vigente(linha):
    return consultar(linha)
