//
//  Observable+Stream.swift
//  Spin.RxSwift
//
//  Created by Thibault Wittemberg on 2019-08-16.
//  Copyright © 2019 WarpFactor. All rights reserved.
//

import RxRelay
import RxSwift
import Spin

extension Observable: Producer & Consumable {
    public typealias Input = Observable
    public typealias Value = Element
    public typealias Executer = ImmediateSchedulerType
    public typealias Lifecycle = Disposable
    
    public func compose<Output: Producer>(function: (Input) -> Output) -> AnyProducer<Output.Input, Output.Value, Output.Executer, Output.Lifecycle> {
        return function(self).eraseToAnyProducer()
    }
    
    public func scan<Result>(initial value: Result, reducer: @escaping (Result, Value) -> Result) -> AnyConsumable<Result, Executer, Lifecycle> {
        return self
            .scan(value, accumulator: reducer)
//            .startWith(value)
            .eraseToAnyConsumable()
    }
    
    public func consume(by: @escaping (Value) -> Void, on: Executer) -> AnyConsumable<Value, Executer, Lifecycle> {
        return self.observeOn(on).do(onNext: by).eraseToAnyConsumable()
    }
    
    public func spy(function: @escaping (Value) -> Void) -> AnyProducer<Input, Value, Executer, Lifecycle> {
        return self.do(onNext: function).eraseToAnyProducer()
    }
    
    public func spin() -> Lifecycle {
        return self.subscribe()
    }
    
    public func toReactiveStream() -> Input {
        return self
    }
}

extension Observable: Feedback where Element: Command {
    
    public func feedback<Result>(initial value: Result,
                                 reducer: @escaping (Result, Value.Mutation) -> Result) -> AnyConsumable<Result, Executer, Lifecycle> where Value.State == Result {
        
        let currentState = BehaviorRelay<Result>(value: value)
        
        return
            self.compose { (commandObservable) -> Observable<Value.Mutation> in
                return commandObservable.withLatestFrom(currentState) { return ($0, $1) }
                    .flatMap { (arg) -> Observable<Element.Mutation> in
                        let (command, state) = arg
                        return command.execute(basedOn: state)
                }
            }
            .scan(initial: value, reducer: reducer)
            .consume(by: { currentState.accept($0) }, on: CurrentThreadScheduler.instance)
    }
}

