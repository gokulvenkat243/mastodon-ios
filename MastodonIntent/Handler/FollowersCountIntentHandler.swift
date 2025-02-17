// Copyright © 2023 Mastodon gGmbH. All rights reserved.

import Foundation
import Intents
import MastodonCore
import MastodonSDK
import MastodonLocalization

@MainActor
class FollowersCountIntentHandler: INExtension, FollowersCountIntentHandling {
    func resolveShowChart(for intent: FollowersCountIntent) async -> INBooleanResolutionResult {
        return .success(with: intent.showChart?.boolValue ?? false)
    }
    
    func resolveAccount(for intent: FollowersCountIntent) async -> INStringResolutionResult {
        .confirmationRequired(with: intent.account)
    }

    func provideAccountOptionsCollection(for intent: FollowersCountIntent, searchTerm: String?) async throws -> INObjectCollection<NSString> {
        guard
            let searchTerm = searchTerm,
            let authenticationBox = AuthenticationServiceProvider.shared.currentActiveUser.value
        else {
            return INObjectCollection(items: [])
        }

        let results = try await APIService.shared
            .search(query: .init(q: searchTerm), authenticationBox: authenticationBox)
        
        return INObjectCollection(items: results.value.accounts.map { $0.acctWithDomainIfMissing(authenticationBox.domain) as NSString })
    }
}
