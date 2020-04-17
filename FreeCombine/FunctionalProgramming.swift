//
//  FunctionProgramming.swift
//  FreeCombine
//
//  Created by Van Simmons on 4/11/20.
//  Copyright © 2020 ComputeCycles, LLC. All rights reserved.
//

precedencegroup CompositionPrecedence {
  associativity: right
  higherThan: AssignmentPrecedence
  lowerThan: MultiplicationPrecedence, AdditionPrecedence
}

infix operator >>>: CompositionPrecedence
func >>> <A, B, C>(
    _ f: @escaping (A) -> B,
    _ g: @escaping (B) -> C
) -> (A) -> C {
    { (a: A) -> C in g(f(a)) }
}

infix operator |>: CompositionPrecedence
public func |> <A, B> (a: A, f: (A) -> B) -> B { f(a) }

public func identity<T>(_ t: T) -> T { t }

public func curry<A, B, C>(
    _ function: @escaping (A, B) -> C
) -> (A) -> (B) -> C {
    { (a: A) -> (B) -> C in
        { (b: B) -> C in
            function(a, b)
        }
    }
}

struct Func<A, B> {
    let call: (A) -> B
    
    init(_ call: @escaping (A) -> B) {
        self.call = call
    }
    
    func callAsFunction(_ a: A) -> B {
        call(a)
    }
    
    func map<C>(
        _ f: @escaping (B) -> C
    ) -> Func<A, C> {
        .init(call >>> f)
    }

    func contraMap<C>(
        _ transform: @escaping (C) -> A
    ) -> Func<C, B> {
        .init(transform >>> call)
    }
    
    func flatMap<C>(
        _ f: @escaping (B) -> Func<A, C>
    ) -> Func<A, C> {
        .init { (self.call >>> f)($0)($0) }
    }
        
    func contraFlatMap<C>(
        _ f: @escaping (Func<A, B>, C) -> Func<C, B>,
        _ g: @escaping (Func<C, B>) -> (C) -> B
    ) -> Func<C, B> {
        .init { (curry(f)(self) >>> g)($0)($0) }
    }

    func dimap<C, D>(
        _ f: @escaping (C) -> A,
        _ g: @escaping (B) -> D
    ) -> Func<C, D> {
        .init(f >>> call >>> g)
    }
}
