//
//  CoreRequestManagerTests.swift
//  DemoAppleWalletTests
//
//  Verifica CoreRequestManager + los requests (URLSession) usando un
//  `URLProtocol` de prueba que intercepta las peticiones. Ejercita el camino
//  real de red SIN necesitar Mockoon corriendo.
//

import XCTest
import SBPCorePersonalBanking

final class CoreRequestManagerTests: XCTestCase {

    private func makeManager() -> CoreRequestManager {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        return CoreRequestManager(baseURL: CoreRequestManager.defaultBaseURL,
                                  session: URLSession(configuration: config))
    }

    override func tearDown() {
        StubURLProtocol.handler = nil
        super.tearDown()
    }

    /// encCard de prueba (en producción lo entrega HST; el SDK lo desempaca).
    private static let encCardFixture = "enc-card-fixture-001"

    func testWalletCardsRequestParsesHSTStructure() async throws {
        StubURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.path, "/cards-wallet")
            XCTAssertEqual(request.httpMethod, "GET")
            return (200, Self.cardsJSON)
        }

        let dtos = try await makeManager().load(WalletCardsRequest())

        XCTAssertEqual(dtos.count, 1)
        let dto = try XCTUnwrap(dtos.first)
        XCTAssertEqual(dto.cardID, "card-visa-001")
        XCTAssertEqual(dto.paymentNetwork, "Visa")
        XCTAssertEqual(dto.encCard, Self.encCardFixture)
    }

    func testPushReceiptRequestSendsCardIDAndParsesReceipt() async throws {
        StubURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.path, "/push-receipt")
            XCTAssertEqual(request.httpMethod, "POST")
            return (200, Self.pushReceiptJSON)
        }

        let request = PushReceiptRequest(cardID: "card-visa-001")
        let body = try XCTUnwrap(request.body)
        let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: String])
        XCTAssertEqual(payload["cardID"], "card-visa-001")

        let dto = try await makeManager().load(request)

        XCTAssertEqual(dto.pushReceiptID, "1643ef957-622d-4137-abdf-fa605e81e72c")
        XCTAssertEqual(dto.receiptExpirationTime, "2026-09-16T17:34:06.123Z")
    }

    func testHTTPErrorIsThrown() async {
        StubURLProtocol.handler = { _ in (500, Data("{}".utf8)) }
        do {
            _ = try await makeManager().load(WalletCardsRequest())
            XCTFail("Debió lanzar error en 500")
        } catch {
            // ok
        }
    }

    // MARK: - JSON de prueba

    private static let pushReceiptJSON = Data("""
    {
      "pushReceiptID": "1643ef957-622d-4137-abdf-fa605e81e72c",
      "receiptExpirationTime": "2026-09-16T17:34:06.123Z"
    }
    """.utf8)

    private static let cardsJSON = Data("""
    [
      {
        "cardHolderName": "Victor Castro",
        "cardID": "card-visa-001",
        "cardImageBase64": "iVBORw0KGgo=",
        "cardType": "credit",
        "encCard": "\(encCardFixture)",
        "lastFourDigits": "4821",
        "localizedDescription": "SBP Visa Signature",
        "paymentNetwork": "Visa"
      }
    ]
    """.utf8)
}

// MARK: - URLProtocol de prueba

final class StubURLProtocol: URLProtocol {

    /// Devuelve (statusCode, body) para cada petición.
    nonisolated(unsafe) static var handler: ((URLRequest) -> (Int, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        let (status, data) = handler(request)
        let response = HTTPURLResponse(url: request.url!,
                                       statusCode: status,
                                       httpVersion: "HTTP/1.1",
                                       headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
