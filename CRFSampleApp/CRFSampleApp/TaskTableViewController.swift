//
//  TaskTableViewController.swift
//  RSDCatalog
//
//  Copyright © 2018 Sage Bionetworks. All rights reserved.
//
// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:
//
// 1.  Redistributions of source code must retain the above copyright notice, this
// list of conditions and the following disclaimer.
//
// 2.  Redistributions in binary form must reproduce the above copyright notice,
// this list of conditions and the following disclaimer in the documentation and/or
// other materials provided with the distribution.
//
// 3.  Neither the name of the copyright holder(s) nor the names of any contributors
// may be used to endorse or promote products derived from this software without
// specific prior written permission. No license is granted to the trademarks of
// the copyright holders even if such marks are included in this software.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE
// FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
// DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
// SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
// OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//

import UIKit
import Research
import CardiorespiratoryFitness

class TaskTableViewController: UITableViewController, RSDTaskViewControllerDelegate {
    
    public var taskList: [RSDTaskInfo] = CRFTaskIdentifier.allCases.map { CRFTaskInfo($0) }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Use automatic hieght dimension
        tableView.rowHeight = UITableView.automaticDimension
        
        addCustomTask()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        flushTempDirectory()
    }
    
    /// Flush the temporary directory contents.
    /// For the example app, we want to leave the output directory untouched *until*
    /// this view controller appears. For a *real* application, the output directory
    /// that is used to store temporary results should be flushed as soon as the task
    /// is completed and the results are encrypted. This is because the results of the
    /// task could include private health data so it is important to handle these results
    /// using a secure method.
    func flushTempDirectory() {
        do {
            let fileManager = FileManager.default
            let tempDir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            let directories = try fileManager.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil, options: [])
            for outputDirectory in directories {
                try FileManager.default.removeItem(at: outputDirectory)
            }
        } catch let error {
            print("Error removing output directory: \(error.localizedDescription)")
        }
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return taskList.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "BasicCell", for: indexPath) as! ImageTableViewCell
        let taskInfo = taskList[indexPath.row]
        cell.titleLabel?.text = taskInfo.title
        cell.subtitleLabel?.text = taskInfo.subtitle
        
        guard let imageView = cell.thumbnailView else {
            return cell
        }
        
        if let crfTaskInfo = taskInfo as? CRFTaskInfo,
           let icon = crfTaskInfo.icon {
            imageView.image = icon.embeddedImage()
        } else {
            taskInfo.imageVendor?.fetchImage(for: CGSize(width: 100, height: 100), callback: { (id, image) in
                imageView.image = image
            })
        }
    
        return cell
    }
 
    // MARK: - Navigation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let cell = sender as? UITableViewCell,
            let indexPath = self.tableView.indexPath(for: cell),
            let vc = segue.destination as? TaskPresentationViewController,
            let taskInfo = taskList[indexPath.row] as? CRFTaskInfo
            else {
                return
        }
        vc.taskInfo = taskInfo
        vc.title = taskInfo.title ?? taskInfo.identifier
        vc.navigationItem.title = vc.title
    }
    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        guard let cell = sender as? UITableViewCell,
            let indexPath = self.tableView.indexPath(for: cell)
            else {
                return false
        }
        let taskInfo = taskList[indexPath.row]
        if (taskInfo is CRFTaskInfo) {
            return true
        }
        runCustomTask(taskInfo: taskInfo)
        return false
    }
    
    func addCustomTask() {
        var cardio12MTTaskInfo = RSDTaskInfoObject(with: "Cardio_12MT")
        cardio12MTTaskInfo.title = "Cardio 12 Minutes"
        cardio12MTTaskInfo.subtitle = "Take your heart rate, run for 12 minutes, then take your heart rate again to measure V02 Max."
        let crfBundle = Bundle(for: CRFTaskObject.self)
        do {
            cardio12MTTaskInfo.icon = try RSDImageWrapper(imageName: "heartRateIcon", bundle: crfBundle)
        } catch {
            debugPrint("Invalid image heartRateIcon in \(String(describing: crfBundle.bundleIdentifier))")
        }
        taskList.append(cardio12MTTaskInfo)
    }
    
    func runCustomTask(taskInfo: RSDTaskInfo) {
        self.showJsonTaskViewControler(jsonName: taskInfo.identifier)
    }
    
    func showJsonTaskViewControler(jsonName: String) {
        do {
            let resourceTransformer = RSDResourceTransformerObject(resourceName: jsonName)
            let factory = CustomCrfFactory()
            let task = try factory.decodeTask(with: resourceTransformer)
            let taskViewModel = RSDTaskViewModel(task: task)
            let vc = RSDTaskViewController(taskViewModel: taskViewModel)
            vc.delegate = self
            self.present(vc, animated: true, completion: nil)
        } catch let err {
            fatalError("Failed to decode the task. \(err)")
        }
    }
    
    func taskController(_ taskController: RSDTaskController, didFinishWith reason: RSDTaskFinishReason, error: Error?) {
        self.dismiss(animated: true, completion: nil)
    }
    
    func taskController(_ taskController: RSDTaskController, readyToSave taskViewModel: RSDTaskViewModel) {
        // Here is where you will save the results to MyStudies
        print("\(taskViewModel.taskResult.identifier) recorded with \(taskViewModel.taskResult.stepHistory.count) simple results and \(String(describing: taskViewModel.taskResult.asyncResults?.count)) JSON results")
    }
}

open class CustomCrfFactory: CRFFactory {
    
    override open func decodeTask(with resourceTransformer: RSDResourceTransformer, taskIdentifier: String? = nil, schemaInfo: RSDSchemaInfo? = nil) throws -> RSDTask {
        
        let crfBundle = Bundle(for: CRFTaskObject.self)
        let (data, type) = try resourceTransformer.resourceData()
        
        return try decodeTask(with: data,
                              resourceType: type,
                              typeName: resourceTransformer.classType,
                              taskIdentifier: taskIdentifier,
                              schemaInfo: schemaInfo,
                              bundle: crfBundle)
    }
    
    
    override open func decodeStep(from decoder: Decoder, with type: RSDStepType) throws -> RSDStep? {
        
        // Add custom step here, your conclusion step
        if (type == "customCompletion") {
            return try CustomCompletionStepObject(from: decoder)
        }
                
        return try super.decodeStep(from: decoder, with: type)
    }
}

class ImageTableViewCell : UITableViewCell {
    
    @IBOutlet weak var thumbnailView: UIImageView?
    @IBOutlet weak var titleLabel: UILabel?
    @IBOutlet weak var subtitleLabel: UILabel?
    
}
