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

extension Observable: Consumable {
    public typealias Value = Element
    public typealias Executer = ImmediateSchedulerType
    public typealias Lifecycle = Disposable
    
    public func consume(by: @escaping (Value) -> Void, on: Executer) -> AnyConsumable<Value, Executer, Lifecycle> {
        return self
            .observeOn(on)
            .do(onNext: by)
            .eraseToAnyConsumable()
    }
    
    public func spin() -> Lifecycle {
        return self.subscribe()
    }
}

extension Observable: Producer where Element: Command, Element.Stream: ObservableType, Element.Stream.Element == Element.Stream.Value {

    public typealias Input = Observable

//    public func merge(function: () -> Input) -> AnyProducer<Input, Value, Executer, Lifecycle> {
//        return Observable.merge(self, function()).eraseToAnyProducer()
//    }
//
//    public func merge(input: Input) -> AnyProducer<Input, Value, Executer, Lifecycle> {
//        return Observable.merge(self, input).eraseToAnyProducer()
//    }

    public func executeAndScan(initial value: Value.State, reducer: @escaping (Value.State, Value.Stream.Value) -> Value.State) -> AnyConsumable<Value.State, Executer, Lifecycle> {
        let currentState = ReplaySubject<Value.State>.create(bufferSize: 1)
        
        return self
            .withLatestFrom(currentState) { return ($0, $1) }
            .catchError { _ in Observable<(Value, Value.State)>.empty() }
            .flatMap { args -> Observable<Value.Stream.Value> in
                let (command, state) = args

                return command.execute(basedOn: state).asObservable().catchError { _ in Observable<Value.Stream.Value>.empty() }
        }
        .observeOn(CurrentThreadScheduler.instance)
        .scan(value, accumulator: reducer)
        .startWith(value)
        .do(onNext: { currentState.onNext($0) })
        .eraseToAnyConsumable()
    }

//    public func spy(function: @escaping (Value) -> Void) -> AnyProducer<Input, Value, Executer, Lifecycle> {
//        return self
//            .do(onNext: function)
//            .eraseToAnyProducer()
//    }

    public func toReactiveStream() -> Input {
        return self
    }
}
