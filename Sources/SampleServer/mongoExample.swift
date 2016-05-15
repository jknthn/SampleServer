import Foundation
import Kitura
import HeliumLogger
import LoggerAPI

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
    var age: Int32? = 0
    
    func toBSON() -> Document {
        return [
                   "username": (self.username ?? "").makeBsonValue(),
                   "name": (self.name ?? "").makeBsonValue(),
                   "surname": (self.surname ?? "").makeBsonValue(),
                   "age": (self.age ?? 0).makeBsonValue()
        ]
    }
    
    mutating func fromBSON(document: Document) {
        username = document["username"].stringValue
        name = document["name"].stringValue
        surname = document["surname"].stringValue
        age = document["age"].int32Value
    }
    
    func toJSON() -> JSON {
        var json = JSON(["username": "",
            "name": "",
            "surname": "",
            "age": 0])
        json["username"].string = self.username
        json["name"].string = self.name
        json["surname"].string = self.surname
        if let age = self.age {
            json["age"].int = Int(age)
        }
        return json
    }
    
    mutating func fromJSON(document: JSON) {
        username = document["username"].stringValue
        name = document["name"].stringValue
        surname = document["surname"].stringValue
        age = Int32(document["age"].intValue)
    }
    
}

func setupMongoAPI(router: Kitura.Router) {
    
    // MongoDB setup
    #if os(OSX)
        // This will not work
        // MongoDB external IP is currently disabled
        let mongoHost = "104.197.204.212"
    #else
        let mongoHost = "10.132.0.7"
    #endif
    let mongoPort: UInt16 = 27017
    do {
        mongo = try MongoKitten.Server(at: mongoHost, port: mongoPort)
        
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
                    model.fromBSON(document: mongoResult)
                    try response.status(.OK).send(json: model.toJSON()).end()
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
}