//
//  FunctionProgramming.swift
//  FreeCombine
//
//  Created by Van Simmons on 4/11/20.
//  Copyright © 2020 ComputeCycles, LLC. All rights reserved.
//
import Foundation

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

public func identity<T>(t: T) -> T { t }
public func never<T>(_ t: T) -> (Never) -> T { {_ in t } }
public func void<T>(_ t: T) -> Void { }
public func const<T, Param>(_ t: T) -> (_ p: Param) -> T { { p in t } }

public func curry<A, B, C>(
    _ function: @escaping (A, B) -> C
) -> (A) -> (B) -> C {
    { (a: A) -> (B) -> C in
        { (b: B) -> C in
            function(a, b)
        }
    }
}
