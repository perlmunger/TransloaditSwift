//
//  TransloaditTask.swift
//
//  Created by Matt Long on 5/19/16.
//

import UIKit

let kBoredServerURL                            = "http://api2.transloadit.com/instances/bored"
let kDefaultExpirationInMinutes:NSTimeInterval = 120.0

class TransloaditTask {
    
    var apiKey:String
    var secretKey:String
    var session:NSURLSession
    var dateFormatter = NSDateFormatter()
    var result:[String:AnyObject]?
    var defaultTimeoutValue:NSTimeInterval = 300.0
    
    init(session:NSURLSession, apiKey:String, secretKey:String) {
        self.session = session
        self.apiKey = apiKey
        self.secretKey = secretKey
        self.dateFormatter.timeZone = NSTimeZone(name: "UTC")
        self.dateFormatter.locale = NSLocale(localeIdentifier: "en_US_POSIX")
        self.dateFormatter.dateFormat = "yyyy/MM/dd HH:mm:ss+00:00"
        
    }
    
    func postData(fileData:NSData, filename:String, fields:[String:String]?, templateIdentifier:String, completion:((json:[String:AnyObject]?, response:NSURLResponse?, error:NSError?) -> ())?) {
        // Request a server instance before sending the actual file
        let serverTask = self.session.dataTaskWithRequest(NSURLRequest(URL: NSURL(string: kBoredServerURL)!)) { (data, response, error) in
            guard let data = data where error == nil else { return }
            
            do {
                let json = try NSJSONSerialization.JSONObjectWithData(data, options: []) as? [String:AnyObject]
                if let serverUrlString = json?["api2_host"] as? String, serverUrl = NSURL(string: "http://" + serverUrlString + "/assemblies") {
                    
                    let formatString = "%@\r\nContent-Disposition: form-data; name=\"%@\"\r\n\r\n%@\r\n"
                    
                    dispatch_async(dispatch_get_main_queue(), {
                        let body = NSMutableData()

                        // Create a boundary to use for the multipart form data
                        let boundaryString = NSUUID().UUIDString
                        let boundary = "--\(boundaryString)"

                        // Add a timeout
                        let date = NSDate().dateByAddingTimeInterval(kDefaultExpirationInMinutes * 60)
                        
                        // This is required by transloadit. Create a params array and then convert it to an NSData
                        let params = ["template_id" : templateIdentifier, "auth" : ["expires" : self.dateFormatter.stringFromDate(date), "key" : self.apiKey], "blocking" : "true"]
                        
                        do {
                            let json = try NSJSONSerialization.dataWithJSONObject(params, options: [])
                            
                            var current = String(format: "%@\r\nContent-Disposition: form-data; name=\"params\"\r\n\r\n", boundary)
                            body.appendData(current.dataUsingEncoding(NSUTF8StringEncoding)!)
                            // Append the resulting data object to the body
                            body.appendData(json)
                            body.appendData("\r\n".dataUsingEncoding(NSUTF8StringEncoding)!)

                            // Generate the signature using the secret key and the JSON output as a string and 
                            // append it to the body as well
                            current = String(format: formatString, boundary, "signature", String(data:json, encoding:NSUTF8StringEncoding)!.sha1WithKey(self.secretKey))
                            body.appendData(current.dataUsingEncoding(NSUTF8StringEncoding)!)
                        } catch {
                            
                        }

                        // Append all the fields to the body
                        if let fields = fields {
                            for (key, value) in fields {
                                let current = String(format: formatString, boundary, key, value)
                                body.appendData(current.dataUsingEncoding(NSUTF8StringEncoding)!)
                            }
                        }

                        // We're only sending one file, so append it to the body as well
                        let current = String(format: "%@\r\nContent-Disposition: form-data; name=\"%@\"; filename=\"%@\"\r\n\r\n", boundary, filename, filename)
                        
                        body.appendData(current.dataUsingEncoding(NSUTF8StringEncoding)!)
                        
                        // File contents as NSData
                        body.appendData(fileData)
                        
                        // Close out the file section
                        body.appendData("\r\n".dataUsingEncoding(NSUTF8StringEncoding)!)

                        // Close out the whole multipart form
                        body.appendData(String(format: "--%@--\r\n", boundaryString).dataUsingEncoding(NSUTF8StringEncoding)!)
                        
                        // Create the URL Request
                        let request = NSMutableURLRequest(URL: serverUrl)
                        // Set the content type, method and body
                        request.setValue(String(format: "multipart/form-data; boundary=%@", boundaryString), forHTTPHeaderField: "Content-Type")
                        request.HTTPMethod = "POST"
                        request.HTTPBody = body
                        
                        // The the content lengths and timeout interval for the request
                        request.setValue(String(format: "%lu", body.length), forHTTPHeaderField: "Content-Length")
                        request.timeoutInterval = self.defaultTimeoutValue
                        
                        let dataTask = self.session.dataTaskWithRequest(request, completionHandler: { (responseData, uploadResponse, uploadError) in
                            if uploadError != nil {
                                dispatch_async(dispatch_get_main_queue(), {
                                    completion?(json:nil, response:uploadResponse, error:uploadError)
                                })
                            }
                            guard let responseData = responseData, httpResponse = uploadResponse as? NSHTTPURLResponse else {
                                dispatch_async(dispatch_get_main_queue(), {
                                    completion?(json:nil, response:uploadResponse, error:uploadError)
                                })
                                return
                            }
                            
                            var json:[String:AnyObject]?
                            do {
                                json = try NSJSONSerialization.JSONObjectWithData(responseData, options: []) as? [String:AnyObject]
                            } catch {
                                json = nil
                            }
                            
                            // Set the local variable which can be access when the request finishes
                            self.result = json?["results"] as? [String:AnyObject]
                            
                            dispatch_async(dispatch_get_main_queue(), {
                                completion?(json:json, response:httpResponse, error:uploadError)
                            })

                        })
                        
                        dataTask.resume()
                    })
                    
                }
                
            } catch {
                
            }
        }
        
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
            guard let result = self.result, resultObject = result[stepName] as? [[String:AnyObject]] else {
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
    func sha1WithKey(secretKey:String) -> String {
        let data = self.cStringUsingEncoding(NSASCIIStringEncoding)
        let key = secretKey.cStringUsingEncoding(NSASCIIStringEncoding)
        
        let dataLen = Int(self.lengthOfBytesUsingEncoding(NSASCIIStringEncoding))
        let keyLen = Int(secretKey.lengthOfBytesUsingEncoding(NSASCIIStringEncoding))
        
        let digestLen = Int(CC_SHA1_DIGEST_LENGTH)
        let result = UnsafeMutablePointer<CUnsignedChar>.alloc(digestLen)
        CCHmac(CCHmacAlgorithm(kCCHmacAlgSHA1), key!, keyLen, data!, dataLen, result)
        
        return self.hexStringWithData(result, ofLength: digestLen) as String
    }
    
    func hexStringWithData(data:UnsafeMutablePointer<CUnsignedChar>, ofLength:Int) -> NSString {
        let tmp = NSMutableString()
        for i:Int in 0..<ofLength {
            tmp.appendFormat("%02x", data[i])
        }
        return NSString(string: tmp)
    }
}