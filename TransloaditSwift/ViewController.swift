//
//  ViewController.swift
//  TransloaditSwift
//
//  Created by Matt Long on 5/21/16.
//  Copyright © 2016 Matt Long. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    @IBOutlet var imageView:UIImageView!
    
    let transloaditAPIKey    = "TRANSLOADIT_API_KEY"
    let transloaditSecretKey = "TRANSLOADIT_SECRET_KEY"
    let transloaditTemplate  = "TRANSLOADIT_TEMPLATE_ID"
    
    override func viewDidLoad() {
        super.viewDidLoad()

    }
    
    @IBAction func didTapUpload(sender:AnyObject) {
    
        // Grab the image from the image view just to demonstrate uploading a file
        if let image = self.imageView.image {
            
            // Create a TransloaditTask object passing it a NSURSession that it will use as well as your API key and secret key
            let task = TransloaditTask(session: NSURLSession.sharedSession(), apiKey: transloaditAPIKey, secretKey: transloaditSecretKey)
            
            // These are fields that my template uses. Yours are going to be different if you use them at all.
            // See the "Template.json" file in the Xcode project to see how these fields are used on the
            // server side.
            let fields = ["corp_id" : "AABBCCDDEEFF", "major" : "123456", "minor": "1234567", "device_id" : UIDevice.currentDevice().identifierForVendor!.UUIDString]
            
            // Turn on the network activity indicator
            UIApplication.sharedApplication().networkActivityIndicatorVisible = true
            
            // Make sure our image is valid
            if let imageData = UIImageJPEGRepresentation(image, 1.0) {
                
                // Call post data on the Transloadit Task object passing it the necessary variables and a completion block
                task.postData(imageData, filename: "HotAirBalloon.jpg", fields:fields, templateIdentifier: transloaditTemplate, completion: { (json, response, error) in
                    
                    // When the request finishes, turn off the network activity indicator
                    UIApplication.sharedApplication().networkActivityIndicatorVisible = false
                    
                    // Print out the full JSON to the console to see what we got
                    print(json)
                    
                    // Print a list of the steps found in the result JSON
                    print(task.resultSteps)
                    
                    // Alternatively, we can use the overloaded subscript operator on the taksk to retrieve
                    // the first result from the step called ":original"
                    if let step1 = task[":original"] {
                        
                        // Do something with the json result for step 1
                        print(step1)
                    }
                    
                    

                })
            }
        }
        

    }


}

