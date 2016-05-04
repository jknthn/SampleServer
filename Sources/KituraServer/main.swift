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
import Kitura
import HeliumLogger

import SwiftRedis
import MongoKitten
import SwiftyJSON

#if os(Linux)
    import Glibc
#endif

import Foundation
import KituraMustache

// MARK: Setup

// All Web apps need a router to define routes
let router = Kitura.Router()

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

// Using an implementation for a Logger
Log.logger = HeliumLogger()

setupRedisAPI()
setupMongoAPI(router)
setupHelloAPI()
defaultSetup()

// Listen on port 8090
let server = HttpServer.listen(8090, delegate: router)
Server.run()