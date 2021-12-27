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
    
        let login = loginData.map { res -> EventLoopFuture<RCOverview> in
            let authToken = res?.authentication_token ?? ""
            headers.add(name: "Cookie", value: "rc_auth_token=\(authToken)")
            let res = req.client.get("https://api.revenuecat.com/v1/developers/me/overview?app=", headers: headers)
            let overview = res.flatMapThrowing { response in
                return try response.content.decode(RCOverview.self)
            }

            return overview
        }
        let formatter = NumberFormatter()
        formatter.locale = Locale.current
        formatter.numberStyle = .currency
        formatter.currencySymbol = ""
        
        return login.flatMap { futureLoop in
            futureLoop.map { overview in
                let revenue = formatter.string(from: overview.revenue as NSNumber) ?? "0"
                
                return Frames(frames: [
                    Frame(icon: "42832", text: "\(overview.activeUsersCount)"),
                    Frame(icon: "406", text: "\(overview.installsCount)"),
                    Frame(icon: "30756", text: "\(revenue)"),
                    Frame(icon: "40354", text: "\(overview.activeSubscribersCount)"),
                    Frame(icon: "41036", text: "\(overview.activeTrialsCount)"),
                ])
            }
        }
    }
}
