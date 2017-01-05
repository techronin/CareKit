import UIKit

/**
 The root view controller when a doctor logs in. It contains the patients and account view controller.
 */
class DoctorRootViewController: UITabBarController {

    private var patientsViewController: MyPatientsViewController!
    private var accountViewController: AccountViewController!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        patientsViewController = createPatientsViewController()
        accountViewController = createAccountViewController()
        
        self.viewControllers = [
            UINavigationController(rootViewController: patientsViewController),
            UINavigationController(rootViewController: accountViewController)
        ]
    }
    
    private func createPatientsViewController() -> MyPatientsViewController {
        let viewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "MyPatientsViewController")
        viewController.tabBarItem = UITabBarItem(title: viewController.title, image: UIImage(named:"patients"), selectedImage: UIImage(named: "patients-selected"))
        return viewController as! MyPatientsViewController
    }
    
    private func createAccountViewController() -> AccountViewController {
        let viewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "AccountViewController")
        viewController.tabBarItem = UITabBarItem(title: viewController.title, image: UIImage(named:"account"), selectedImage: UIImage(named: "account-selected"))
        return viewController as! AccountViewController
    }
}
