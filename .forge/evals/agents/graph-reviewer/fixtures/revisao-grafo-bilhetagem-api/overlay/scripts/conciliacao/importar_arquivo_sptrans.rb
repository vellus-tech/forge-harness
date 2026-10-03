require_relative 'layout_cnab'
require_relative 'lancamento'
class ImportarArquivo
  def call(path) = File.readlines(path).map { |l| Lancamento.new(LayoutCnab.parse(l)) }
end
