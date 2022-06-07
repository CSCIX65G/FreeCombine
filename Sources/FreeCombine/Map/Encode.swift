//
//  Encode.swift
//  
//
//  Created by Van Simmons on 6/6/22.
//
public extension Publisher {
    struct TopLevelEncoder<T> {
        var encoder: (Output) throws -> T
        init(encoder: @escaping (Output) throws -> T) {
            self.encoder = encoder
        }
        func encode(_ data: Output) throws -> T {
            try encoder(data)
        }
    }

    func encode<Item: Decodable>(
        encoder: TopLevelEncoder<Item>
    ) -> Publisher<Item> {
        .init { continuation, downstream in
            self(onStartup: continuation) { r in
                switch r {
                    case .value(let data):
                        do { return try await downstream(.value(encoder.encode(data))) }
                        catch { return try await downstream(.completion(.failure(error))) }
                    case let .completion(value):
                        return try await downstream(.completion(value))
                }
            }
        }
    }
}
