// MIT license. Copyright (c) 2020 Simon Strandgaard. All rights reserved.
import Foundation

public protocol SnakeGameExecuter: class {
    func reset()
    func undo()
    func executeStep(_ gameState: SnakeGameState) -> SnakeGameState

    /// Decide about optimal path to get to the food.
    func computeNextBotMovement(_ gameState: SnakeGameState) -> SnakeGameState

    func placeNewFood(_ gameState: SnakeGameState) -> SnakeGameState

    func endOfStep(_ gameState: SnakeGameState) -> SnakeGameState
}


/// Replay the moves of a historic game.
public class SnakeGameExecuterReplay: SnakeGameExecuter {
    public let initialGameState: SnakeGameState
    private let foodPositions: [IntVec2]
    private let player1Positions: [IntVec2]
    private let player2Positions: [IntVec2]

    private init(initialGameState: SnakeGameState, foodPositions: [IntVec2], player1Positions: [IntVec2], player2Positions: [IntVec2]) {
        self.initialGameState = initialGameState
        self.foodPositions = foodPositions
        self.player1Positions = player1Positions
        self.player2Positions = player2Positions
    }

    public static func create() -> SnakeGameExecuterReplay {
        let data: Data = SnakeDatasetBundle.load("1.snakeDataset")
        let model: SnakeGameResultModel
        do {
            model = try SnakeGameResultModel(serializedData: data)
        } catch {
            log.error("Unable to load file: \(error)")
            fatalError()
        }

        guard model.hasLevel else {
            log.error("Expected the file to contain a 'level' snapshot of the board, but got none.")
            fatalError()
        }
        guard model.hasFirstStep else {
            log.error("Expected the file to contain a 'firstStep' snapshot of the board, but got none.")
            fatalError()
        }
        guard model.hasLastStep else {
            log.error("Expected the file to contain a 'lastStep' snapshot of the board, but got none.")
            fatalError()
        }
        log.debug("successfully loaded file")

        let step0: SnakeGameStateStepModel = model.firstStep

        let level: SnakeLevel = createLevel(levelModel: model.level, stepModel: step0)
        log.debug("level: \(level)")
        // IDEA: make use of the loaded level. Pass it on to the IngameScene.
        // IDEA: check hashes of the loaded level with the level in the file system.

        func convert(_ modelPositionArray: [SnakeGameStateModelPosition]) -> [IntVec2] {
            return modelPositionArray.map { IntVec2(x: Int32($0.x), y: Int32($0.y)) }
        }
        let foodPositions: [IntVec2] = convert(model.foodPositions)
        let player1Positions: [IntVec2] = convert(model.playerAPositions)
        let player2Positions: [IntVec2] = convert(model.playerBPositions)

        log.debug("level.id: '\(model.level.uuid)'")
        log.debug("food positions.count: \(foodPositions.count)")
        log.debug("player1 positions.count: \(player1Positions.count)")
        log.debug("player2 positions.count: \(player2Positions.count)")

        let pretty = PrettyPrintArray.simple
        log.debug("player1: \(pretty.format(player1Positions))")
        log.debug("player2: \(pretty.format(player2Positions))")
        log.debug("food: \(pretty.format(foodPositions))")

        // IDEA: validate positions are inside the level coordinates
        // IDEA: validate that none of the snakes overlap with each other
        // IDEA: validate that the snakes only occupy empty cells
        // IDEA: validate that the food is placed on an empty cell

        guard ValidateDistance.manhattanDistanceIsOne(player1Positions) else {
            log.error("Invalid player1 positions. All moves must be by a distance of 1 unit.")
            fatalError()
        }
        guard ValidateDistance.manhattanDistanceIsOne(player2Positions) else {
            log.error("Invalid player2 positions. All moves must be by a distance of 1 unit.")
            fatalError()
        }

        var gameState = SnakeGameState.empty()
        gameState = gameState.stateWithNewLevel(level)

        if player1Positions.count >= 2 {
            var player = SnakePlayer.create(id: .player1, role: .replay)
            player = player.playerWithNewSnakeBody(level.player1_body)
            gameState = gameState.stateWithNewPlayer1(player)
        } else {
            var player = SnakePlayer.create(id: .player1, role: .none)
            player = player.uninstall()
            gameState = gameState.stateWithNewPlayer1(player)
        }

        if player2Positions.count >= 2 {
            var player = SnakePlayer.create(id: .player2, role: .replay)
            player = player.playerWithNewSnakeBody(level.player2_body)
            gameState = gameState.stateWithNewPlayer2(player)
        } else {
            var player = SnakePlayer.create(id: .player2, role: .none)
            player = player.uninstall()
            gameState = gameState.stateWithNewPlayer2(player)
        }

        gameState = gameState.stateWithNewFoodPosition(level.initialFoodPosition.intVec2)

        return SnakeGameExecuterReplay(
            initialGameState: gameState,
            foodPositions: foodPositions,
            player1Positions: player1Positions,
            player2Positions: player2Positions
        )
    }

    static func createLevel(levelModel: SnakeGameStateModelLevel, stepModel: SnakeGameStateStepModel) -> SnakeLevel {
        let uuidString: String = levelModel.uuid
        guard let uuid: UUID = UUID(uuidString: uuidString) else {
            log.error("Expected a valid uuid, but got: '\(uuidString)'")
            fatalError()
        }
        log.debug("level uuid: '\(uuid)'")

        guard levelModel.width > 3 && levelModel.height > 3 else {
            log.error("Expected size of level to be 3 or more, but got less. Cannot create level.")
            fatalError()
        }
        let size = UIntVec2(x: levelModel.width, y: levelModel.height)
        log.debug("level size: '\(size)'")

        let emptyPositions: [UIntVec2] = levelModel.emptyPositions.map { UIntVec2(x: $0.x, y: $0.y) }
        log.debug("number of empty positions: \(emptyPositions.count)")
        let emptyPositionSet = Set<UIntVec2>(emptyPositions)


        let builder = SnakeLevelBuilder(id: uuid, size: size)

        // Install walls on the non-empty positions
        for y: UInt32 in 0..<size.y {
            for x: UInt32 in 0..<size.x {
                let position = UIntVec2(x: x, y: y)
                let isEmpty: Bool = emptyPositionSet.contains(position)
                if !isEmpty {
                    builder.installWall(at: position)
                }
            }
        }

        // Insert food
        guard case .foodPosition(let foodPositionModel)? = stepModel.optionalFoodPosition else {
            log.error("Expected file to contain a food position for the first step, but got none.")
            fatalError()
        }
        builder.initialFoodPosition = UIntVec2(x: foodPositionModel.x, y: foodPositionModel.y)

        populateBuilderWithPlayerA(builder: builder, stepModel: stepModel)
        populateBuilderWithPlayerB(builder: builder, stepModel: stepModel)

        return builder.level()
    }

    private static func populateBuilderWithPlayerA(builder: SnakeLevelBuilder, stepModel: SnakeGameStateStepModel) {
        guard case .playerA(let player)? = stepModel.optionalPlayerA else {
            log.error("Expected player A, but got none.")
            return
        }
        guard player.alive else {
            log.debug("player1 is not alive, so no need to install")
            return
        }

        let positions: [IntVec2] = player.bodyPositions.map { IntVec2(x: Int32($0.x), y: Int32($0.y)) }

        guard let body = SnakeBody.create(positions: positions.reversed()) else {
            log.error("Unable to create snake from the positions: \(positions)")
            return
        }
        log.debug("headPosition: \(body.head.position)")
        log.debug("length: \(body.length)")
        log.debug("headDirection: \(body.head.direction)")
        builder.player1_body = body
    }

    private static func populateBuilderWithPlayerB(builder: SnakeLevelBuilder, stepModel: SnakeGameStateStepModel) {
        guard case .playerB(let player)? = stepModel.optionalPlayerB else {
            log.error("Expected player B, but got none.")
            return
        }
        guard player.alive else {
            log.debug("player2 is not alive, so no need to install")
            return
        }

        let positions: [IntVec2] = player.bodyPositions.map { IntVec2(x: Int32($0.x), y: Int32($0.y)) }

        guard let body = SnakeBody.create(positions: positions.reversed()) else {
            log.error("Unable to create snake from the positions: \(positions)")
            return
        }
        log.debug("headPosition: \(body.head.position)")
        log.debug("length: \(body.length)")
        log.debug("headDirection: \(body.head.direction)")
        builder.player2_body = body
    }

    public func reset() {
    }

    public func undo() {
    }

    public func executeStep(_ currentGameState: SnakeGameState) -> SnakeGameState {
        var gameState: SnakeGameState = currentGameState
        let newGameState = gameState.detectCollision()
        gameState = newGameState

        if gameState.player1.isAlive {
            var player: SnakePlayer = gameState.player1
            let snakeBody: SnakeBody = player.snakeBody.stateForTick(
                movement: player.pendingMovement,
                act: player.pendingAct
            )
            player = player.playerWithNewSnakeBody(snakeBody)
            player = player.updatePendingMovement(.dontMove)
            player = player.updatePendingAct(.doNothing)
//            player = stuckSnakeDetector1.killBotIfStuckInLoop(player)
            gameState = gameState.stateWithNewPlayer1(player)
        }

        if gameState.player2.isAlive {
            var player: SnakePlayer = gameState.player2
            let snakeBody: SnakeBody = player.snakeBody.stateForTick(
                movement: player.pendingMovement,
                act: player.pendingAct
            )
            player = player.playerWithNewSnakeBody(snakeBody)
            player = player.updatePendingMovement(.dontMove)
            player = player.updatePendingAct(.doNothing)
//            player = stuckSnakeDetector2.killBotIfStuckInLoop(player)
            gameState = gameState.stateWithNewPlayer2(player)
        }

        return gameState
    }

    public func computeNextBotMovement(_ oldGameState: SnakeGameState) -> SnakeGameState {
        let currentIteration: UInt64 = oldGameState.numberOfSteps + 2
        var newGameState: SnakeGameState = oldGameState

        if newGameState.player1.isAlive {
            if currentIteration >= player1Positions.count {
                log.debug("Player1 is dead. Reached end of player1Positions array.")
                newGameState = newGameState.killPlayer1(.killAfterAFewTimeSteps)
            } else {
                let position: IntVec2 = player1Positions[Int(currentIteration)]
                let head: SnakeHead = newGameState.player1.snakeBody.head
                let movement: SnakeBodyMovement = head.moveToward(position) ?? SnakeBodyMovement.dontMove
                //log.debug("move from \(head.position) to \(position)   movement: \(movement)")
                if movement == .dontMove {
                    log.error("Killing player1. The snake is supposed to move, but doesn't. Iteration: \(currentIteration)")
                    newGameState = newGameState.killPlayer1(.killAfterAFewTimeSteps)
                } else {
//                    log.debug("#\(currentIteration) player1: movement \(movement)")
                    newGameState = newGameState.updatePendingMovementForPlayer1(movement)
                }
            }
        }

        if newGameState.player2.isAlive {
            if currentIteration >= player2Positions.count {
                log.debug("Player2 is dead. Reached end of player2Positions array.")
                newGameState = newGameState.killPlayer2(.killAfterAFewTimeSteps)
            } else {
                let position: IntVec2 = player2Positions[Int(currentIteration)]
                let head: SnakeHead = newGameState.player2.snakeBody.head
                let movement: SnakeBodyMovement = head.moveToward(position) ?? SnakeBodyMovement.dontMove
                //log.debug("move from \(head.position) to \(position)   movement: \(movement)")
                if movement == .dontMove {
                    log.error("Killing player2. The snake is supposed to move, but doesn't. Iteration: \(currentIteration)")
                    newGameState = newGameState.killPlayer2(.killAfterAFewTimeSteps)
                } else {
//                    log.debug("#\(currentIteration) player2: movement \(movement)")
                    newGameState = newGameState.updatePendingMovementForPlayer2(movement)
                }
            }
        }

        return newGameState
    }

    public func placeNewFood(_ oldGameState: SnakeGameState) -> SnakeGameState {
        let currentIteration: UInt64 = oldGameState.numberOfSteps + 1
        guard currentIteration < foodPositions.count else {
            log.debug("Reached end of foodPositions array.  Iteration: \(currentIteration)")
            return oldGameState
        }
        let position: IntVec2 = foodPositions[Int(currentIteration)]
        guard position != oldGameState.foodPosition else {
//            log.debug("#\(currentIteration) food is unchanged. position: \(position)")
            return oldGameState
        }
        log.debug("#\(currentIteration) placing new food at \(position)")
        return oldGameState.stateWithNewFoodPosition(position)
    }

    static let printNumberOfSteps = false

    public func endOfStep(_ oldGameState: SnakeGameState) -> SnakeGameState {
        let step0: UInt64 = oldGameState.numberOfSteps
        let newGameState: SnakeGameState = oldGameState.incrementNumberOfSteps()
        let step1: UInt64 = newGameState.numberOfSteps
        if Self.printNumberOfSteps {
            log.debug("----------- numberOfSteps \(step0) -> \(step1) -----------")
        }
        return newGameState
    }
}


public class SnakeGameExecuterInteractive: SnakeGameExecuter {
    private var stuckSnakeDetector1 = StuckSnakeDetector(humanReadableName: "Player1")
    private var stuckSnakeDetector2 = StuckSnakeDetector(humanReadableName: "Player2")
    private var foodGenerator: SnakeFoodGenerator = SnakeFoodGenerator()

    public init() {}

    public func reset() {
        stuckSnakeDetector1.reset()
        stuckSnakeDetector2.reset()
    }

    public func undo() {
        stuckSnakeDetector1.undo()
        stuckSnakeDetector2.undo()
    }

    public func executeStep(_ currentGameState: SnakeGameState) -> SnakeGameState {
        var gameState: SnakeGameState = currentGameState
        let newGameState = gameState.detectCollision()
        gameState = newGameState

        if gameState.player1.isAlive {
            var player: SnakePlayer = gameState.player1
            let snakeBody: SnakeBody = player.snakeBody.stateForTick(
                movement: player.pendingMovement,
                act: player.pendingAct
            )
            player = player.playerWithNewSnakeBody(snakeBody)
            player = player.updatePendingMovement(.dontMove)
            player = player.updatePendingAct(.doNothing)
            player = stuckSnakeDetector1.killBotIfStuckInLoop(player)
            gameState = gameState.stateWithNewPlayer1(player)
        }

        if gameState.player2.isAlive {
            var player: SnakePlayer = gameState.player2
            let snakeBody: SnakeBody = player.snakeBody.stateForTick(
                movement: player.pendingMovement,
                act: player.pendingAct
            )
            player = player.playerWithNewSnakeBody(snakeBody)
            player = player.updatePendingMovement(.dontMove)
            player = player.updatePendingAct(.doNothing)
            player = stuckSnakeDetector2.killBotIfStuckInLoop(player)
            gameState = gameState.stateWithNewPlayer2(player)
        }

        return gameState
    }

	public func computeNextBotMovement(_ oldGameState: SnakeGameState) -> SnakeGameState {
        let oldPlayer1: SnakePlayer = oldGameState.player1
        let oldPlayer2: SnakePlayer = oldGameState.player2

        var computePlayer1 = false
		if case SnakePlayerRole.bot = oldPlayer1.role {
			if oldPlayer1.isAlive && oldPlayer1.pendingMovement == .dontMove {
                computePlayer1 = true
            }
        }
        var computePlayer2 = false
        if case SnakePlayerRole.bot = oldPlayer2.role {
            if oldPlayer2.isAlive && oldPlayer2.pendingMovement == .dontMove {
                computePlayer2 = true
            }
        }

        guard computePlayer1 || computePlayer2 else {
            // No need to compute next movement for the bots.
            return oldGameState
        }
        //log.debug("will compute")

        var newGameState: SnakeGameState = oldGameState
        if computePlayer1 {
            let newBotState = newGameState.player1.bot.compute(
                level: newGameState.level,
                player: newGameState.player1,
                oppositePlayer: newGameState.player2,
                foodPosition: newGameState.foodPosition
            )
            let pendingMovement: SnakeBodyMovement = newBotState.plannedMovement
            newGameState = newGameState.updateBot1(newBotState)
            newGameState = newGameState.updatePendingMovementForPlayer1(pendingMovement)
            //log.debug("player1: \(pendingMovement)")
		}

		if computePlayer2 {
            let newBotState = newGameState.player2.bot.compute(
                level: newGameState.level,
                player: newGameState.player2,
                oppositePlayer: newGameState.player1,
                foodPosition: newGameState.foodPosition
            )
            let pendingMovement: SnakeBodyMovement = newBotState.plannedMovement
            newGameState = newGameState.updateBot2(newBotState)
            newGameState = newGameState.updatePendingMovementForPlayer2(pendingMovement)
            //log.debug("player2: \(pendingMovement)")
		}

        //log.debug("did compute")
		return newGameState
	}

    public func placeNewFood(_ oldGameState: SnakeGameState) -> SnakeGameState {
        if oldGameState.foodPosition != nil {
            return oldGameState
        }
        // IDEA: Generate CSV file with statistics about food eating frequency
        //let steps: UInt64 = self.gameState.numberOfSteps
        //log.debug("place new food: \(steps)")
        return foodGenerator.placeNewFood(oldGameState)
    }

    static let printNumberOfSteps = false

    public func endOfStep(_ oldGameState: SnakeGameState) -> SnakeGameState {
        let step0: UInt64 = oldGameState.numberOfSteps
        let newGameState: SnakeGameState = oldGameState.incrementNumberOfSteps()
        let step1: UInt64 = newGameState.numberOfSteps
        if Self.printNumberOfSteps {
            log.debug("----------- numberOfSteps \(step0) -> \(step1) -----------")
        }
        return newGameState
    }
}

extension SnakeGameState {

	/// Deal with collision when both the player1 and the player2 is installed
	/// Deal with collision only if either the player1 or player2 is installed
	fileprivate func detectCollision() -> SnakeGameState {
		var gameState: SnakeGameState = self
		if gameState.player1.isDead && gameState.player2.isDead {
			log.debug("Both players are dead. No need to check for collision between them. 1")
			return gameState
		}

		let detector = SnakeCollisionDetector.create(
			level: gameState.level,
			foodPosition: gameState.foodPosition,
			player1: gameState.player1,
			player2: gameState.player2
		)
		detector.process()

		if gameState.player1.isAlive && detector.player1Alive == false {
            let collisionType: SnakeCollisionType = detector.collisionType1
            log.info("killing player1 because: \(collisionType)")
            gameState = gameState.killPlayer1(collisionType.killEvent)
		}
		if gameState.player2.isAlive && detector.player2Alive == false {
            let collisionType: SnakeCollisionType = detector.collisionType2
            log.info("killing player2 because: \(collisionType)")
			gameState = gameState.killPlayer2(collisionType.killEvent)
		}

		if detector.player1EatsFood {
			gameState = gameState.stateWithNewFoodPosition(nil)
			var player: SnakePlayer = gameState.player1
			player = player.updatePendingAct(.eat)
			gameState = gameState.stateWithNewPlayer1(player)
		}
		if detector.player2EatsFood {
			gameState = gameState.stateWithNewFoodPosition(nil)
			var player: SnakePlayer = gameState.player2
			player = player.updatePendingAct(.eat)
			gameState = gameState.stateWithNewPlayer2(player)
		}
		return gameState
	}
}

extension SnakeCollisionType {
    /// Convert from a `CollisionType` to its corresponding `KillEvent`.
    fileprivate var killEvent: SnakePlayerKillEvent {
        switch self {
        case .noCollision:
            fatalError("Inconsistency. A collision happened, but no collision is registered. Should never happen!")
        case .snakeCollisionWithWall:
            return .collisionWithWall
        case .snakeCollisionWithOpponent:
            return .collisionWithOpponent
        case .snakeCollisionWithItself:
            return .collisionWithItself
        }
    }
}

extension StuckSnakeDetector {
    /// While playing as a human, I find it annoying to get killed because
    /// I'm doing the same patterns over and over.
    /// So this "stuck in loop" detection only applies to bots.
    fileprivate func killBotIfStuckInLoop(_ player: SnakePlayer) -> SnakePlayer {
        guard player.isBot && player.isAlive else {
            return player
        }
        self.append(player.snakeBody)
        if self.isStuck {
            return player.kill(.stuckInALoop)
        } else {
            return player
        }
    }
}
