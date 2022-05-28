//
//  Decode.swift
//  
//
//  Created by Van Simmons on 5/18/22.
//
public extension Publisher {
    struct TopLevelDecoder<T> {
        var decoder: (T.Type, Output) throws -> T
        init(decoder: @escaping (T.Type, Output) throws -> T) {
            self.decoder = decoder
        }
        func decode(_ t: T.Type, from output: Output) throws -> T {
            try decoder(t, output)
        }
    }

    func decode<Item: Decodable>(
        _ type: Item.Type,
        decoder: TopLevelDecoder<Item>
    ) -> Publisher<Item> {
        .init { continuation, downstream in
            self(onStartup: continuation) { r in
                switch r {
                    case .value(let data):
                        do { return try await downstream(.value(decoder.decode(type, from: data))) }
                        catch { return try await downstream(.completion(.failure(error))) }
                    case let .completion(value):
                        return try await downstream(.completion(value))
                }
            }
        }
    }
}
