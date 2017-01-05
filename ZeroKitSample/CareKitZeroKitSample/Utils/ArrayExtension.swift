import Foundation

extension Array {
    
    typealias AsyncMapPartialResultCompletion<T> = (T?, Error?) -> Void
    typealias AsyncMapTransform<T> = (Element, @escaping AsyncMapPartialResultCompletion<T>) -> Void
    typealias AsyncMapCompletion<T> = ([T]?, Error?) -> Void
    
    /**
     Works similarly to Swift's built in `map` but the transformation does not need to return a result synchronously, it returns a result by calling a completion closure passed to it. The completion is called when all items are transformed or and error occurs.
     
     - parameter transform: Closure performing the transformation. It must call the partial result completion closure passed to it to report its result or an error if it occurred.
     - parameter compeltion: Called when all transformations are completed or an error occurred.
     */
    func asyncMap<T>(transform: @escaping AsyncMapTransform<T>, completion: @escaping AsyncMapCompletion<T>) {
        asyncMap(fromIndex: 0, transformedItems: [T](), transform: transform, completion: completion)
    }
    
    private func asyncMap<T>(fromIndex index: Int, transformedItems: [T], transform: @escaping AsyncMapTransform<T>, completion: @escaping AsyncMapCompletion<T>) {
        guard index < self.count else {
            completion(transformedItems, nil)
            return
        }
        
        let item = self[index]
        
        transform(item) { transformedItem, error in
            
            guard let transformedItem = transformedItem else {
                completion(nil, error)
                return
            }
            
            var newItems = transformedItems
            newItems.append(transformedItem)
            
            self.asyncMap(fromIndex: index + 1, transformedItems: newItems, transform: transform, completion: completion)
        }
    }
}
