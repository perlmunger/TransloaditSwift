//
//  TransloaditTask.swift
//
//  Created by Matt Long on 5/19/16.
//

import UIKit

let kBoredServerURL                            = "http://api2.transloadit.com/instances/bored"
let kDefaultExpirationInMinutes:TimeInterval = 120.0

class TransloaditTask {
    
    var apiKey:String
    var secretKey:String
    var session:URLSession
    var dateFormatter = DateFormatter()
    var result:[String:AnyObject]?
    var defaultTimeoutValue:TimeInterval = 300.0
    
    init(session:URLSession, apiKey:String, secretKey:String) {
        self.session = session
        self.apiKey = apiKey
        self.secretKey = secretKey
        self.dateFormatter.timeZone = TimeZone(identifier: "UTC")
        self.dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        self.dateFormatter.dateFormat = "yyyy/MM/dd HH:mm:ss+00:00"
        
    }
    
    func postData(_ fileData:Data, filename:String, fields:[String:String]?, templateIdentifier:String, completion:((_ json:[String:AnyObject]?, _ response:URLResponse?, _ error:NSError?) -> ())?) {
        // Request a server instance before sending the actual file
        let serverTask = self.session.dataTask(with: URLRequest(url: URL(string: kBoredServerURL)!), completionHandler: { (data, response, error) in
            guard let data = data, error == nil else { return }
            
            do {
                let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String:AnyObject]
                if let serverUrlString = json?["api2_host"] as? String, let serverUrl = URL(string: "http://" + serverUrlString + "/assemblies") {
                    
                    let formatString = "%@\r\nContent-Disposition: form-data; name=\"%@\"\r\n\r\n%@\r\n"
                    
                    DispatchQueue.main.async(execute: {
                        var body = Data()
                        
                        // Create a boundary to use for the multipart form data
                        let boundaryString = UUID().uuidString
                        let boundary = "--\(boundaryString)"
                        
                        // Add a timeout
                        let date = Date().addingTimeInterval(kDefaultExpirationInMinutes * 60)
                        
                        // This is required by transloadit. Create a params array and then convert it to an NSData
                        let params = ["template_id" : templateIdentifier, "auth" : ["expires" : self.dateFormatter.string(from: date), "key" : self.apiKey], "blocking" : "true"] as [String : Any]
                        
                        do {
                            let json = try JSONSerialization.data(withJSONObject: params, options: [])
                            
                            var current = String(format: "%@\r\nContent-Disposition: form-data; name=\"params\"\r\n\r\n", boundary)
                            body.append(current.data(using: String.Encoding.utf8)!)
                            // Append the resulting data object to the body
                            body.append(json)
                            body.append("\r\n".data(using: String.Encoding.utf8)!)
                            
                            // Generate the signature using the secret key and the JSON output as a string and
                            // append it to the body as well
                            current = String(format: formatString, boundary, "signature", String(data:json, encoding:String.Encoding.utf8)!.sha1WithKey(self.secretKey))
                            body.append(current.data(using: String.Encoding.utf8)!)
                        } catch {
                            
                        }
                        
                        // Append all the fields to the body
                        if let fields = fields {
                            for (key, value) in fields {
                                let current = String(format: formatString, boundary, key, value)
                                body.append(current.data(using: String.Encoding.utf8)!)
                            }
                        }
                        
                        // We're only sending one file, so append it to the body as well
                        let current = String(format: "%@\r\nContent-Disposition: form-data; name=\"%@\"; filename=\"%@\"\r\n\r\n", boundary, filename, filename)
                        
                        body.append(current.data(using: String.Encoding.utf8)!)
                        
                        // File contents as NSData
                        body.append(fileData)
                        
                        // Close out the file section
                        body.append("\r\n".data(using: String.Encoding.utf8)!)
                        
                        // Close out the whole multipart form
                        body.append(String(format: "--%@--\r\n", boundaryString).data(using: String.Encoding.utf8)!)
                        
                        // Create the URL Request
                        let request = NSMutableURLRequest(url: serverUrl)
                        // Set the content type, method and body
                        request.setValue(String(format: "multipart/form-data; boundary=%@", boundaryString), forHTTPHeaderField: "Content-Type")
                        request.httpMethod = "POST"
                        request.httpBody = body as Data
                        
                        // The the content lengths and timeout interval for the request
                        request.setValue(String(format: "%lu", body.count), forHTTPHeaderField: "Content-Length")
                        request.timeoutInterval = self.defaultTimeoutValue
                        
                        let dataTask = self.session.dataTask(with: request as URLRequest, completionHandler: { (responseData, uploadResponse, uploadError) in
                            if uploadError != nil {
                                DispatchQueue.main.async(execute: {
                                    completion?(nil, uploadResponse, uploadError as NSError?)
                                })
                            }
                            guard let responseData = responseData, let httpResponse = uploadResponse as? HTTPURLResponse else {
                                DispatchQueue.main.async(execute: {
                                    completion?(nil, uploadResponse, uploadError as NSError?)
                                })
                                return
                            }
                            
                            var json:[String:AnyObject]?
                            do {
                                json = try JSONSerialization.jsonObject(with: responseData, options: []) as? [String:AnyObject]
                            } catch {
                                json = nil
                            }
                            
                            // Set the local variable which can be access when the request finishes
                            self.result = json?["results"] as? [String:AnyObject]
                            
                            DispatchQueue.main.async(execute: {
                                completion?(json, httpResponse, uploadError as NSError?)
                            })
                            
                        })
                        
                        dataTask.resume()
                    })
                    
                }
                
            } catch {
                
            }
        })
        
        serverTask.resume()
    }
    
    var resultSteps : [String]? {
        guard let result = self.result else {
            return nil
        }
        return Array(result.keys)
    }
    
    subscript(stepName:String) -> [String:AnyObject]? {
        get {
            guard let result = self.result, let resultObject = result[stepName] as? [[String:AnyObject]] else {
                return nil
            }
            // This implementation only uploads a single file, so there
            // should only be one result per step. Return the first one.
            return resultObject.first
        }
    }
}

// Create a string extension for handling the SHA1 encryption
extension String {
    func sha1WithKey(_ secretKey:String) -> String {
        let data = self.cString(using: String.Encoding.ascii)
        let key = secretKey.cString(using: String.Encoding.ascii)
        
        let dataLen = Int(self.lengthOfBytes(using: String.Encoding.ascii))
        let keyLen = Int(secretKey.lengthOfBytes(using: String.Encoding.ascii))
        
        let digestLen = Int(CC_SHA1_DIGEST_LENGTH)
        let result = UnsafeMutablePointer<CUnsignedChar>.allocate(capacity: digestLen)
        CCHmac(CCHmacAlgorithm(kCCHmacAlgSHA1), key!, keyLen, data!, dataLen, result)
        
        return self.hexStringWithData(result, ofLength: digestLen) as String
    }
    
    func hexStringWithData(_ data:UnsafeMutablePointer<CUnsignedChar>, ofLength:Int) -> NSString {
        var tmp = String()
        for i:Int in 0..<ofLength {
            tmp = tmp.appendingFormat("%02x", data[i])
        }
        return NSString(string: tmp)
    }
}
