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

import KituraSys
import KituraNet
import Kitura

import LoggerAPI
import HeliumLogger

import SwiftRedis
import MongoKitten
import SwiftyJSON
import CouchDB

#if os(Linux)
    import Glibc
#endif

import Foundation
import KituraMustache

// MARK: Setup
// All Web apps need a router to define routes
let router = Router()

// Using an implementation for a Logger
Log.logger = HeliumLogger()

// Redis setup
let redisHost = "10.240.0.9"
let redisPort: Int32 = 6379
let redis = Redis()
redis.connect(redisHost, port: redisPort) {error in
    if  let error = error {
        Log.error("Failed to connect to Redis server at \(redisHost):\(redisPort). Error=\(error.localizedDescription)")
    }
}

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

//MARK: API /redis
// This route accepts GET requests
router.get("/redis/:key") { request, response, next in
    Log.debug("GET /redis/:key")
    response.setHeader("Content-Type", value: "application/json; charset=utf-8")
    if let key = request.params["key"] {
        Log.debug("key=\(key)")
        redis.get(key) { (result: RedisString?, error: NSError?) in
            if let r = result where error == nil {
                Log.debug("Found key")
                do {
                    try response.status(HttpStatusCode.OK).send(r.asString).end()
                } catch {
                    Log.error("Failed to send response \(error)")
                }
            } else {
                Log.error("Key not found")
                response.error = error  ??  NSError(domain: "Redis", code: 1, userInfo: [NSLocalizedDescriptionKey:"Key not found"])
            }
            next()
        }
    } else {
        Log.error("Parameters not found")
        response.error = NSError(domain: "Redis", code: 1, userInfo: [NSLocalizedDescriptionKey:"Parameters not found"])
        next()
    }
}

// This route accepts PUT requests
router.put("/redis/:key") {request, response, next in
    Log.debug("PUT /redis/:key")
    response.setHeader("Content-Type", value: "application/json; charset=utf-8")
    if let key = request.params["key"],
        let value = request.queryParams["value"] {
        Log.debug("key=\(key), value=\(value)")
        redis.set(key, value: value) { (wasSet: Bool, error: NSError?) in
            if wasSet && error == nil {
                Log.debug("Set value for a key")
                do {
                    try response.status(HttpStatusCode.OK).send("\(wasSet)").end()
                } catch {
                    Log.error("Failed to send response \(error)")
                }
            } else {
                Log.error("Setting key failed")
                response.error = error  ??  NSError(domain: "Redis", code: 1, userInfo: [NSLocalizedDescriptionKey:"Setting key failed"])
            }
            next()
        }
    } else {
        Log.error("Parameters not found")
        response.error = NSError(domain: "Redis", code: 1, userInfo: [NSLocalizedDescriptionKey:"Parameters not found"])
        next()
    }
}

// This route accepts DELETE requests
router.delete("/redis/:key") {request, response, next in
    Log.debug("DELETE /redis/:key")
    response.setHeader("Content-Type", value: "application/json; charset=utf-8")
    if let key = request.params["key"] {
        Log.debug("key=\(key)")
        redis.del(key) { (length: Int?, error: NSError?) in
            if let l = length where error == nil {
                Log.debug("Number of keys deleted: \(l)")
                do {
                    try response.status(HttpStatusCode.OK).send("\(l)").end()
                } catch {
                    Log.error("Failed to send response \(error)")
                }
            } else {
                Log.error("Key not found")
                response.error = error  ??  NSError(domain: "Redis", code: 1, userInfo: [NSLocalizedDescriptionKey:"Key not found"])
            }
            next()
        }
    } else {
        Log.error("Parameters not found")
        response.error = NSError(domain: "Redis", code: 1, userInfo: [NSLocalizedDescriptionKey:"Parameters not found"])
        next()
    }
}

//MARK: /hello
router.get("/hello") { _, response, next in
    response.setHeader("Content-Type", value: "text/plain; charset=utf-8")
    do {
        try response.status(HttpStatusCode.OK).send("Hello World, from Kitura!").end()
    } catch {
        Log.error("Failed to send response \(error)")
    }
}

// This route accepts POST requests
router.post("/hello") {request, response, next in
    response.setHeader("Content-Type", value: "text/plain; charset=utf-8")
    do {
        try response.status(HttpStatusCode.OK).send("Got a POST request").end()
    } catch {
        Log.error("Failed to send response \(error)")
    }
}

// This route accepts PUT requests
router.put("/hello") {request, response, next in
    response.setHeader("Content-Type", value: "text/plain; charset=utf-8")
    do {
        try response.status(HttpStatusCode.OK).send("Got a PUT request").end()
    } catch {
        Log.error("Failed to send response \(error)")
    }
}

// This route accepts DELETE requests
router.delete("/hello") {request, response, next in
    response.setHeader("Content-Type", value: "text/plain; charset=utf-8")
    do {
        try response.status(HttpStatusCode.OK).send("Got a DELETE request").end()
    } catch {
        Log.error("Failed to send response \(error)")
    }
}

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

// Reading parameters
// Accepts user as a parameter
router.get("/users/:user") { request, response, next in
    response.setHeader("Content-Type", value: "text/html; charset=utf-8")
    let p1 = request.params["user"] ?? "(nil)"
    do {
        try response.status(HttpStatusCode.OK).send(
            "<!DOCTYPE html><html><body>" +
                "<b>User:</b> \(p1)" +
            "</body></html>\n\n").end()
    } catch {
        Log.error("Failed to send response \(error)")
    }
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

// Listen on port 8090
let server = HttpServer.listen(8090, delegate: router)
Server.run()