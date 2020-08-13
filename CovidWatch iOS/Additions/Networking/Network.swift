//
//  Network.swift
//  CovidWatch
//
//  Created by Christopher McGraw on 6/3/20.
//

class Network: NSObject {

    class func request<T: Codable>(router: Request, completion: @escaping (Result<T, Error>) -> ()) {
        guard let request = constructRequest(router: router) else { return }
        let config: URLSessionConfiguration = .default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 10
        let session = URLSession(configuration: config, delegate: Network(), delegateQueue: OperationQueue.main)
        let dataTask = session.dataTask(with: request) { data, response, error in
            logRequest(request: request, data: data, response: response as? HTTPURLResponse, error: error)
            
            if let error = error {
                completion(.failure(error))
                return
            }
            
            if let data = data {
                do {
                    let responseData = try JSONDecoder().decode(T.self, from: data)
                    completion(.success(responseData))
                } catch{
                    do{
                        if let newData = data as? T {
                            completion(.success(newData))
                        } else {
                            completion(.failure(error))
                        }
                    }
                }
            }
            
        }
        dataTask.resume()
    }

    private class func constructRequest(router: Request) -> URLRequest? {
        let urlComponents = getUrlComponents(router: router)
        guard let url = urlComponents.url else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = router.method
        request.httpBody = router.body?.toJSONData()

        for (header, value) in router.headers {
            request.addValue(value, forHTTPHeaderField: header)
        }

        return request
    }

    private class func getUrlComponents(router: Request) -> URLComponents {
        var components = URLComponents()
        components.scheme = router.scheme
        components.host = router.host
        components.path = router.path
        if (router.parameters.count > 0) {
            components.queryItems = router.parameters
        }

        return components
    }
    
    private class func logRequest(request: URLRequest, data: Data?, response: HTTPURLResponse?, error: Error?) {
        
        guard let requestStr = logStringForURLRequest(request), let responseStr = self.logStringForHTTP(data: data, response: response, error: error) else {
            return
        }

        LogManager.sharedManager.writeLog(entry: LogEntry(source: Network(), message: "\n\n# HTTP MESSAGE\n\(requestStr)\(responseStr)"))

    }
    
    private class func logStringForURLRequest(_ request: URLRequest) -> String? {
        
        guard let httpMethod = request.httpMethod, let url = request.url, let allHTTPHeaderFields = request.allHTTPHeaderFields else {
            LogManager.sharedManager.writeLog(entry: LogEntry(source: Network(), level: .error, message: "Request properties are nil"))
            return nil
        }
        
        var lines = [String]()
        lines.append(String(format: "%@ %@ HTTP/1.1", httpMethod, url.absoluteString))
        
        for name in allHTTPHeaderFields {
            let key = name.key
            if let value = allHTTPHeaderFields[key] {
                lines.append(String(format: "%@: %@", name.key, value))
            }
        }
        
        lines.append("")
        
        if let httpBody = request.httpBody, httpBody.count > 0 {
            if let body = String(data: httpBody, encoding: .utf8) {
                lines.append(body)
            } else {
                lines.append("[binary data]")
            }
        }
        
        return String(format: "\n## REQUEST\n\n```\n%@\n```\n", lines.joined(separator: "\n"))
        
    }
    
    private class func logStringForHTTP(data: Data?, response: HTTPURLResponse?, error: Error?) -> String? {
        
        var lines = [String]()

        if let response = response {
            lines.append(String(format: "HTTP/1.1 %d", response.statusCode))
            
            for name in response.allHeaderFields {
                let key = name.key
                if let value = response.allHeaderFields[key] as? String {
                    lines.append(String(format: "%@: %@", key as CVarArg, value))
                }
            }
        } else {
            lines.append("HTTP/1.1 --- No Response ---")
        }
        
        lines.append("")
        
        if let data = data, let dataStr = String(data: data, encoding: .utf8) {
            lines.append(dataStr)
        } else if let responseStr = error?.localizedDescription {
            lines.append(responseStr)
        }

        return String(format: "\n## RESPONSE\n\n```\n%@\n```\n", lines.joined(separator: "\n"))
    }
    
}

extension Network: URLSessionDataDelegate {
    
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, willCacheResponse proposedResponse: CachedURLResponse, completionHandler: @escaping (CachedURLResponse?) -> Void) {
        completionHandler(nil)
    }
    
}
