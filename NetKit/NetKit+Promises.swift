#if canImport(Promises)
    import Promises

    public extension NetKitRequestable {
        func execute<T: Decodable>() -> Promise<T> {
            return Promise<T>({ success, failure in
                let hanlder: (Result<T>) -> Void = { result in
                    switch result {
                    case let .success(value): success(value)
                    case let .failure(error): failure(error)
                    }
                }
                self.execute(complete: hanlder)
            })
        }
    }
#endif
