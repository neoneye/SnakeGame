// MIT license. Copyright (c) 2020 Simon Strandgaard. All rights reserved.
import Foundation
import Combine
import SwiftUI

#if os(iOS)
import EngineIOS
#elseif os(macOS)
import EngineMac
#else
#error("Unknown OS")
#endif

#if os(macOS)
// Environment key to hold even publisher
struct WindowEventPublisherKey: EnvironmentKey {
    static let defaultValue: AnyPublisher<NSEvent, Never> =
        Just(NSEvent()).eraseToAnyPublisher() // just default stub
}


// Environment value for keyPublisher access
extension EnvironmentValues {
    var keyPublisher: AnyPublisher<NSEvent, Never> {
        get { self[WindowEventPublisherKey.self] }
        set { self[WindowEventPublisherKey.self] = newValue }
    }
}
#endif

public class GameViewModel: ObservableObject {
    public let jumpToLevelSelector = PassthroughSubject<Void, Never>()
    public let userInterfaceStyle = PassthroughSubject<Void, Never>()
    @Published var player1Length: UInt = 1
    @Published var player2Length: UInt = 1
    @Published var player1Info = "Player 1 (green)\nAlive\nLength 29"
    @Published var player2Info = "Player 2 (blue)\nDead by collision with wall\nLength 14"
    @Published var showPauseButton: Bool = true
    @Published var levelSelector_humanVsBot = true
    @Published var levelSelector_visible = true
    @Published var levelSelector_insetTop: CGFloat = 0
    @Published var player1SnakeBody: SnakeBody = SnakeBody.empty()
    private let snakeGameEnvironment: SnakeGameEnvironment

    #if os(iOS)
    @Published var iOS_soundEffectsEnabled: Bool = SoundEffectController().value {
        didSet { SoundEffectController().set(self.iOS_soundEffectsEnabled) }
    }
    #endif

    init(snakeGameEnvironment: SnakeGameEnvironment) {
        self.snakeGameEnvironment = snakeGameEnvironment
    }

    static func create() -> GameViewModel {
        let gameState = SnakeGameState.create(
            player1: .human,
            player2: .none,
            levelName: "Level 0.csv"
        )
        let snakeGameEnvironment: SnakeGameEnvironment = SnakeGameEnvironmentInteractive(
            initialGameState: gameState
        )
        return GameViewModel(snakeGameEnvironment: snakeGameEnvironment)
    }

    func sendInfoEvent(_ event: SnakeGameInfoEvent) {
        switch event {
        case .showLevelSelector:
            player1Info = ""
            player2Info = ""
            player1Length = 0
            player2Length = 0
            showPauseButton = false
        case let .showLevelDetail(gameState):
            player1Info = gameState.player1.humanReadableRole
            player2Info = gameState.player2.humanReadableRole
            player1Length = gameState.player1.lengthOfInstalledSnake()
            player2Length = gameState.player2.lengthOfInstalledSnake()
        case let .beginNewGame(gameState):
            player1Info = gameState.player1.humanReadableRole
            player2Info = gameState.player2.humanReadableRole
            player1Length = gameState.player1.lengthOfInstalledSnake()
            player2Length = gameState.player2.lengthOfInstalledSnake()
            showPauseButton = true
        case let .player1_didUpdateLength(length):
            player1Length = length
        case let .player2_didUpdateLength(length):
            player2Length = length
        case let .player1_dead(causesOfDeath):
            let deathExplanations: [String] = causesOfDeath.map { $0.humanReadableDeathExplanation }
            let info: String = deathExplanations.joined(separator: "\n-\n")
            player1Info = info
        case let .player2_dead(causesOfDeath):
            let deathExplanations: [String] = causesOfDeath.map { $0.humanReadableDeathExplanation }
            let info: String = deathExplanations.joined(separator: "\n-\n")
            player2Info = info
        }
    }

}
