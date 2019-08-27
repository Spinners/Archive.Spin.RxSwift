//
//  Observable+Stream.swift
//  Spin.RxSwift
//
//  Created by Thibault Wittemberg on 2019-08-16.
//  Copyright © 2019 WarpFactor. All rights reserved.
//

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
        return self.scan(value, accumulator: reducer).eraseToAnyConsumable()
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

public typealias Spin<Value> = AnyProducer<Observable<Value>, Value, Observable<Value>.Executer, Observable<Value>.Lifecycle>
