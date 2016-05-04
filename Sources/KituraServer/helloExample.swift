import Foundation

import Kitura
import KituraNet

import HeliumLogger
import LoggerAPI

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