import Foundation

// Orquestra a recarga via Pix: chama RecargaService e publica o QR Code para RecargaView.
final class RecargaViewModel {
    private let service: RecargaService
    init(service: RecargaService) { self.service = service }
    func solicitar(cartao: Cartao, valorCentavos: Int) async throws -> Recarga {
        try await service.criarRecargaPix(cartao: cartao, valorCentavos: valorCentavos)
    }
}
