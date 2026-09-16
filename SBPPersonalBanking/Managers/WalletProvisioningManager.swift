//
//  WalletProvisioningManager.swift
//  DemoAppleWallet
//
//  API in-app para agregar una tarjeta a Wallet. Delega en el `WalletEngine`
//  activo: en device el SDK presenta el sheet real de Apple Pay; en simulador el
//  mock lo simula con un alert.
//

import UIKit
import PassKit
import SBPCorePersonalBanking
import SBPShared

final class WalletProvisioningManager: NSObject {

    /// Id emitido por HST para un alta concreta (opciones A/B).
    struct PushReceipt {
        /// Vigencia documentada por HST para `GetPushReceipt`.
        static let validity: TimeInterval = 15 * 60

        let id: String
        let cardID: String
        let expiresAt: Date

        var isExpired: Bool { Date() >= expiresAt }
    }

    private let engine: WalletEngineProtocol

    init(engine: WalletEngineProtocol = WalletEngineProvider.current) {
        self.engine = engine
        super.init()
    }

    /// Indica si el dispositivo/cuenta actual puede añadir pases de pago. Devuelve:
    /// `false` en el simulador y en dispositivos no compatibles con Apple Pay.
    static var canAddPayments: Bool {
        PKAddPaymentPassViewController.canAddPaymentPass()
    }

    /// Inicia el alta de la tarjeta con su `encCard` (real o simulada según el backend).
    func startProvisioning(for card: WalletCard,
                           from presenter: UIViewController,
                           completion: @escaping (ProvisioningOutcome) -> Void) {
        engine.startInAppProvisioning(card: card, from: presenter, completion: completion)
    }

    // MARK: - Alta con pushReceiptID

    /// Pide al backend del emisor un `pushReceiptID` para la tarjeta. La red vive
    /// aquí y no en el engine: `SBPShared` también corre en las extensiones y no
    /// depende de `SBPCorePersonalBanking`.
    func requestPushReceipt(for card: WalletCard) async throws -> PushReceipt {
        let dto = try await CoreRequestManager.shared.load(PushReceiptRequest(cardID: card.cardID))
        return PushReceipt(id: dto.pushReceiptID,
                           cardID: card.cardID,
                           expiresAt: Self.expirationDate(from: dto.receiptExpirationTime))
    }

    /// Inicia el alta canjeando un `pushReceiptID` vigente.
    func startProvisioning(for card: WalletCard,
                           pushReceiptID: String,
                           from presenter: UIViewController,
                           completion: @escaping (ProvisioningOutcome) -> Void) {
        engine.startInAppProvisioning(card: card,
                                      pushReceiptID: pushReceiptID,
                                      from: presenter,
                                      completion: completion)
    }

    /// Si el backend no envía la expiración o no se puede leer, se asume la vigencia de HST.
    private static func expirationDate(from value: String?) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return value.flatMap(formatter.date(from:)) ?? Date().addingTimeInterval(PushReceipt.validity)
    }
}
