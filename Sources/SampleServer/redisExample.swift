import Foundation
import Kitura
import HeliumLogger
import LoggerAPI

import SwiftRedis
import SwiftyJSON

#if os(Linux)
    import Glibc
#endif

//MARK: API /redis
let redis = Redis()

func setupRedisAPI(router: Kitura.Router) {
    
    // Redis setup
    #if os(OSX)
        // This will not work
        // Redis external IP is currently disabled
        let redisHost = "104.197.205.184"
    #else
        let redisHost = "10.132.0.3"
    #endif
    let redisPort: Int32 = 6379
    redis.connect(host: redisHost, port: redisPort) {error in
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
                        try response.status(.OK).send(r.asString).end()
                    } catch {
                        Log.error("Failed to send response \(error)")
                    }
                } else {
                    Log.error("Key not found")
                    response.error = error  ??  NSError(domain: "Redis",
                                                        code: 1,
                                                        userInfo: [NSLocalizedDescriptionKey: "Key not found"])
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
                        try response.status(.OK).send("\(wasSet)").end()
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
        response.setHeader("Content-Type", value: "text/plain; charset=utf-8")
        if let key = request.params["key"] {
            Log.debug("key=\(key)")
            redis.del(key) { (length: Int?, error: NSError?) in
                if let l = length where error == nil {
                    Log.debug("Number of keys deleted: \(l)")
                    do {
                        try response.status(.OK).send("\(l)").end()
                    } catch {
                        Log.error("Failed to send response \(error)")
                    }
                } else {
                    Log.error("Key not found")
                    response.error = error  ??  NSError(domain: "Redis",
                                                        code: 1,
                                                        userInfo: [NSLocalizedDescriptionKey: "Key not found"])
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
}