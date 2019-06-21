import Alamofire
import Foundation

public typealias Result<T> = Swift.Result<T, Swift.Error>
public typealias HTTPMethod = Alamofire.HTTPMethod
public typealias DataRequest = Alamofire.DataRequest
public typealias URLEncoding = Alamofire.URLEncoding
public typealias JSONEncoding = Alamofire.JSONEncoding
public typealias ParameterEncoding = Alamofire.ParameterEncoding

public typealias JSON = [String: Any]
public typealias MockDataConstructor = (URLRequest) -> NetKit.MockPolicy.Behavior
public typealias NetworkResponse = (URLRequest?, HTTPURLResponse?, Data?)
