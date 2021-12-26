import Vapor

struct Frames: Codable, Content {
    var frames: [Frame]
}

struct Frame: Codable, Content {
    var icon: String
    var text: String
}

struct RCOverview: Codable, Content {
    let activeSubscribersCount: Int
    let activeTrialsCount: Int
    let activeUsersCount: Int
    let installsCount: Int
    let mrr: Double
    let revenue: Double
    
    enum CodingKeys: String, CodingKey {
        case activeSubscribersCount = "active_subscribers_count"
        case activeTrialsCount = "active_trials_count"
        case activeUsersCount = "active_users_count"
        case installsCount = "installs_count"
        case mrr
        case revenue
    }
}

final class User: Authenticatable {
    let email: String?
    let password: String?
    
    init(email: String, password: String) {
      self.email = email
      self.password = password
    }
}

struct LoginRequest: Content {
    var email: String
    var password: String
}

struct LoginResponse: Content, Codable {
    let authentication_token: String
}

func routes(_ app: Application) throws {
    app.get { req -> EventLoopFuture<Frames> in
        let auth = req.headers.basicAuthorization
        var headers = HTTPHeaders()
        headers.add(name: "x-requested-with", value: "XMLHttpRequest")
        let loginRequest = LoginRequest(email: auth?.username ?? "", password: auth?.password ?? "")

        let loginResponse = req.client.post ("https://api.revenuecat.com/v1/developers/login", headers: headers, beforeSend: { loginReq in
            try loginReq.content.encode(loginRequest)
        })
        
        let loginData: EventLoopFuture<LoginResponse?> = loginResponse.map { response in
            return try? response.content.decode(LoginResponse.self)
        }
    
        
        let aaa = loginData.map { res -> EventLoopFuture<RCOverview> in
            let authToken = res?.authentication_token ?? ""
            headers.add(name: "Cookie", value: "rc_auth_token=\(authToken)")
            let res = req.client.get("https://api.revenuecat.com/v1/developers/me/overview?app=", headers: headers)
            let bbb = res.flatMapThrowing { response in
                return try response.content.decode(RCOverview.self)
            }

            return bbb
        }
        let formatter = NumberFormatter()
        formatter.locale = Locale.current
        formatter.numberStyle = .currency
        formatter.currencySymbol = ""
        
        return aaa.flatMap { futureLoop in
            futureLoop.map { overview in
                let revenue = formatter.string(from: overview.revenue as NSNumber) ?? "0"
                
                return Frames(frames: [
                    Frame(icon: "42832", text: "\(overview.activeUsersCount)"),
                    Frame(icon: "406", text: "\(overview.installsCount)"),
                    Frame(icon: "30756", text: "\(revenue)"),
//                    Frame(icon: "401", text: "\(overview.activeSubscribersCount)"),
//                    Frame(icon: "401", text: "\(overview.activeTrialsCount)"),
                ])
            }
        }
    }
    
    /**
     
     {
         "active_subscribers_count": 4,
         "active_trials_count": 2,
         "active_users_count": 353,
         "installs_count": 243,
         "mrr": 3.5521728951546,
         "revenue": 158.409177242769
     }
     
     
     */

    app.get("hello") { req -> String in
        return "Hello, world!"
    }
}
