//
//  File.swift
//  
//
//  Created by bibek timalsina on 07/01/2021.
//

import Foundation

protocol Container: Codable {
    
}

struct SingleContainer<T: Codable>: Container {
    let data: T?
}

struct LogResponse: Codable {
    
}

struct LogRequest {
    var request: URLRequest
    let endPoint: EndPoint
    
    init(request: URLRequest, endPoint: EndPoint) {
        self.request = request
        self.endPoint = endPoint
    }
}

enum EndPoint {
    case authenticate
    case log
    case event
    
    private var path: String {
        switch self {
        case .authenticate: return ""
        case .log: return "ekmobile-bigmart-dev"
        case .event: return "ekmobile-bigmart-event-dev"
        }
    }
    
    private var method: String {
        switch self {
        case .log, .event, .authenticate:
            return "POST"
//        default:
//            return "GET"
        }
    }
    
    func request(urlString: String, body: [String: Any]? = nil) -> LogRequest {
        let url = URL(string: urlString)!
        debugPrint(url)
        var request = URLRequest(url: url)
        request.httpMethod = method
        if method == "POST" || method == "DELETE" || method == "PUT" {
            request.setValue("application/vnd.kafka.json.v2+json", forHTTPHeaderField: "Content-Type")
            if let body = body {
                request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: .prettyPrinted)
            }
        }
        //        request.setValue(Configuration.conf.apiKey, forHTTPHeaderField: "Api-Key")
        //        request.setValue(Localize.currentLanguage(), forHTTPHeaderField: "Accept-Language")
        //        if let token = GlobalConstanst.KeyValues.accessToken?.token {
        //            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        //        }
        return LogRequest(request: request, endPoint: self)
    }
    
    func request(body: [String: Any]? = nil) -> LogRequest {
        let urlString = "https://drk.ekbana.net/topics/" + path
        return request(urlString: urlString, body: body)
    }
    
}

extension URLSession {
    
    @discardableResult
    func dataTask<T:Codable>(request: LogRequest, success: @escaping (T) -> (), failure: @escaping (Error) -> ()) -> URLSessionDataTask {
        let task = dataTask(with: request.request) { [weak self] (data, response, error) in
            self?.handle(data: data, response: response, error: error, success: { (successData: SingleContainer<T>) in
                debugPrint(request.request.url?.absoluteURL ?? "")
                success(successData.data!)
            }, failure: { error in
                debugPrint(request.request.url?.absoluteURL ?? "")
                failure(error)
            })
        }
        task.resume()
        return task
    }
    
    private func handle<T: Container>(data: Data?, response: URLResponse?, error: Error?, success: @escaping (T)->(), failure: @escaping (Error) -> ()) {
        func send(error: Error) {
            DispatchQueue.main.async {
                failure(error)
            }
        }
        
        func send(object: T) {
            DispatchQueue.main.async {
                success(object)
            }
        }
        
        if (error as NSError?)?.code == -999 {return}
        
        if let error = error {
            return send(error: error)
        }
        
        if let data = data,
            let json = try? JSONSerialization.jsonObject(with: data, options: .allowFragments) {
            debugPrint(json)
        }
//        let statuscode = (response as? HTTPURLResponse)?.statusCode ?? 500
        if let data = data {
            do {
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                let container = try decoder.decode(T.self, from: data)
//                if let error = container.allErrors?.first?.error {
//                    return send(error: error)
//                }
//                if container.hasData {
                return send(object: container)
//                }
            } catch {
                debugPrint(error)
            }
        }
        return send(error: NSError(domain: "EKLogs", code: 500, userInfo: [NSLocalizedDescriptionKey: "Something went wrong."]))
    }
}
