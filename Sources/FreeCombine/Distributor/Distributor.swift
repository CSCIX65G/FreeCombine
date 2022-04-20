//
//  File.swift
//  
//
//  Created by Van Simmons on 4/17/22.
//

import Foundation

struct Distibutor<Output> {
    enum Action { }
    let channel: StatefulChannel<Output, Action>
}
