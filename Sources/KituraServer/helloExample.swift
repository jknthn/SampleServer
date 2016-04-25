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

func setupHelloAPI() {
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
}