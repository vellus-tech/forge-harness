import Foundation

final class RecargaService {
    private let api: APIClient
    init(api: APIClient) { self.api = api }
    func criarRecargaPix(cartao: Cartao, valorCentavos: Int) async throws -> Recarga { Recarga() }
}
