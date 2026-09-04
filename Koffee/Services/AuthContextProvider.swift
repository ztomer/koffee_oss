import Foundation
import AuthenticationServices
import AppKit

@MainActor
final class AuthContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = AuthContextProvider()

    private override init() {
        super.init()
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return ASPresentationAnchor()
    }
}
