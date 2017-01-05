import UIKit

class LoadingView: UIView {
    class func create() -> LoadingView {
        let view = Bundle.main.loadNibNamed("LoadingView", owner: nil, options: nil)!.first! as! LoadingView
        let spinnerContainer = view.viewWithTag(1337)!
        spinnerContainer.layer.cornerRadius = 16
        spinnerContainer.clipsToBounds = true
        return view
    }
}
