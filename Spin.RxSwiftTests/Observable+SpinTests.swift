//
//  Observable_SpinTests.swift
//  Spin.RxSwiftTests
//
//  Created by Thibault Wittemberg on 2019-08-16.
//  Copyright © 2019 WarpFactor. All rights reserved.
//

import RxBlocking
import RxRelay
import RxSwift
import Spin
import Spin_RxSwift
import XCTest

struct MockState: Equatable {
    let value: Int

    static let zero = MockState(value: 0)
}

enum MockAction: Equatable {
    case increment
    case reset
}

class IncrementCommand: Command {
    var operationQueueOfExecutionName: String?
    private let shouldError: Bool

    init(shouldError: Bool = false) {
        self.shouldError = shouldError
    }

    func execute(basedOn state: MockState) -> Observable<MockAction> {
        guard !self.shouldError else { return .error(TestError()) }

        self.operationQueueOfExecutionName = OperationQueue.current?.name

        if state.value >= 5 {
            return .just(.reset)
        }

        return .just(.increment)
    }
}

struct ResetCommand: Command {
    func execute(basedOn state: MockState) -> Observable<MockAction> {
        return .just(.reset)
    }
}

struct TestError: Error {
}

let reducer: (MockState, MockAction) -> MockState = { (state, action) in
    switch action {
    case .increment:
        return MockState(value: state.value + 1)
    case .reset:
        return MockState(value: 0)
    }
}

final class Observable_SpinTests: XCTestCase {
    
    private let disposeBag = DisposeBag()

    // MARK: tests Consumable conformance

    func testConsume_receives_all_the_events_from_the_inputStream() {
        // Given: some values to emit as a stream
        let exp = expectation(description: "consume")
        exp.expectedFulfillmentCount = 9

        let expectedValues = [1, 2, 3, 4, 5, 6, 7, 8, 9]
        var consumedValues = [Int]()

        // When: consuming a stream of input values
        Observable<Int>.from(expectedValues)
            .consume(by: { value in
                consumedValues.append(value)
                exp.fulfill()
            }, on: MainScheduler.instance)
            .spin()
            .disposed(by: self.disposeBag)

        waitForExpectations(timeout: 2)

        // Then: consumes values are the same os the input values
        XCTAssertEqual(consumedValues, expectedValues)
    }

    func testConsume_switches_to_the_expected_queues () {
        let expectations = expectation(description: "schedulers")
        expectations.expectedFulfillmentCount = 18

        let consumeScheduler1: OperationQueueScheduler = {
            let queue = OperationQueue()
            queue.name = "CONSUME_QUEUE_1"
            queue.maxConcurrentOperationCount = 1
            return OperationQueueScheduler(operationQueue: queue)
        }()

        let consumeScheduler2: OperationQueueScheduler = {
            let queue = OperationQueue()
            queue.name = "CONSUME_QUEUE_2"
            queue.maxConcurrentOperationCount = 1
            return OperationQueueScheduler(operationQueue: queue)
        }()

        // Given: some values to emit as a stream
        // When: consuming these values on different Executers
        // Then: the Executers are respected
        Observable<Int>.from([1, 2, 3, 4, 5, 6, 7, 8, 9])
            // switch to CONSUME_QUEUE_1 before consume
            .consume(by: { _ in
                expectations.fulfill()
                XCTAssertEqual(OperationQueue.current?.name!, "CONSUME_QUEUE_1")
            }, on: consumeScheduler1)
            // switch to CONSUME_QUEUE_2 before consume
            .consume(by: { _ in
                expectations.fulfill()
                XCTAssertEqual(OperationQueue.current?.name!, "CONSUME_QUEUE_2")
            }, on: consumeScheduler2)
            .spin()
            .disposed(by: self.disposeBag)

        waitForExpectations(timeout: 2)
    }

    // MARK: tests Producer conformance

    func testToReactiveStream_gives_the_original_inputStream () {
        // Given: a from closure
        let fromClosure = { () -> Observable<AnyCommand<Observable<MockAction>, MockState>> in return .just(ResetCommand().eraseToAnyCommand()) }
        let fromClosureResult = fromClosure()

        // When: retrieving the stream from the closure
        let resultStream = Spinner.from(function: fromClosure).toReactiveStream()

        // Then: the stream is of the same type than the result of the from closure
        XCTAssertTrue(type(of: resultStream) == type(of: fromClosureResult))
    }

//    func testSpy_sees_all_the_events_from_the_inputStream() {
//        // Given: some commands to emit as a stream
//        let inputStream = Observable<AnyCommand<Observable<MockAction>, MockState>>.from([
//            IncrementCommand().eraseToAnyCommand(),
//            ResetCommand().eraseToAnyCommand()
//            ])
//
//        var spiedCommands: [AnyCommand<Observable<MockAction>, MockState>] = []
//
//        // When: spying the stream of commands
//        _ = try? Spinner
//            .from { inputStream }
//            .spy { spiedCommands.append($0) }
//            .toReactiveStream()
//            .toBlocking()
//            .toArray()
//
//        // Then: consumes values are the same os the input values
//        XCTAssertEqual(spiedCommands.count, 2)
//        let action1 = try? spiedCommands[0].execute(basedOn: MockState(value: 0)).toBlocking().single()
//        let action2 = try? spiedCommands[1].execute(basedOn: MockState(value: 0)).toBlocking().single()
//        
//        XCTAssertEqual(action1!, .increment)
//        XCTAssertEqual(action2!, .reset)
//    }

    func testFeedback_computes_the_expected_states() {
        let exp = expectation(description: "feedback")
        exp.expectedFulfillmentCount = 7
        var receivedStates = [MockState]()

        // Given: some commands to emit as a stream
        let inputStream = Observable<AnyCommand<Observable<MockAction>, MockState>>.from([
            IncrementCommand().eraseToAnyCommand(),
            IncrementCommand().eraseToAnyCommand(),
            IncrementCommand().eraseToAnyCommand(),
            IncrementCommand().eraseToAnyCommand(),
            IncrementCommand().eraseToAnyCommand(),
            IncrementCommand().eraseToAnyCommand()
            ])

        // When: runing a feedback loop on the stream of commands
        Spinner
            .from { inputStream }
            .executeAndScan(initial: .zero, reducer: reducer)
            .consume(by: { state in
                exp.fulfill()
                receivedStates.append(state)
            }, on: MainScheduler.instance)
            .spin()
            .disposed(by: self.disposeBag)

        waitForExpectations(timeout: 2)

        // Then: the computed states are good (and relying on the previous state values -> see the implementation of IncrementCommand)
        XCTAssertEqual(receivedStates.map { $0.value }, [0, 1, 2, 3, 4, 5, 0])
    }

    func testLoop_does_not_stop_in_case_of_error_in_a_command() {
        let exp = expectation(description: "feedback")
        exp.expectedFulfillmentCount = 2
        var receivedStates = [MockState]()

        // Given: some commands to emit as a stream
        let inputStream = Observable<AnyCommand<Observable<MockAction>, MockState>>.from([
            IncrementCommand(shouldError: true).eraseToAnyCommand(),
            IncrementCommand(shouldError: false).eraseToAnyCommand()
            ])

        // When: runing a feedback loop on the stream of commands
        Spinner
            .from { inputStream }
            .executeAndScan(initial: .zero, reducer: reducer)
            .consume(by: { state in
                exp.fulfill()
                receivedStates.append(state)
            }, on: MainScheduler.instance)
            .spin()
            .disposed(by: self.disposeBag)

        waitForExpectations(timeout: 2)

        // Then: the computed states are good (the command that failed did not stop the loop)
        XCTAssertEqual(receivedStates.map { $0.value }, [0, 1])
    }

    func testExecuters_are_correctly_applied () {
        let expectations = expectation(description: "schedulers")
//        expectations.expectedFulfillmentCount = 6
        expectations.expectedFulfillmentCount = 5

        let fromScheduler: OperationQueueScheduler = {
            let queue = OperationQueue()
            queue.name = "FROM_QUEUE"
            queue.maxConcurrentOperationCount = 1
            return OperationQueueScheduler(operationQueue: queue)
        }()

        let consumeScheduler1: OperationQueueScheduler = {
            let queue = OperationQueue()
            queue.name = "CONSUME_QUEUE_1"
            queue.maxConcurrentOperationCount = 1
            return OperationQueueScheduler(operationQueue: queue)
        }()

        let consumeScheduler2: OperationQueueScheduler = {
            let queue = OperationQueue()
            queue.name = "CONSUME_QUEUE_2"
            queue.maxConcurrentOperationCount = 1
            return OperationQueueScheduler(operationQueue: queue)
        }()

        // Given: an input stream being a single Command
        // When: executing the different layers of the loop on different Executers
        // Then: the Executers are respected
        let commandToExecute = IncrementCommand()
        let inputStream = Observable<AnyCommand<Observable<MockAction>, MockState>>.from([
            commandToExecute.eraseToAnyCommand()
            ])

        Spinner
            .from { () -> Observable<AnyCommand<Observable<MockAction>, MockState>> in
                expectations.fulfill()
                return inputStream.observeOn(fromScheduler)
            }
            // switch to FROM_QUEUE after from
//            .spy(function: { _ in
//                expectations.fulfill()
//                XCTAssertEqual(OperationQueue.current?.name!, "FROM_QUEUE")
//            })
            .executeAndScan(initial: .zero, reducer: reducer)
            // switch to CONSUME_QUEUE_1 before consume
            .consume(by: { _ in
                expectations.fulfill()
                XCTAssertEqual(OperationQueue.current?.name!, "CONSUME_QUEUE_1")
            }, on: consumeScheduler1)
            // switch to CONSUME_QUEUE_2 before consume
            .consume(by: { _ in
                expectations.fulfill()
                XCTAssertEqual(OperationQueue.current?.name!, "CONSUME_QUEUE_2")
            }, on: consumeScheduler2)
            .spin()
            .disposed(by: self.disposeBag)

        waitForExpectations(timeout: 2)

        XCTAssertEqual(commandToExecute.operationQueueOfExecutionName!, "FROM_QUEUE")
    }
}
