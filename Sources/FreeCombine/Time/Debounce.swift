//
//  Debounce.swift
//  
//
//  Created by Van Simmons on 7/8/22.
//
//  Copyright 2022, ComputeCycles, LLC
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//
extension Publisher {
    private func cleanup(
        _ subject: Subject<Output>,
        _ subjectRef: ValueRef<Subject<Output>?>,
        _ cancellable: Cancellable<Demand>,
        _ cancellableRef: ValueRef<Cancellable<Demand>?>,
        _ timerCancellableRef: ValueRef<Cancellable<Void>?>
    ) async throws  -> Void {
        let timerCancellable = timerCancellableRef.value
        _ = await timerCancellable?.cancelAndAwaitResult()
        timerCancellableRef.set(value: .none)
        try await subject.finish()
        _ = await subject.result
        subjectRef.set(value: .none)
        _ = await cancellable.result
        cancellableRef.set(value: .none)
    }

    func debounce(
        interval: Duration
    ) -> Self {
        .init { resumption, downstream in
            let subjectRef = ValueRef<Subject<Output>?>(value: .none)
            let cancellableRef = ValueRef<Cancellable<Demand>?>(value: .none)
            let timerCancellableRef = ValueRef<Cancellable<Void>?>(value: .none)
            return self(onStartup: resumption) { r in
                var subject: Subject<Output>! = subjectRef.value
                var cancellable: Cancellable<Demand>! = cancellableRef.value
                if subject == nil {
                    subject = try await PassthroughSubject(buffering: .bufferingNewest(1))
                    subjectRef.set(value: subject)
                    cancellable = await subject.publisher().sink(downstream)
                    cancellableRef.set(value: cancellable)
                }
                guard !Task.isCancelled && !cancellable.isCancelled else {
                    try await cleanup(subject, subjectRef, cancellable, cancellableRef, timerCancellableRef)
                    return try await handleCancellation(of: downstream)
                }
                if let timer = timerCancellableRef.value {
                    // FIXME: Need to check if value got sent anyway
                    _ = await timer.cancelAndAwaitResult()
                    timerCancellableRef.set(value: .none)
                }
                timerCancellableRef.set(value: .init {
                    guard let subject = subjectRef.value else {
                        throw PublisherError.internalError
                    }
                    try await Task.sleep(nanoseconds: interval.inNanoseconds)
                    let _: Void = try subject.nonblockingSend(r)
                })
                switch r {
                    case .value:
                        return .more
                    case .completion(.finished), .completion(.cancelled):
                        try await cleanup(subject, subjectRef, cancellable, cancellableRef, timerCancellableRef)
                        return .done
                    case .completion(.failure(let error)):
                        try await cleanup(subject, subjectRef, cancellable, cancellableRef, timerCancellableRef)
                        throw error
                }
            }
        }
    }
}
