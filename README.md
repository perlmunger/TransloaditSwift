# Transloadit Swift

The official [Transloadit iOS-SDK library](https://github.com/transloadit/ios-sdk) provides an Objective-C implementation that will probably suffice for many users attempting to use their service, however, it leaves a few things to be desired:

- The library is a bit out of date so there are deprecation warnings
- The library is a bit large and monolithic as it tries to cover all use cases
- The library uses an old syncrhonous API for network connections that make it necessary for the user to use it in an NSOperation or a dispatch_queue
- There is no Swift implementation of the library currently

While none of these are complete show stoppers, they make using the library a little cumbersome. I decided to write a small Swift class the encapsulates the functionality I personally need for my applications and leaves the rest unimplemented. My goals included:

- Build a simple class that handles the network connection and pushing the data to the transloadit server using modern APIs like NSURLSession
- Write the class in Swift using a closure API that makes it simple to be called back after processing
- Add a few convenience functions and extensions to help interrogate the data structure that comes back from Transloadit on a successful upload
- Only allows a single file to be uploaded at a time
- You cannot specify your steps on the app side. They have to be created on the Transloadit website and used directly with an assembly identifier.

**Take a look at the Assembly.json file that is part of the Xcode project to see how my assembly is implemented on the Transloadit site**

## Installation

### Pods

Right. Yeah. No.

### Copy the Swift File To Your Project and Add a Brigding header

Yep. That's it. You will need to add a bridging header because the class uses the common crypto classes. You can take a look at the bridging header in the Xcode project to see how it's done. You're just going to import the Common Crypto library by adding this line to your bridging header:

```objective-c
#import <CommonCrypto/CommonCrypto.h>
```

If you haven't already added a bridging header to your project, you will need to select 'File New | File..." in Xcode and select a header file in the source category.

![New Header File in Xcode](http://i.imgur.com/hUBSmbs.png)

Make sure you name the file [Project Name]-Bridging-Header.h where 'Project Name' is the name of the project you're adding it to. Then, in your project settings, specify the path to the bridging header in the "Swift Compler - Code Generation" section--specifically the "Objective-C Bridging Header" field:

![Project Settings](http://i.imgur.com/iGRvN0K.png)

## Usage

The class that I created allows you to perform an upload to Transloadit with the following:

```swift
// Grab the image from the image view just to demonstrate uploading a file
if let image = self.imageView.image {
    
    // Create a TransloaditTaks object passing it a NSURSession that it will use as well as your API key and secret key
    let task = TransloaditTask(session: NSURLSession.sharedSession(), apiKey: transloaditAPIKey, secretKey: transloaditSecretKey)
    
    // These are fields that my assembly uses. Yours are going to be different if you use them at all.
    // See the "Assembly.json" file in the Xcode project to see how these fields are used on the
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
```

## The Sample Xcode Project

The project that I included is a universal iOS application that displays an image in an image view. When you tap an upload button, the app grabs the image in the UIImageView and uploads it to Transloadit using an Assembly I created in my account. The example assembly file is included as part of the Xcode project and is named Assembly.json.

## Support

I don't provide any. Feel free to post questions in the Github issues, but I may or may not answer them. The best/quickest way to add something or make a change is to submit a pull request. I'll take a look and see if it makes sense to merge it in.