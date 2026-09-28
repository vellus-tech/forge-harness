module LayoutCnab
  def self.parse(linha) = { cartao: linha[0, 16], valor: linha[16, 10].to_i }
end
