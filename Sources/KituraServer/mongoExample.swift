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

import MongoKitten
import SwiftyJSON

#if os(Linux)
    import Glibc
#endif

//MARK: API /mongo

var mongo: MongoKitten.Server!
var workingCollection: MongoKitten.Collection {
    let database: MongoKitten.Database = mongo["example"]
    let userCollection: MongoKitten.Collection = database["users"]
    return userCollection
}

struct Model {
    var username: String? = ""
    var name: String? = ""
    var surname: String? = ""
    var age: Int? = 0
    
    func toBSON() -> Document {
        return [
                   "username": (self.username ?? ""),
                   "name": (self.name ?? ""),
                   "surname": (self.surname ?? ""),
                   "age": (self.age ?? 0)
        ]
    }
    
    mutating func fromBSON(document: Document) {
        username = document["username"]?.stringValue
        name = document["name"]?.stringValue
        surname = document["surname"]?.stringValue
        age = document["age"]?.intValue
    }
    
    func toJSON() -> JSON {
        var json = JSON(["username": "",
            "name": "",
            "surname": "",
            "age": 0])
        json["username"].string = self.username
        json["name"].string = self.name
        json["surname"].string = self.surname
        json["age"].int = self.age
        return json
    }
    
    mutating func fromJSON(document: JSON) {
        username = document["username"].stringValue
        name = document["name"].stringValue
        surname = document["surname"].stringValue
        age = document["age"].intValue
    }
    
}

func setupMongoAPI(router: Kitura.Router) {
    
    // Redis setup
    #if os(OSX)
        let mongoHost = "104.197.204.212"
    #else
        let mongoHost = "10.240.0.8"
    #endif
    let mongoPort: Int = 27017
    do {
        mongo = try MongoKitten.Server(at: mongoHost, port: mongoPort, using: nil, automatically: true)
        
    } catch {
        // Unable to connect
        Log.debug("MongoDB is not available on the given host and port")
    }
    
    // This route accepts GET requests
    router.get("/mongo/:username") { request, response, next in
        Log.debug("GET /mongo/:username")
        response.setHeader("Content-Type", value: "application/json charset=utf-8")
        
        if let username = request.params["username"] {
            Log.debug("username=\(username)")
            do {
                let newResult = try workingCollection.findOne(matching: "username" == username)
                if let mongoResult = newResult {
                    var model = Model()
                    model.fromBSON(mongoResult)
                    try response.status(.OK).sendJson(model.toJSON()).end()
                } else {
                    Log.error("Failed to parse results")
                    response.error = NSError(domain: "Mongo",
                                             code: 1,
                                             userInfo: [NSLocalizedDescriptionKey:"Failed to parse results"])
                    next()
                }
            } catch {
                Log.error("Failed to send response \(error)")
            }
        } else {
            Log.error("Parameters not found")
            response.error = NSError(domain: "Mongo",
                                     code: 1,
                                     userInfo: [NSLocalizedDescriptionKey:"Parameters not found"])
            next()
        }
    }
    /*
     // This route accepts PUT requests
     router.put("/redis/:key") { request, response, next in
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
     */
}