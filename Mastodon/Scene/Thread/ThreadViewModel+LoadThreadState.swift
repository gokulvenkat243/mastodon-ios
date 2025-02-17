//
//  ThreadViewModel+LoadThreadState.swift
//  Mastodon
//
//  Created by MainasuK Cirno on 2021-4-12.
//

import Foundation
import Combine
import GameplayKit
import CoreDataStack
import MastodonSDK
import MastodonCore

extension ThreadViewModel {
    class LoadThreadState: GKState {
        
        let id = UUID()
        
        weak var viewModel: ThreadViewModel?
                
        init(viewModel: ThreadViewModel) {
            self.viewModel = viewModel
        }
        
        @MainActor
        func enter(state: LoadThreadState.Type) {
            stateMachine?.enter(state)
        }
    }
}

extension ThreadViewModel.LoadThreadState {
    class Initial: ThreadViewModel.LoadThreadState {
        override func isValidNextState(_ stateClass: AnyClass) -> Bool {
            switch stateClass {
            case is Loading.Type:   return true
            default:                return false
            }
        }
    }
    
    class Loading: ThreadViewModel.LoadThreadState {
        override func isValidNextState(_ stateClass: AnyClass) -> Bool {
            switch stateClass {
            case is Fail.Type:      return true
            case is NoMore.Type:    return true
            default:                return false
            }
        }
        
        override func didEnter(from previousState: GKState?) {
            super.didEnter(from: previousState)

            guard let viewModel, let stateMachine else { return }
            
            
            Task { @MainActor in
                guard let threadContext = viewModel.threadContext else {
                    stateMachine.enter(Fail.self)
                    return
                }
                do {
                    let response = try await APIService.shared.statusContext(
                        statusID: threadContext.statusID,
                        authenticationBox: viewModel.authenticationBox
                    )

                    enter(state: NoMore.self)
                    
                    // assert(!Thread.isMainThread)
                    // await Task.sleep(1_000_000_000)     // 1s delay to prevent UI render issue

                    _ = try await APIService.shared.getHistory(forStatusID: threadContext.statusID,
                                                                                          authenticationBox: viewModel.authenticationBox)
                    
                    await viewModel.mastodonStatusThreadViewModel.appendAncestor(
                        nodes: MastodonStatusThreadViewModel.Node.replyToThread(
                            for: threadContext.replyToID,
                            from: response.value.ancestors
                        )
                    )

                    await viewModel.mastodonStatusThreadViewModel.appendDescendant(
                        nodes: response.value.descendants.map { status in
                            return .init(status: .fromEntity(status), children: [])
                        }
                    )
                } catch {
                    enter(state: Fail.self)
                }
            }   // end Task
        }

    }
    
    class Fail: ThreadViewModel.LoadThreadState {
        override func isValidNextState(_ stateClass: AnyClass) -> Bool {
            switch stateClass {
            case is Loading.Type:   return true
            default:                return false
            }
        }
        
        override func didEnter(from previousState: GKState?) {
            super.didEnter(from: previousState)
            
            guard let _ = viewModel, let stateMachine = stateMachine else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                stateMachine.enter(Loading.self)
            }
        }
    }
    
    class NoMore: ThreadViewModel.LoadThreadState {
        override func isValidNextState(_ stateClass: AnyClass) -> Bool {
            stateClass is Loading.Type
        }
    }
}
