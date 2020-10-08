//
//  Demand+Helpers.swift
//  FreeCombine
//
//  Created by Van Simmons on 5/25/20.
//  Copyright © 2020 ComputeCycles, LLC. All rights reserved.
//

extension Demand{
    var unsatisfied: Bool {
        switch self {
            case .none: return false
            case .max(let val) where val > 0: return true
            case .max: return false
            case .decrementPrevious: return false
            case .unlimited: return true
            case .cancel: return false
        }
    }
}

