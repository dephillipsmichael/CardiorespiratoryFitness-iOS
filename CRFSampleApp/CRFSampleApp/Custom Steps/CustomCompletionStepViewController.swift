
import Foundation
import Research
import ResearchUI

open class CustomCompletionStepObject: RSDUIStepObject, RSDStepViewControllerVendor {
    
    private enum CodingKeys: String, CodingKey, CaseIterable {
        case customJsonField
    }
    
    public var customJsonField: String? = nil
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.customJsonField = try container.decode(String.self, forKey: .customJsonField)
        try super.init(from: decoder)
    }
    
    required public init(identifier: String, type: RSDStepType? = nil) {
        super.init(identifier: identifier, type: type)
    }
    
    /// Override to set the properties of the subclass.
    override open func copyInto(_ copy: RSDUIStepObject) {
        super.copyInto(copy)
        guard let subclassCopy = copy as? CustomCompletionStepObject else {
            assertionFailure("Superclass implementation of the `copy(with:)` protocol should return an instance of this class.")
            return
        }
        subclassCopy.customJsonField = self.customJsonField
    }
    
    public func instantiateViewController(with parent: RSDPathComponent?) -> (UIViewController & RSDStepController)? {
        return CustomCompletionStepViewController(step: self, parent: parent)
    }
}

open class CustomCompletionStepViewController: RSDStepViewController {
    
    /// The step for this view controller
    open var customCompletionStep: CustomCompletionStepObject? {
        return self.step as? CustomCompletionStepObject
    }
    
    override open func goForward() {
        
        /// Save custom result?
        /// let countResult = RSDAnswerResultObject(identifier: customCompletionStep.identifier, answerType: .String, value: customCompletionStep.customJsonField)
        /// _ = self.stepViewModel.parent?.taskResult.appendStepHistory(with: countResult)
 
        super.goForward()
    }
}

