//
//  URLHandler.swift
//  Mlem
//
//  Created by Nicholas Lawson on 10/06/2023.
//

import SwiftUI
import SafariServices

/// A class that provides handling behaviour for `URL` actions
class URLHandler {

    /// The type of action to perform in response to the URL
    enum Action {
        case error(String)
    }

    struct Result {
        let result: OpenURLAction.Result
        let action: Action?
    }

    @available(*, unavailable, message: "This handler should not be instantiated, please use static methods.")
    init() { /* class should not be instantiated */ }

    /// A method to perform handling on URLs within the application
    /// - Parameter url: The `URL` you require to be handled
    /// - Returns: A `Result` containing to the system level `OpenURLAction.Result` and any application level actions to perform
    static func handle(_ url: URL) -> Result {
        guard let scheme = url.scheme, scheme.hasPrefix("http") else {
            return .init(result: .systemAction, action: .error("This type of link is not currently supported 😞"))
        }

        Task { @MainActor in
            let viewController = SFSafariViewController(url: url, configuration: .default)
            UIApplication.shared.firstKeyWindow?.rootViewController?.present(viewController, animated: true)
        }
        
        return .init(result: .handled, action: nil)
    }
}

extension SFSafariViewController.Configuration {
    /// The default settings used in this application
    static var `default`: Self {
        let configuration = Self.init()
        configuration.entersReaderIfAvailable = false
        return configuration
    }
}
