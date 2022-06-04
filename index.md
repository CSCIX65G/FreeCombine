# FreeCombine

- Protocol-free.
- Race-free.
- Yield-free.
- Sleep-free.
- Lock-free.
- Leak-free.
- Dependency-free.

## Salient features

1. "Small things that compose"
2. Futures _AND_ Streams

## Todo

1. maybe add an additional repo (FreeCombineDispatch) that depends on libdispatch to get delay, debounce, throttle
2. revamp StateThread to be exactly a concurrency aware version of TCA's store
3. Add support for Promise/Future
4. Add a repo which implements asyncPublishers for everything in Foundation that currently has a `publisher`
5. fully implement all Combine operators
6. Add a Buffer publisher/operator to reintroduce a push model via an independent source of demand upstream
7. Get to 100% test coverage
8. Document this at the level of writing a book in the form of playgrounds
