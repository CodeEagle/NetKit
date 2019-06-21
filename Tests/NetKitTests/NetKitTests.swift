import XCTest
@testable import NetKit

let config = NetKitRequestConfiguration()

class NetKitTests: XCTestCase {

    var decodeJsonArray = false
    override func setUp() {
        config.mockPolicy = .custom({ request -> NetKit.MockPolicy.Behavior in
            guard let path = request.url?.path.replacingOccurrences(of: "/", with: "") else { return .timeout }

            switch path {
            case "wrongFormat": return .wrongFormat("{\"wrong\" : \"format\"}".data(using: .utf8)!)
            case "randomDelay", "json":
                let data = """
{
  "slideshow": {
    "author": "Yours Truly",
    "date": "date of publication",
    "slides": [
      {
        "title": "Wake up to WonderWidgets!",
        "type": "all"
      },
      {
        "items": [
          "Why <em>WonderWidgets</em> are great",
          "Who <em>buys</em> WonderWidgets"
        ],
        "title": "Overview",
        "type": "all"
      }
    ],
    "title": "Sample Slide Show"
  }
}
""".data(using: .utf8)!
                return .randomDelayInSeconds(3, data)
            default: return .timeout
            }
        })
        config.prepare = { req in
            var r = req
            r.timeoutInterval = 5
            return r
        }
        config.willSend = { request in
            print("will send: \(request), \(request.allHTTPHeaderFields!)")

        }
        config.didReceive = { response in
            if let req = response.0 {
                print("req: \(req)")
            }
            if let resp = response.1 {
                print("resp: \(resp)")
            }
            if let d = response.2, let json = String(data: d, encoding: .utf8) {
                print("data: \(json)")
            }
        }

        config.process = { resp -> NetworkResponse in
            guard self.decodeJsonArray else { return resp }
            let d = """
[
      {
        "title": "Wake up to WonderWidgets!",
        "type": "all"
      },
      {
        "items": [
          "Why <em>WonderWidgets</em> are great",
          "Who <em>buys</em> WonderWidgets"
        ],
        "title": "Overview",
        "type": "all"
      }
    ]
""".data(using: .utf8)!
            return (resp.0, resp.1, d)
        }
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testDecodeJsonArray() {
        decodeJsonArray = true
        asyncTest { (e) in
            HttpBin.getObject.execute(complete: { (result: Result<[Test.Slideshow.Slides]>) in
                print(try! result.get())
                e.fulfill()
            })
        }
    }

    func testDecodeJsonObject() {
        decodeJsonArray = false
        asyncTest { (e) in
            HttpBin.getObject.execute(complete: { (result: Result<Test>) in
                print(try! result.get())
                e.fulfill()
            })
        }
    }

    func testRawObject() {
        decodeJsonArray = false
        asyncTest { (e) in
            HttpBin.getObject.execute(complete: { (result: Result<Test>) in
                print(try! result.get())
                e.fulfill()
            })
        }
    }

    func testTimeOut() {
        asyncTest { (e) in
            HttpBin.stubTimeout.execute(complete: { (result: Result<Test>) in
                do {
                    _ = try result.get()
                    assertionFailure()
                } catch {
                    debugPrint(error.localizedDescription)
                    debugPrint(error)
                    debugPrint(error as NSError)
                }
                e.fulfill()
            })
        }
    }

    func testRandomDelay() {
        asyncTest { (e) in
            HttpBin.stubRandomDelay.execute(complete: { (result: Result<Test>) in
                print(String(describing: try? result.get()))
                e.fulfill()
            })
        }
    }

    func testWrongFormat() {
        asyncTest { (e) in
            HttpBin.stubWrongFormat.execute(complete: { (result: Result<Test>) in
                do {
                    _ = try result.get()
                    assertionFailure()
                } catch {
                    debugPrint(error.localizedDescription)
                    debugPrint(error)
                    debugPrint(error as NSError)
                }
                e.fulfill()
            })
        }
    }

    func asyncTest(timeout: TimeInterval = 80, block: (XCTestExpectation) -> ()) {
        let expectation: XCTestExpectation = self.expectation(description: "❌:Timeout")
        block(expectation)
        self.waitForExpectations(timeout: timeout) { (error) in
            if let err = error {
                XCTFail("time out: \(err)")
            } else {
                XCTAssert(true, "success")
            }
        }
    }
}

extension NetKitTests {
    func testCombineSupport() {
        asyncTest { (e) in
            _ = HttpBin.getObject.once()
                .sink(receiveCompletion: { state in
                    print(state)
                    e.fulfill()
                }, receiveValue: { (value: Test) in
                     print(value)
                })
        }
    }
}

enum HttpBin: NetKitRequestable {
    var configuration: RequestableConfiguration { return config }

    var baseURL: URL { return URL(string: "https://httpbin.org")! }
    var path: String {
        switch self {
        case .getObject:  return "json"
        case .stubTimeout: return "timeout"
        case .stubRandomDelay: return "randomDelay"
        case .stubWrongFormat: return "wrongFormat"
        }
    }
    
    var isMockEnabled: Bool {
        switch self {
        case .getObject: return false
        case .stubTimeout, .stubRandomDelay, .stubWrongFormat: return true
        }
    }

    case getObject
    case stubRandomDelay
    case stubTimeout
    case stubWrongFormat
}

struct Test: Codable {
    struct Slideshow: Codable {
        let author: String
        let date: String
        struct Slides: Codable {
            let title: String
            let type: String
            let items: [String]?
        }
        let slides: [Slides]
        let title: String
    }
    let slideshow: Slideshow
}
