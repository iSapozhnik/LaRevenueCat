import Vapor
import Foundation

struct Frames: Content {
    var frames: [Frame]
}

extension Frames {
    static let `default` = Frames(frames: [
        Frame(icon: "42832", text: "Not authorized")
    ])
}

struct Frame: Content {
    var icon: String
    var text: String
}

struct ChuckFact: Content {
    var value : String
}

struct RCOverview: Content {
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

let formatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.locale = Locale.current
    formatter.numberStyle = .currency
    formatter.currencySymbol = ""
    return formatter
}()

func routes(_ app: Application) throws {
    app.get { req -> EventLoopFuture<Frames> in
        let auth = req.headers.basicAuthorization
        guard let auth = auth, !auth.username.isEmpty, !auth.password.isEmpty else {
            return req.eventLoop.makeSucceededFuture(Frames.default)
        }

        var headers = HTTPHeaders()
        headers.add(name: "x-requested-with", value: "XMLHttpRequest")
        let loginRequest = LoginRequest(email: auth.username, password: auth.password)

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
    
    app.get("chuck") { req -> EventLoopFuture<Frames> in
        req
            .client
            .get("https://api.chucknorris.io/jokes/random")
            .flatMapThrowing { response in
                try response.content.decode(ChuckFact.self)
            }
            .map { fact in
                Frames(frames: [Frame(icon: "i32945", text: fact.value)])
            }
    }
}
