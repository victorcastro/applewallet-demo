import Foundation
import SBPShared

final class MenuViewModel {

    var hasLocalUser: Bool {
        cookieJoy?.isEmpty == false
    }

    var isFaceIDEnabled: Bool {
        hasLocalUser && SBPLocalStore.bool(forKey: .faceIDEnabled)
    }
    
    private var cookieJoy: String? {
        SBPSecureStore.string(forKey: .cookieJoy)
    }
    
    func resetCards() {
        WalletCardRepository.shared.resetAllData()
    }

    func setFaceIDEnabled(_ enabled: Bool) {
        guard hasLocalUser else {
            SBPLocalStore.remove(.faceIDEnabled)
            return
        }
        SBPLocalStore.set(enabled, forKey: .faceIDEnabled)
    }
}
