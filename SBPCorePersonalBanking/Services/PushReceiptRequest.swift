//
//  PushReceiptRequest.swift
//  SBPCorePersonalBanking (framework estático)
//
//  Servicio `POST /push-receipt` y su DTO de respuesta. El backend del emisor
//  llama a `GetPushReceipt` de HST y devuelve el id que consume
//  `HP2.executeProvisioning(pushRecId:)`.
//  Se ejecuta con `CoreRequestManager.shared.load(...)`.
//

import Foundation

public struct PushReceiptDTO: Codable {
    public let pushReceiptID: String
    /// Formato HST: `yyyy-MM-ddTHH:mm:ss.SSSZ` (GMT).
    public let receiptExpirationTime: String?
}

public struct PushReceiptRequest: SBPNetworking.Request {
    public typealias Response = PushReceiptDTO
    public let path: String
    public let method: HTTPMethod
    public let body: Data?

    public init(cardID: String) {
        path = "/push-receipt"
        method = .post
        body = try? JSONEncoder().encode(PushReceiptPayload(cardID: cardID))
    }
}

private struct PushReceiptPayload: Encodable {
    let cardID: String
}
