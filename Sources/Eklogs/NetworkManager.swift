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
    let offsets: T?
    let result: T?
    var data: T? {
        return offsets ?? result
    }
    var hasData: Bool {
        return data != nil
    }
    let msg: String
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

let baseURL = "https://eklogs-sdk.ekbana.net/api/v1/"

enum EndPoint {
    case log(String)
    case event(String)
    case info(String)
    
    private var path: String {
        switch self {
        case .log(let projectID): return "init/\(projectID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? "")"
        case .event(let projectID): return "event/\(projectID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? "")"
        case .info(let domain): return "sdk_info/\(domain.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? "")"
        }
    }
    
    private var method: String {
        switch self {
        case .log, .event:
            return "POST"
        default:
            return "GET"
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
        return LogRequest(request: request, endPoint: self)
    }
    
    func request(body: [String: Any]? = nil) -> LogRequest {
        let urlString = baseURL + path
        return request(urlString: urlString, body: body)
    }
    
}

extension URLSession {
    
    @discardableResult
    func dataTask<T:Codable>(request: LogRequest, success: @escaping (T?) -> (), failure: @escaping (Error) -> ()) -> URLSessionDataTask {
        let task = dataTask(with: request.request) { [weak self] (data, response, error) in
            self?.handle(data: data, response: response, error: error, success: { (successData: SingleContainer<T>) in
                debugPrint(request.request.url?.absoluteURL ?? "")
                success(successData.data)
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
        
        if let data = data,
           let string = String(data: data, encoding: .utf8) {
            debugPrint(string)
        }
        if let data = data {
            do {
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                let container = try decoder.decode(T.self, from: data)
                return send(object: container)
            } catch {
                debugPrint(error)
            }
        }
        return send(error: NSError(domain: "EKLogs", code: 500, userInfo: [NSLocalizedDescriptionKey: "Something went wrong."]))
    }
}
