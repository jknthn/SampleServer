//
//  slacket.swift
//  SampleServer
//
//  Created by Jakub Tomanik on 17/05/16.
//
//

import Foundation
import Kitura
import HeliumLogger
import LoggerAPI

import SimpleHttpClient

#if os(Linux)
    import Glibc
#endif

protocol AppType {
    
    var router: Kitura.Router { get }
    init(using router: Kitura.Router)
    mutating func setupRoutes()
}

struct Slacket: AppType {
    
    private let pocketConsumerKey = "54643-3989062fcc074d7073bfcc5f"
    private var pocketRequestToken: String? {
        didSet {
            Log.debug("pocketRequestToken = \(pocketRequestToken)")
        }
    }
    private var pocketAccessToken: String? {
        didSet {
            Log.debug("pocketAccessToken = \(pocketAccessToken)")
        }
    }
    private var pocketUsername: String? {
        didSet {
            Log.debug("pocketUsername = \(pocketUsername)")
        }
    }
    
    private var slackUserIds: [String] = []
    private var pocketAccessTokens: [String: String] = [:]
    private var pocketRequestTokens: [String: String] = [:]
    private var pocketUsernames: [String: String] = [:]
    
    let router: Router
    
    init(using router: Kitura.Router) {
        self.router = router
        self.setupRoutes()
    }
    
    mutating func setupRoutes() {
        
        // setup inbound slack URL
        router.get("api/v1/slack/command") { request, response, next in
            Log.debug("GET api/v1/slack/command")
            
            let params = ParamsParser.parse(parameters: request.queryParams)
            if let command = SlackParser.parse(parameters: params) {
                Log.debug("Request from slack user = \(command.userId)")
                Log.debug("To send link = \(command.text)")
                
                if let pocketAccessToken = self.pocketAccessTokens[command.userId] {
                    
                    let addLink = SimpleHttpClient.HttpResourse(schema: "https", host: "getpocket.com/v3/add", port: "80")
                    let headers = ["Content-Type": "application/json; charset=UTF8",
                                   "X-Accept": "application/json; charset=UTF8"];
                    #if os(Linux)
                        let url = command.text.stringByTrimmingCharactersInSet(NSCharacterSet(charactersInString: " "))
                        let decodedUrl = url.stringByRemovingPercentEncoding
                    #else
                        let url = command.text.trimmingCharacters(in: NSCharacterSet(charactersIn: " "))
                        let decodedUrl = url.removingPercentEncoding
                    #endif
                    
                    if let encodedUrl = decodedUrl {
                        
                        let tags = "\(command.teamDomain),\(command.channelName)"
                        let jsonString = "{\"url\":\"\(encodedUrl)\",\"tags\":\"\(tags)\",\"consumer_key\":\"\(self.pocketConsumerKey)\",\"access_token\":\"\(pocketAccessToken)\"}"
                        Log.info(jsonString)
                        
                        #if os(Linux)
                            let data = jsonString.dataUsingEncoding(NSUTF8StringEncoding)
                        #else
                            let data = jsonString.data(using: NSUTF8StringEncoding)
                        #endif
                        
                        if let data = data {
                            
                            response.setHeader("Content-Type", value: "text/plain; charset=utf-8")
                            
                            HttpClient.post(resource: addLink, headers: headers, data: data) { error, status, headers, data in
                                
                                if let _ = error{
                                    
                                    Log.error("Pocket API returned error")
                                    response.error = NSError(domain: "Slacket",
                                                             code: status ?? 0,
                                                             userInfo: [NSLocalizedDescriptionKey: "Parameters not found"])
                                    next()
                                } else {
                                    response.send("success")
                                    next()
                                }
                            }
                        } else {
                            Log.error("Encoding JSON has failed")
                            response.error = NSError(domain: "Slacket",
                                                     code: 1,
                                                     userInfo: [NSLocalizedDescriptionKey: "Encoding JSON has failed"])
                            next()
                        }
                    } else {
                        Log.error("Encoding URL has failed")
                        response.error = NSError(domain: "Slacket",
                                                 code: 1,
                                                 userInfo: [NSLocalizedDescriptionKey: "Encoding JSON has failed"])
                        next()
                    }

                } else {
                    Log.error("Access token not found")
                    response.send("Please go to http://slacket.link/api/v1/pocket/auth/\(command.userId)")
                    next()
                }
            } else {
                Log.error("Parameters not found")
                response.error = NSError(domain: "Slacket",
                                         code: 1,
                                         userInfo: [NSLocalizedDescriptionKey: "Parameters not found"])
                next()
            }
        }
        
        router.get("api/v1/pocket/auth/:slack_id") { request, response, next in
            Log.debug("api/v1/pocket/auth/:slack_id")
            
            if let slackId = request.params["slack_id"] {
                Log.debug("Begin authorization for slackId =  \(slackId)")
                
                let redirectURL = "http://slacket.link/api/v1/pocket/authorized/\(slackId)"
                
                let authStep1 = SimpleHttpClient.HttpResourse(schema: "https", host: "getpocket.com/v3/oauth/request", port: "80")
                let headers = ["Content-Type": "application/x-www-form-urlencoded; charset=UTF8",
                               "X-Accept": "(x-www-form-urlencoded"];
                let postString = "consumer_key=\(self.pocketConsumerKey)&redirect_uri=\(redirectURL)"
                
                #if os(Linux)
                    let data = postString.dataUsingEncoding(NSUTF8StringEncoding)
                #else
                    let data = postString.data(using: NSUTF8StringEncoding)
                #endif
                
                if let data = data {
                    
                    HttpClient.post(resource: authStep1, headers: headers, data: data) { error, status, headers, data in
                        Log.debug("Received response from Pocket API")
                        
                        if let _ = error{
                            Log.error("Pocket API returned error")
                            response.error = NSError(domain: "Slacket",
                                                     code: status ?? 0,
                                                     userInfo: [NSLocalizedDescriptionKey: "Parameters not found"])
                            next()
                        } else {
                            
                            if let data = data,
                                let code = String(data: data, encoding: NSUTF8StringEncoding) {
                                
                                #if os(Linux)
                                    let requestToken = code.stringByReplacingOccurrencesOfString("code=", withString: "")
                                #else
                                    let requestToken = code.replacingOccurrences(of: "code=", with: "")
                                #endif
                                
                                self.pocketRequestTokens[slackId] = requestToken
                                let redirecTo = "https://getpocket.com/auth/authorize?request_token=\(requestToken)&redirect_uri=\(redirectURL)"
                                Log.debug("Pocket request token =  \(requestToken)")
                                
                                do {
                                    Log.debug("Redirecting")
                                    try response.redirect(redirecTo)
                                }
                                catch {}
                                return
                            }
                        }
                    }
                }
            } else {
                Log.error("Parameters not found")
                response.error = NSError(domain: "Slacket",
                                         code: 1,
                                         userInfo: [NSLocalizedDescriptionKey: "Parameters not found"])
                next()
            }
        }
        
        router.get("api/v1/pocket/authorized/:slack_id") { request, response, next in
            Log.debug("api/v1/pocket/auth/:slack_id")
            
            if let slackId = request.params["slack_id"],
            let pocketRequestToken = self.pocketRequestTokens[slackId] {
                Log.debug("finishing authorization for slackId =  \(slackId)")
                
                let authStep2 = SimpleHttpClient.HttpResourse(schema: "https", host: "getpocket.com/v3/oauth/authorize", port: "80")
                let headers = ["Content-Type": "application/x-www-form-urlencoded; charset=UTF8",
                               "X-Accept": "(x-www-form-urlencoded"];
                let postString = "consumer_key=\(self.pocketConsumerKey)&code=\(pocketRequestToken)"
                
                #if os(Linux)
                    let data = postString.dataUsingEncoding(NSUTF8StringEncoding)
                #else
                    let data = postString.data(using: NSUTF8StringEncoding)
                #endif
                
                if let data = data {
                    
                    HttpClient.post(resource: authStep2, headers: headers, data: data) { error, status, headers, data in
                        
                        if let _ = error{
                            
                            Log.error("Pocket API returned error")
                            response.error = NSError(domain: "Slacket",
                                                     code: status ?? 0,
                                                     userInfo: [NSLocalizedDescriptionKey: "Parameters not found"])
                            next()
                        } else {
                            
                            if let data = data,
                                let answer = String(data: data, encoding: NSUTF8StringEncoding) {
                                
                                Log.info(answer)
                                
                                #if os(Linux)
                                    let splitted = answer.componentsSeparatedByString("&").map { $0.componentsSeparatedByString("=") }
                                #else
                                    let splitted = answer.components(separatedBy: "&").map { $0.components(separatedBy: "=") }
                                #endif
                                
                                splitted.forEach { $0.forEach{ Log.info($0) } }
                                
                                if splitted.count == 2 {
                                    self.pocketAccessTokens[slackId] = splitted[0][1]
                                    self.pocketUsernames[slackId] = splitted[1][1]
                                }
                                
                                
                                let errorString = "error"
                                let responseString = "access token = \(self.pocketAccessTokens[slackId] ?? errorString)\nusername = \(self.pocketUsernames[slackId] ?? errorString)"
                                
                                response.setHeader("Content-Type", value: "text/plain; charset=utf-8")
                                response.send(responseString)
                                next()
                            }
                        }
                    }
                }
            } else {
                Log.error("Parameters not found")
                response.error = NSError(domain: "Slacket",
                                         code: 1,
                                         userInfo: [NSLocalizedDescriptionKey: "Parameters not found"])
                next()
            }
        }
        
        router.get("api/v1/*") { request, response, next in
            do {
                try response.end()
            }
            catch {
                Log.error("Failed to send response \(error)")
            }
        }
    }
}

protocol Debugable {
    
    var description: String { get }
}

protocol SlackCommandType: Debugable {
    
    var token: String { get }
    var teamId: String { get }
    var teamDomain: String { get }
    var channelId: String { get }
    var channelName: String { get }
    var userId: String { get }
    var userName: String { get }
    var command: String { get }
    var text: String { get }
    var responseUrl: String { get }
}

struct SlackCommand: SlackCommandType {
    
    let token: String
    let teamId: String
    let teamDomain: String
    let channelId: String
    let channelName: String
    let userId: String
    let userName: String
    let command: String
    let text: String
    let responseUrl: String
    
    var description: String {
        var description = ""
        description += "token = \(token)/n"
        description += "teamId = \(teamId)"
        description += "teamDomain = \(teamDomain)/n"
        description += "channelId = \(channelId)/n"
        description += "channelName = \(channelName)/n"
        description += "userId = \(userId)/n"
        description += "userName = \(userName)/n"
        description += "command = \(command)/n"
        description += "text = \(text)/n"
        description += "responseUrl = \(responseUrl)/n"
        return description
    }
}

protocol ParamsService {
    
    static func parse(parameters: [String: String]) -> [String: String]
}

struct ParamsParser: ParamsService {
    
    static func parse(parameters: [String: String]) -> [String : String] {
        
        var dict: [String: String] = [:]
        for (key, value) in parameters {
            dict[key] = value
        }
        return dict
    }
}

protocol SlackService {
    
    //static func parse(parameters: [[String]]) -> SlackCommandType?
    static func parse(parameters: [String: String]) -> SlackCommandType?
}

struct SlackParser: SlackService {
    
    //static func parse(parameters: [[String]]) -> SlackCommandType? {
    //    return parse(parameters: ParamsParser.parse(parameters: parameters))
    //}
    
    static func parse(parameters: [String : String]) -> SlackCommandType? {
        if let token = parameters["token"],
            let teamId = parameters["team_id"],
            let teamDomain = parameters["team_domain"],
            let channelId = parameters["channel_id"],
            let channelName = parameters["channel_name"],
            let userId = parameters["user_id"],
            let userName = parameters["user_name"],
            let command = parameters["command"],
            //let responseUrl = parameters["response_url"]
            let text = parameters["text"] {
            return SlackCommand(token: token,
                                teamId: teamId,
                                teamDomain: teamDomain,
                                channelId: channelId,
                                channelName: channelName,
                                userId: userId,
                                userName: userName,
                                command: command,
                                text: text,
                                responseUrl: "")
        } else {
            return nil
        }
    }
}