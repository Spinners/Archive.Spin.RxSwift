//
//  Observable+Stream.swift
//  Spin.RxSwift
//
//  Created by Thibault Wittemberg on 2019-08-16.
//  Copyright © 2019 WarpFactor. All rights reserved.
//

import RxSwift
import Spin

extension Observable: Spin.Stream {
    public typealias Input = Observable
    public typealias Value = Element
    public typealias Context = SchedulerType
    public typealias Runtime = Disposable

    public static func from(function: () -> Input) -> AnyProducer<Input, Value, Context, Runtime> {
        return function().eraseToAnyProducer()
    }

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

    public func engage() -> Runtime {
        return self.subscribe()
    }
}
