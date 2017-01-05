import UIKit
import ZeroKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    private(set) var zeroKit: ZeroKit!
    private(set) var authenticator: Authenticator!
    private(set) var appMock: ExampleAppMock!

    static var current: AppDelegate {
        return UIApplication.shared.delegate as! AppDelegate
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.tintColor = Colors.red.color
        showZeroKitLoadingView()
        window?.makeKeyAndVisible()
        
        setupZeroKit()
        
        return true
    }
    
    fileprivate func setupZeroKit() {
        let zeroKitPlistUrl = Bundle.main.url(forResource: "ExampleAppMock", withExtension: "plist")!
        let zeroKitSettings = NSDictionary(contentsOf: zeroKitPlistUrl)!
        let zeroKitApiUrl = URL(string: zeroKitSettings["ZeroKitAPIURL"] as! String)!
        let config = ZeroKitConfig(apiUrl: zeroKitApiUrl)
        
        zeroKit = try! ZeroKit(config: config)
        appMock = ExampleAppMock()
        authenticator = Authenticator(zeroKit: zeroKit, appMock: appMock)
        
        NotificationCenter.default.addObserver(self, selector: #selector(zeroKitDidLoad(_:)), name: ZeroKit.DidLoadNotification, object: zeroKit!)
        NotificationCenter.default.addObserver(self, selector: #selector(zeroKitDidFailLoading(_:)), name: ZeroKit.DidFailLoadingNotification, object: zeroKit!)
        
        NotificationCenter.default.addObserver(self, selector: #selector(didLogIn(_:)), name: Notification.Name.AuthenticatorDidLogIn, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(didLogOut(_:)), name: Notification.Name.AuthenticatorDidLogOut, object: nil)
    }
    
    @objc fileprivate func zeroKitDidLoad(_ notification: Notification) {
        CloudKitStore.checkAccountStatus { success in
            DispatchQueue.main.async {
                if success {
                    // We create the database schema here.
                    // This can be done in development CloudKit environment but not in production. It works for this sample app, so it is easier to set up.
                    try! CloudKitStore.createDatabaseSchema()
                    self.showWelcomeView()
                    
                } else {
                    self.window!.rootViewController!.showAlert("iCloud error", message: "You are either not logged in to iCloud or an error happened. In order to use CloudKit you must log in to iCloud in Settings.")
                }
            }
        }
    }
    
    @objc fileprivate func zeroKitDidFailLoading(_ notification: Notification) {
        // Handle error, retry...
        self.window?.rootViewController?.showAlert("Failed to load ZeroKit API")
    }
    
    @objc fileprivate func didLogIn(_ notification: Notification) {
        switch authenticator.currentUser!.type {
        case .patient:
            didLogInAsPatient()
        case .doctor:
            didLogInAsDoctor()
        }
    }
    
    fileprivate func didLogInAsPatient() {
        AppDelegate.current.showProgress()
        let currentUser = authenticator.currentUser!
        
        currentUser.createCarePlanTresors { success, error in
            guard success else {
                self.window?.rootViewController?.showAlert("Failed to create care plan tresors", message: "\(error)")
                self.authenticator.logout { success, error in
                }
                return
            }
            AppDelegate.current.hideProgress()
            self.showViewForPatient()
        }
    }
    
    fileprivate func didLogInAsDoctor() {
        showViewForDoctor()
    }
    
    @objc fileprivate func didLogOut(_ notification: Notification) {
        AppDelegate.current.hideProgress()
        self.showWelcomeView()
        self.deleteUserData()
    }
    
    fileprivate func showZeroKitLoadingView() {
        window?.rootViewController = UIStoryboard(name: "LaunchScreen", bundle: nil).instantiateInitialViewController()
    }
    
    fileprivate func showViewForPatient() {
        window?.rootViewController = PatientRootViewController(user: authenticator.currentUser!)
    }
    
    fileprivate func showViewForDoctor() {
        window?.rootViewController = DoctorRootViewController()
    }
    
    fileprivate func showWelcomeView() {
        window?.rootViewController = UIStoryboard(name: "LoginRegistration", bundle: nil).instantiateInitialViewController()
    }
    
    fileprivate func deleteUserData() {
        _ = CarePlanStoreManager.deleteLocalStore()
    }
    
    // MARK: Progress view
    
    fileprivate var progressView: UIView?
    
    func showProgress() {
        if progressView != nil {
            return
        }
        
        let view = LoadingView.create()
        view.frame = self.window!.bounds
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.translatesAutoresizingMaskIntoConstraints = true
        
        self.window?.addSubview(view)
        self.progressView = view
    }
    
    func hideProgress() {
        progressView?.removeFromSuperview()
        progressView = nil
    }
}

