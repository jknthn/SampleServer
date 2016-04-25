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

func setupRedisAPI() {
    
    // Redis setup
    #if os(OSX)
        let redisHost = "104.197.205.184"
    #else
        let redisHost = "10.240.0.9"
    #endif
    let redisPort: Int32 = 6379
    let redis = Redis()
    redis.connect(redisHost, port: redisPort) {error in
        if  let error = error {
            Log.error("Failed to connect to Redis server at \(redisHost):\(redisPort). Error=\(error.localizedDescription)")
        }
    }
    
    // This route accepts GET requests
    router.get("/redis/:key") { request, response, next in
        Log.debug("GET /redis/:key")
        response.setHeader("Content-Type", value: "text/plain; charset=utf-8")
        if let key = request.params["key"] {
            Log.debug("key=\(key)")
            redis.get(key) { (result: RedisString?, error: NSError?) in
                if let r = result where error == nil {
                    Log.debug("Found value for key: \(r.asString)")
                    do {
                        try response.status(HttpStatusCode.OK).send(r.asString).end()
                    } catch {
                        Log.error("Failed to send response \(error)")
                    }
                } else {
                    Log.error("Key not found")
                    response.error = error  ??  NSError(domain: "Redis",
                                                        code: 1,
                                                        userInfo: [NSLocalizedDescriptionKey:"Key not found"])
                }
                next()
            }
        } else {
            Log.error("Parameters not found")
            response.error = NSError(domain: "Redis",
                                     code: 1,
                                     userInfo: [NSLocalizedDescriptionKey:"Parameters not found"])
            next()
        }
    }
    
    // This route accepts PUT requests
    router.put("/redis/:key") {request, response, next in
        Log.debug("PUT /redis/:key")
        response.setHeader("Content-Type", value: "text/plain; charset=utf-8")
        if let key = request.params["key"],
            let value = request.queryParams["value"] {
            Log.debug("key=\(key), value=\(value)")
            redis.set(key, value: value) { (wasSet: Bool, error: NSError?) in
                if wasSet && error == nil {
                    Log.debug("Set value for a key")
                    do {
                        // logic goes here
                        try response.status(HttpStatusCode.OK).send("\(wasSet)").end()
                    } catch {
                        Log.error("Failed to send response \(error)")
                    }
                } else {
                    Log.error("Setting key failed")
                    response.error = error  ??  NSError(domain: "Redis",
                                                        code: 1,
                                                        userInfo: [NSLocalizedDescriptionKey: "Setting key failed"])
                }
                next()
            }
        } else {
            Log.error("Parameters not found")
            response.error = NSError(domain: "Redis",
                                     code: 1,
                                     userInfo: [NSLocalizedDescriptionKey: "Parameters not found"])
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
}




