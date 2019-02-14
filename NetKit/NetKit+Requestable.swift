import Alamofire
import Foundation

public protocol RequestableConfiguration {
    var prepare: (URLRequest) -> URLRequest { get }
    var willSend: (URLRequest) -> Void { get }
    var didRecieve: (NetworkResponse) -> Void { get }
    var process: (NetworkResponse) -> NetworkResponse { get }
    var mockPolicy: NetKit.MockPolicy { get }
    var decoder: JSONDecoder { get }
    var session: Session { get }
}

public protocol NetKitRequestable {
    var method: HTTPMethod { get }
    var path: String { get }
    var params: [String: Any] { get }
    var baseURL: URL { get }
    var paramEncoding: ParameterEncoding { get }
    var configuration: RequestableConfiguration { get }
}

public extension NetKitRequestable {
    var method: HTTPMethod { return .get }
    var params: [String: Any] { return [:] }
    var paramEncoding: ParameterEncoding {
        switch method {
        case .get: return URLEncoding()
        default: return JSONEncoding()
        }
    }
}

public extension NetKitRequestable {

    @discardableResult func execute<T: Decodable>(complete: @escaping (Result<T>) -> Void) -> DataRequest? {
        let req: URLRequest
        do { req = try asURLRequest() }
        catch {
            let e = NetKit.NetworkError.info(error, (nil, nil, nil))
            let result: Result<T> = Result.failure(e)
            DispatchQueue.main.async { complete(result) }
            return nil
        }
        let modifiedRequest = configuration.prepare(req)
        configuration.willSend(modifiedRequest)

        if configuration.mockPolicy.isMockEnabled {
            doMock(req: modifiedRequest, complete: complete)
            return nil
        } else {
            return doExecute(req: modifiedRequest, complete: complete)
        }
    }

    private func doExecute<T: Decodable>(req: URLRequest, complete: @escaping (Result<T>) -> Void) -> DataRequest {

        let ret = configuration.session.request(req).response { [conf = configuration] resp in
            let response: NetworkResponse = (resp.request, resp.response, resp.data)
            let modifiedResponse = conf.process(response)
            conf.didRecieve(modifiedResponse)

            guard let v = modifiedResponse.2 else {
                let err = AFError.responseValidationFailed(reason: AFError.ResponseValidationFailureReason.dataFileNil)
                let e = NetKit.NetworkError.info(err, response)
                let r: Result<T> = Result.failure(e)
                complete(r)
                return
            }

            do {
                let decoder = conf.decoder
                let model = try decoder.decode(T.self, from: v)
                let r: Result<T> = Result.success(model)
                DispatchQueue.main.async { complete(r) }
            } catch {
                let e = NetKit.NetworkError.info(error, response)
                DispatchQueue.main.async { complete(.failure(e)) }
            }
        }
        return ret
    }

    private func doMock<T: Decodable>(req: URLRequest, complete: @escaping (Result<T>) -> Void) {
        guard let mock = configuration.mockPolicy.mockConstructor?(req) else {
            fatalError("Stub behavior is not specify when using stubExecute for \(req)")
        }

        func decodeAndReturn(data: Data) {
            let result: Result<T>
            do {
                let raw: NetworkResponse = (req, nil, data)
                configuration.didRecieve(raw)
                let resp = configuration.process(raw)
                let decoder = configuration.decoder
                if let d = resp.2 {
                    let model = try decoder.decode(T.self, from: d)
                    result = Result.success(model)
                } else {
                    let e = NetKit.NetworkError.dataIsNil(resp)
                    result = .failure(e)
                }
            } catch {
                let e = NetKit.NetworkError.info(error, (req, nil, data))
                result = .failure(e)
            }
            complete(result)
        }
        let timeoutInterval = Int(req.timeoutInterval)
        let timeoutError = NetKit.StubError.timeout(Int(timeoutInterval))
        let e = NetKit.NetworkError.info(timeoutError, (req, nil, nil))
        switch mock {
        case .timeout:
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(timeoutInterval)) {
                complete(.failure(e))
            }
        case let .randomDelayInSeconds(time, data):
            let delay = Int.random(in: 0 ... Int(time))
            let isTimeout = delay >= timeoutInterval
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(delay)) {
                if isTimeout {
                    complete(.failure(e))
                } else {
                    decodeAndReturn(data: data)
                }
            }
        case let .wrongFormat(data):
            DispatchQueue.main.async { decodeAndReturn(data: data) }
        }
    }

    private func asURLRequest() throws -> URLRequest {
        let encoder = paramEncoding
        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.cachePolicy = .useProtocolCachePolicy
        return try encoder.encode(request, with: params)
    }
}
