import Alamofire
import Foundation

open class NetKitRequestConfiguration: RequestableConfiguration {
    open var mockPolicy: NetKit.MockPolicy = .never
    open var prepare: (URLRequest) -> URLRequest = { $0 }
    open var willSend: (URLRequest) -> Void = { _ in }
    open var didReceive: (NetworkResponse) -> Void = { _ in }
    open var process: (NetworkResponse) -> NetworkResponse = { $0 }
    open var decoder = JSONDecoder()
    open var session = Session()
    open func errorHandler<T>(error: Error, resp: NetworkResponse, request: URLRequest, completion: @escaping (Result<T>) -> Void) where T : Decodable {
        DispatchQueue.main.async {
            completion(.failure(error))
        }
    }
    public init() { }
}

public final class NetKit {
    public enum MockPolicy {
        case never
        case custom(MockDataConstructor)

        public enum Behavior {
            case randomDelayInSeconds(UInt, Data)
            case timeout
            case wrongFormat(Data)
        }

        public var mockConstructor: MockDataConstructor? {
            switch self {
            case .never: return nil
            case let .custom(value): return value
            }
        }

        public var isMockEnabled: Bool {
            switch self {
            case .never: return false
            case .custom: return true
            }
        }
    }

    public enum NetworkError: Error {
        case dataIsNil(NetworkResponse)
        case info(Error, NetworkResponse)
    }

    public enum StubError: Error, CustomNSError {
        case timeout(Int)

        private var _seconds: Int {
            switch self {
            case let .timeout(sec): return sec
            }
        }

        public var errorCode: Int { return NSURLErrorTimedOut }
        public var errorUserInfo: [String: Any] { return ["StubInfo": "Timeout for \(_seconds) seconds"] }
        public var localizedDescription: String {
            return "Stub Timeout for \(_seconds) seconds"
        }
    }
}
