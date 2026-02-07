import Foundation
import WatchConnectivity
import Combine

/// Manages communication between iPhone and Apple Watch
class WatchConnectivityService: NSObject, ObservableObject {
    static let shared = WatchConnectivityService()
    
    @Published var isPaired = false
    @Published var isWatchAppInstalled = false
    @Published var isReachable = false
    @Published var lastSyncDate: Date?
    
    private var session: WCSession?
    
    override init() {
        super.init()
        
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
    }
    
    // MARK: - Public Methods
    
    /// Send auth credentials to Watch
    func sendAuthToWatch(userId: String, email: String) {
        guard let session = session, session.isPaired, session.isWatchAppInstalled else {
            print("⌚️ Watch not available for auth sync")
            return
        }
        
        let message: [String: Any] = [
            "type": "auth",
            "userId": userId,
            "email": email,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        if session.isReachable {
            session.sendMessage(message, replyHandler: { reply in
                print("⌚️ Auth sent to Watch, reply: \(reply)")
            }, errorHandler: { error in
                print("⌚️ Error sending auth: \(error)")
            })
        } else {
            // Use application context for background transfer
            do {
                try session.updateApplicationContext(message)
                print("⌚️ Auth sent via application context")
            } catch {
                print("⌚️ Error updating context: \(error)")
            }
        }
    }
    
    /// Send active workout session to Watch
    func sendWorkoutToWatch(_ session: PersistableSession) {
        guard let wcSession = self.session, wcSession.isPaired, wcSession.isWatchAppInstalled else {
            print("⌚️ Watch not available for workout sync")
            return
        }
        
        guard let data = try? JSONEncoder().encode(session) else { return }
        
        let message: [String: Any] = [
            "type": "workout",
            "data": data,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        if wcSession.isReachable {
            wcSession.sendMessage(message, replyHandler: nil, errorHandler: { error in
                print("⌚️ Error sending workout: \(error)")
            })
        } else {
            do {
                try wcSession.updateApplicationContext(message)
            } catch {
                print("⌚️ Error updating context: \(error)")
            }
        }
    }
    
    /// Request sync from Watch
    func requestSyncFromWatch() {
        guard let session = session, session.isReachable else { return }
        
        session.sendMessage(["type": "requestSync"], replyHandler: { reply in
            print("⌚️ Sync response: \(reply)")
        }, errorHandler: { error in
            print("⌚️ Sync request error: \(error)")
        })
    }
    
    /// Open Watch app
    func openWatchApp() {
        guard let session = session, session.isPaired, session.isWatchAppInstalled else { return }
        
        // Send a message that will wake up the Watch app
        if session.isReachable {
            session.sendMessage(["type": "wake"], replyHandler: nil, errorHandler: nil)
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityService: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isPaired = session.isPaired
            self.isWatchAppInstalled = session.isWatchAppInstalled
            self.isReachable = session.isReachable
            
            print("⌚️ WCSession activated: paired=\(session.isPaired), installed=\(session.isWatchAppInstalled), reachable=\(session.isReachable)")
        }
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
        print("⌚️ Session became inactive")
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        print("⌚️ Session deactivated")
        // Reactivate for switching watches
        session.activate()
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
            print("⌚️ Reachability changed: \(session.isReachable)")
        }
    }
    
    func sessionWatchStateDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isPaired = session.isPaired
            self.isWatchAppInstalled = session.isWatchAppInstalled
            print("⌚️ Watch state changed: paired=\(session.isPaired), installed=\(session.isWatchAppInstalled)")
        }
    }
    
    // Receive messages from Watch
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        print("⌚️ Received message from Watch: \(message)")
        handleWatchMessage(message)
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        print("⌚️ Received message from Watch (with reply): \(message)")
        handleWatchMessage(message)
        replyHandler(["status": "received"])
    }
    
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        print("⌚️ Received application context: \(applicationContext)")
        handleWatchMessage(applicationContext)
    }
    
    private func handleWatchMessage(_ message: [String: Any]) {
        guard let type = message["type"] as? String else { return }
        
        DispatchQueue.main.async {
            switch type {
            case "workoutCompleted":
                // Watch completed a workout - sync to server
                if let data = message["data"] as? Data {
                    self.handleWorkoutFromWatch(data)
                }
                self.lastSyncDate = Date()
                
            case "requestAuth":
                // Watch is asking for auth credentials
                if let userId = AuthService.shared.userId,
                   let email = AuthService.shared.userEmail {
                    self.sendAuthToWatch(userId: userId, email: email)
                }
                
            default:
                print("⌚️ Unknown message type: \(type)")
            }
        }
    }
    
    private func handleWorkoutFromWatch(_ data: Data) {
        // Decode and save workout from Watch
        // TODO: Implement workout sync from Watch
        print("⌚️ Received workout data from Watch")
    }
}
