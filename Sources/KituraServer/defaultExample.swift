import Foundation

import Kitura
import KituraNet

import HeliumLogger
import LoggerAPI

#if os(Linux)
    import Glibc
#endif

//MARK: API /redis

func defaultSetup() {
    
    router.all("/static", middleware: StaticFileServer())
    
    // Error handling example
    router.get("/error") { _, response, next in
        Log.error("Example of error being set")
        response.status(HttpStatusCode.INTERNAL_SERVER_ERROR)
        response.error = NSError(domain: "RouterTestDomain", code: 1, userInfo: [:])
        next()
    }
    
    // Redirection example
    router.get("/redir") { _, response, next in
        do {
            try response.redirect("http://www.ibm.com")
        } catch {
            Log.error("Failed to redirect \(error)")
        }
        next()
    }
    
    // Uses multiple handler blocks
    router.get("/multi", handler: { request, response, next in
        response.status(HttpStatusCode.OK).send("I'm here!\n")
        next()
        }, { request, response, next in
            response.send("Me too!\n")
            next()
    })
    router.get("/multi") { request, response, next in
        response.status(HttpStatusCode.OK).send("I come afterward..\n")
        next()
    }
    
    // Handles any errors that get set
    router.error { request, response, next in
        response.setHeader("Content-Type", value: "text/plain; charset=utf-8")
        do {
            let errorDescription: String
            if let error = response.error {
                errorDescription = "\(error)"
            } else {
                errorDescription = "Unknown error"
            }
            try response.send("Caught the error: \(errorDescription)").end()
        }
        catch {
            Log.error("Failed to send response \(error)")
        }
    }
    // A custom Not found handler
    router.all { request, response, next in
        if  response.statusCode == .NOT_FOUND  {
            // Remove this wrapping if statement, if you want to handle requests to / as well
            if  request.originalUrl != "/"  &&  request.originalUrl != ""  {
                do {
                    try response.send("Route not found in Sample application!").end()
                }
                catch {
                    Log.error("Failed to send response \(error)")
                }
            }
        }
        next()
    }
}