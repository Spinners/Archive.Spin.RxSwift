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
    public typealias Context = ImmediateSchedulerType
    public typealias Runtime = Disposable
    
    public func compose<Output: Producer>(function: (Input) -> Output) -> AnyProducer<Output.Input, Output.Value, Output.Context, Output.Runtime> {
        return function(self).eraseToAnyProducer()
    }

    public func scan<Result>(initial value: Result, reducer: @escaping (Result, Value) -> Result) -> AnyConsumable<Result, Context, Runtime> {
        return self.scan(value, accumulator: reducer).eraseToAnyConsumable()
    }
    
    public func consume(by: @escaping (Value) -> Void, on: Context) -> AnyConsumable<Value, Context, Runtime> {
        return self.observeOn(on).do(onNext: by).eraseToAnyConsumable()
    }

    public func spy(function: @escaping (Value) -> Void) -> AnyProducer<Input, Value, Context, Runtime> {
        return self.do(onNext: function).eraseToAnyProducer()
    }

    public func spin() -> Runtime {
        return self.subscribe()
    }
    
    public func toReactiveStream() -> Input {
        return self
    }
}

public typealias Spin<Value> = AnyProducer<Observable<Value>, Value, Observable<Value>.Context, Observable<Value>.Runtime>
