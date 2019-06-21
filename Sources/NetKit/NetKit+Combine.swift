import Combine

public extension NetKitRequestable {
    
    func execute<T: Decodable>() -> AnyPublisher<T, Error> {
        AnyPublisher { subscriber in
            let hanlder: (Result<T>) -> Void = { result in
                switch result {
                case let .success(value):
                    _ = subscriber.receive(value)
                    subscriber.receive(completion: .finished)
                    
                case let .failure(error):
                    subscriber.receive(completion: .failure(error))
                }
            }
            let req = self.execute(complete: hanlder)
            subscriber.receive(subscription: AnySubscription({ req?.cancel() }))
        }
    }
    
    func once<T: Decodable>() -> Publishers.Future<T, Error> {
        Publishers.Future { self.execute(complete: $0) }
    }
}

public final class AnySubscription: Subscription {
    private let cancellable: Cancellable
    
    public init(_ cancel: @escaping () -> Void) {
        cancellable = AnyCancellable(cancel)
    }
    
    public func request(_ demand: Subscribers.Demand) {}
    
    public func cancel() {
        cancellable.cancel()
    }
}
