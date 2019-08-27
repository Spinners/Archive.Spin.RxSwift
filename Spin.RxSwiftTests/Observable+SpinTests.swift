//
//  Observable_SpinTests.swift
//  Spin.RxSwiftTests
//
//  Created by Thibault Wittemberg on 2019-08-16.
//  Copyright © 2019 WarpFactor. All rights reserved.
//

import RxSwift
import Spin
import Spin_RxSwift
import XCTest

struct Pair<Value: Equatable>: Equatable {
    let left: Value
    let right: Value
}

final class Observable_SpinTests: XCTestCase {
    
    private let disposeBag = DisposeBag()
    
    func testToStream_gives_the_original_reactiveStream () {
        // Given: a from closure
        let fromClosure = { () -> Observable<Int> in return .just(1) }
        let fromClosureResult = fromClosure()
        
        // When: retrieving the stream from the closure
        let resultStream = Spin.from(function: fromClosure).toReactiveStream()
        
        // Then: the stream is of the same type than the result of the from closure
        XCTAssertTrue(type(of: resultStream) == type(of: fromClosureResult))
    }
    
    func testMutipleCompose_transforms_a_stream_elements_in_the_correct_type() {
        let expectations = expectation(description: "consume by")
        expectations.expectedFulfillmentCount = 9
        
        // Given: a composed stream
        // When: executing the loop
        var result = [Int]()
                
        Spin
            .from { return Observable<Int>.from([1, 2, 3, 4, 5, 6, 7, 8, 9]) }
            .compose { return $0.map { "\($0)" } }
            .compose { return $0.map { Int($0)! } }
            .scan(initial: 0) { (previous, current) -> Int in
                expectations.fulfill()
                result.append(current)
                return previous + current
            }
            .spin()
            .disposed(by: self.disposeBag)
                
        // Then: the output values before the scan are the ones from the final transformation of compose
        waitForExpectations(timeout: 2)
        XCTAssertEqual([1, 2, 3, 4, 5, 6, 7, 8, 9], result)
    }
    
    func testScan_outputs_the_right_results () {
        // Given: an input stream being a sequence of ints from 1 to 9
        let expectations = expectation(description: "consume by")
        expectations.expectedFulfillmentCount = 9
        let expectedResult = [1, 3, 6, 10, 15, 21, 28, 36, 45]
        var result = [Int]()
        
        // When: scanning the input by making the sum of all the inputs elements
        Spin.from { return Observable<Int>.from([1, 2, 3, 4, 5, 6, 7, 8, 9]) }
            .scan(initial: 0) { return $0 + $1 }
            .consume(by: { value in
                expectations.fulfill()
                result.append(value)
            }, on: MainScheduler.instance)
            .spin()
            .disposed(by: self.disposeBag)
        
        // Then: the expectation is met with the output being a stream of the successive addition of the input elements
        waitForExpectations(timeout: 2)
        XCTAssertEqual(result, expectedResult)
    }
    
    func testSpy_spies_the_elements_of_the_stream () {
        // Given: an input stream being a sequence of ints from 1 to 9
        let expectations = expectation(description: "spy")
        expectations.expectedFulfillmentCount = 9
        let expectedResult = [1, 2, 3, 4, 5, 6, 7, 8, 9]
        var result = [Int]()
        
        // When: spying the elements of the stream
        Spin.from { return Observable<Int>.from([1, 2, 3, 4, 5, 6, 7, 8, 9]) }
            .spy(function: { (value) in
                expectations.fulfill()
                result.append(value)
            })
            .scan(initial: 0) { return $0 + $1 }
            .spin()
            .disposed(by: self.disposeBag)
        
        // Then: the spied elements are the same as the inputs elements
        waitForExpectations(timeout: 2)
        XCTAssertEqual(result, expectedResult)
    }
    
    func testMiddlewares_catch_the_elements_of_scan () {
        // Given: an input stream being a sequence of ints from 1 to 9
        let expectations = expectation(description: "middlewares")
        expectations.expectedFulfillmentCount = 27
        let expectedResult = [Pair(left: 0, right: 1),
                              Pair(left: 1, right: 2),
                              Pair(left: 3, right: 3),
                              Pair(left: 6, right: 4),
                              Pair(left: 10, right: 5),
                              Pair(left: 15, right: 6),
                              Pair(left: 21, right: 7),
                              Pair(left: 28, right: 8),
                              Pair(left: 36, right: 9)]
        var result = [Pair<Int>]()
        
        // When: spying the elements of the stream
        Spin.from { return Observable<Int>.from([1, 2, 3, 4, 5, 6, 7, 8, 9]) }
            .scan(initial: 0, reducer: { $0 + $1 }, middlewares: { (previous, current) in
                expectations.fulfill()
                result.append(Pair(left: previous, right: current))
            }, { (previous, current) in
                expectations.fulfill()
            }, { (previous, current) in
                expectations.fulfill()
            })
            .spin()
            .disposed(by: self.disposeBag)
        
        // Then: the spied elements are the same as the inputs elements
        waitForExpectations(timeout: 2)
        XCTAssertEqual(result, expectedResult)
    }
    
    func testSchedulers_execute_layers_on_good_queues () {
        let expectations = expectation(description: "schedulers")
        expectations.expectedFulfillmentCount = 7

        let fromScheduler: OperationQueueScheduler = {
            let queue = OperationQueue()
            queue.name = "FROM_QUEUE"
            queue.maxConcurrentOperationCount = 1
            return OperationQueueScheduler(operationQueue: queue)
        }()
        
        let composeScheduler: OperationQueueScheduler = {
            let queue = OperationQueue()
            queue.name = "COMPOSE_QUEUE"
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
        
        // Given: an input stream being a a single element
        // When: executing the different layers off the loop on different Queues
        // Then: the queues are respected
        Spin
            .from { () -> Observable<Int> in
                expectations.fulfill()
                return Observable<Int>.just(1).observeOn(fromScheduler)
            }
            // switch to FROM_QUEUE after from
            .spy { _ in
                expectations.fulfill()
                XCTAssertEqual(OperationQueue.current?.name!, "FROM_QUEUE")
            }
            .compose { input -> Observable<String> in
                expectations.fulfill()
                return input.map { "\($0)" }.observeOn(composeScheduler)
            }
            // switch to COMPOSE_QUEUE after compose
            .spy { _ in
                expectations.fulfill()
                XCTAssertEqual(OperationQueue.current?.name!, "COMPOSE_QUEUE")
            }
            .scan(initial: "") { (previous, current) -> String in
                expectations.fulfill()
                return previous + current
            }
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
}
