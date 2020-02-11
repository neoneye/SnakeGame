// MIT license. Copyright (c) 2020 Simon Strandgaard. All rights reserved.
import Foundation

public class SnakeGameState {
	public let level: SnakeLevel

	// IDEA: change foodPosition to UIntVec2, so that fewer casts are needed.
	public let foodPosition: IntVec2?
	public let player1: SnakePlayer
	public let player2: SnakePlayer
	public let foodRandomGenerator_seed: UInt64
	public let foodRandomGenerator_count: UInt64
	public let numberOfSteps: UInt64

	internal init(level: SnakeLevel, foodPosition: IntVec2?, player1: SnakePlayer, player2: SnakePlayer, foodRandomGenerator_seed: UInt64, foodRandomGenerator_count: UInt64, numberOfSteps: UInt64) {
		self.level = level
		self.foodPosition = foodPosition
		self.player1 = player1
		self.player2 = player2
		self.foodRandomGenerator_seed = foodRandomGenerator_seed
		self.foodRandomGenerator_count = foodRandomGenerator_count
		self.numberOfSteps = numberOfSteps
	}

	public class func empty() -> SnakeGameState {
		return SnakeGameState(
			level: SnakeLevel.empty(),
			foodPosition: nil,
			player1: SnakePlayer.create(role: .human),
			player2: SnakePlayer.create(role: .human),
			foodRandomGenerator_seed: 0,
			foodRandomGenerator_count: 0,
			numberOfSteps: 0
		)
	}

	public func stateWithNewLevel(_ newLevel: SnakeLevel) -> SnakeGameState {
		return SnakeGameState(
			level: newLevel,
			foodPosition: foodPosition,
			player1: player1,
			player2: player2,
			foodRandomGenerator_seed: foodRandomGenerator_seed,
			foodRandomGenerator_count: foodRandomGenerator_count,
			numberOfSteps: numberOfSteps
		)
	}

	public func stateWithNewFoodPosition(_ newFoodPosition: IntVec2?) -> SnakeGameState {
		return SnakeGameState(
			level: level,
			foodPosition: newFoodPosition,
			player1: player1,
			player2: player2,
			foodRandomGenerator_seed: foodRandomGenerator_seed,
			foodRandomGenerator_count: foodRandomGenerator_count,
			numberOfSteps: numberOfSteps
		)
	}

	public func stateWithNewPlayer1(_ newPlayer1: SnakePlayer) -> SnakeGameState {
		return SnakeGameState(
			level: level,
			foodPosition: foodPosition,
			player1: newPlayer1,
			player2: player2,
			foodRandomGenerator_seed: foodRandomGenerator_seed,
			foodRandomGenerator_count: foodRandomGenerator_count,
			numberOfSteps: numberOfSteps
		)
	}

	public func stateWithNewPlayer2(_ newPlayer2: SnakePlayer) -> SnakeGameState {
		return SnakeGameState(
			level: level,
			foodPosition: foodPosition,
			player1: player1,
			player2: newPlayer2,
			foodRandomGenerator_seed: foodRandomGenerator_seed,
			foodRandomGenerator_count: foodRandomGenerator_count,
			numberOfSteps: numberOfSteps
		)
	}

	public func updatePendingMovementForPlayer1(_ newPendingMovement: SnakeBodyMovement) -> SnakeGameState {
		return SnakeGameState(
			level: level,
			foodPosition: foodPosition,
			player1: player1.updatePendingMovement(newPendingMovement),
			player2: player2,
			foodRandomGenerator_seed: foodRandomGenerator_seed,
			foodRandomGenerator_count: foodRandomGenerator_count,
			numberOfSteps: numberOfSteps
		)
	}

	public func updatePendingMovementForPlayer2(_ newPendingMovement: SnakeBodyMovement) -> SnakeGameState {
		return SnakeGameState(
			level: level,
			foodPosition: foodPosition,
			player1: player1,
			player2: player2.updatePendingMovement(newPendingMovement),
			foodRandomGenerator_seed: foodRandomGenerator_seed,
			foodRandomGenerator_count: foodRandomGenerator_count,
			numberOfSteps: numberOfSteps
		)
	}

	public func clearPendingMovementAndPendingLengthForHumanPlayers() -> SnakeGameState {
		return SnakeGameState(
			level: level,
			foodPosition: foodPosition,
			player1: player1.clearPendingMovementAndPendingActForHuman(),
			player2: player2.clearPendingMovementAndPendingActForHuman(),
			foodRandomGenerator_seed: foodRandomGenerator_seed,
			foodRandomGenerator_count: foodRandomGenerator_count,
			numberOfSteps: numberOfSteps
		)
	}

	public func killPlayer1() -> SnakeGameState {
		return SnakeGameState(
			level: level,
			foodPosition: foodPosition,
			player1: player1.killed(),
			player2: player2,
			foodRandomGenerator_seed: foodRandomGenerator_seed,
			foodRandomGenerator_count: foodRandomGenerator_count,
			numberOfSteps: numberOfSteps
		)
	}

	public func killPlayer2() -> SnakeGameState {
		return SnakeGameState(
			level: level,
			foodPosition: foodPosition,
			player1: player1,
			player2: player2.killed(),
			foodRandomGenerator_seed: foodRandomGenerator_seed,
			foodRandomGenerator_count: foodRandomGenerator_count,
			numberOfSteps: numberOfSteps
		)
	}

	public func updateFoodRandomGenerator(seed: UInt64, count: UInt64) -> SnakeGameState {
		return SnakeGameState(
			level: level,
			foodPosition: foodPosition,
			player1: player1,
			player2: player2,
			foodRandomGenerator_seed: seed,
			foodRandomGenerator_count: count,
			numberOfSteps: numberOfSteps
		)
	}

	public func updateBot1(_ newBot: SnakeBot) -> SnakeGameState {
		return SnakeGameState(
			level: level,
			foodPosition: foodPosition,
			player1: player1.updateBot(newBot),
			player2: player2,
			foodRandomGenerator_seed: foodRandomGenerator_seed,
			foodRandomGenerator_count: foodRandomGenerator_count,
			numberOfSteps: numberOfSteps
		)
	}

	public func updateBot2(_ newBot: SnakeBot) -> SnakeGameState {
		return SnakeGameState(
			level: level,
			foodPosition: foodPosition,
			player1: player1,
			player2: player2.updateBot(newBot),
			foodRandomGenerator_seed: foodRandomGenerator_seed,
			foodRandomGenerator_count: foodRandomGenerator_count,
			numberOfSteps: numberOfSteps
		)
	}

	public func incrementNumberOfSteps() -> SnakeGameState {
		return SnakeGameState(
			level: level,
			foodPosition: foodPosition,
			player1: player1,
			player2: player2,
			foodRandomGenerator_seed: foodRandomGenerator_seed,
			foodRandomGenerator_count: foodRandomGenerator_count,
			numberOfSteps: numberOfSteps + 1
		)
	}
}
