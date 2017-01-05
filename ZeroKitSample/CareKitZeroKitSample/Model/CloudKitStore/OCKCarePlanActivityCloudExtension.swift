import CareKit

fileprivate let ActivityModificationDateKey = "ActivityModificationDateKey"

extension OCKCarePlanActivity {
    
    /**
     - return: A care plan activity that has the updated modification date.
     */
    func updated(with modificationDate: Date) -> OCKCarePlanActivity {
        var userInfo = self.userInfo ?? [String: NSCoding]()
        
        userInfo[ActivityModificationDateKey] = modificationDate as NSCoding?
        
        return OCKCarePlanActivity(identifier: self.identifier,
                                   groupIdentifier: self.groupIdentifier,
                                   type: self.type,
                                   title: self.title,
                                   text: self.text,
                                   tintColor: self.tintColor,
                                   instructions: self.instructions,
                                   imageURL: self.imageURL,
                                   schedule: self.schedule,
                                   resultResettable: self.resultResettable,
                                   userInfo: userInfo)
    }
    
    var modificationDate: Date? {
        return self.userInfo?[ActivityModificationDateKey] as? Date
    }
}
