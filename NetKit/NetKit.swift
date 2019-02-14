import Alamofire
import Foundation

public final class NetKit {
    public var mockPolicy: MockPolicy = .never
    public var prepare: (URLRequest) -> URLRequest = { $0 }
    public var willSend: (URLRequest) -> Void = { _ in }
    public var didRecieve: (NetworkResponse) -> Void = { _ in }
    public var process: (NetworkResponse) -> NetworkResponse = { $0 }
    public var decoder = JSONDecoder()
    public var session = Session()
}

extension NetKit: RequestableConfiguration {}

public extension NetKit {
    enum MockPolicy {
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

    enum NetworkError: Error {
        case dataIsNil(NetworkResponse)
        case info(Error, NetworkResponse)
    }

    enum StubError: Error, CustomNSError {
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
