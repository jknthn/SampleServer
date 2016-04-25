/**
 * Copyright IBM Corporation 2016
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 **/

// KituraSample shows examples for creating custom routes.
import Foundation

import KituraSys
import KituraNet
import Kitura

import LoggerAPI
import HeliumLogger

import SwiftRedis

#if os(Linux)
    import Glibc
#endif

//MARK: API /redis

func defaultSetup() {
    
    /**
     * RouterMiddleware can be used for intercepting requests and handling custom behavior
     * such as authentication and other routing
     */
    class BasicAuthMiddleware: RouterMiddleware {
        func handle(request: RouterRequest, response: RouterResponse, next: () -> Void) {
            
            let authString = request.headers["Authorization"]
            
            Log.info("Authorization: \(authString)")
            
            // Check authorization string in database to approve the request if fail
            // response.error = NSError(domain: "AuthFailure", code: 1, userInfo: [:])
            
            next()
        }
    }
    
    // This route executes the echo middleware
    router.all(middleware: BasicAuthMiddleware())
    
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
        if  response.getStatusCode() == .NOT_FOUND  {
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




