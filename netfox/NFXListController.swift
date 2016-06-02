//
//  NFXListController.swift
//  netfox
//
//  Copyright © 2015 kasketis. All rights reserved.
//

import Foundation
import UIKit
import MessageUI

@available(iOS 8.0, *)
class NFXListController: NFXGenericController, UITableViewDelegate, UITableViewDataSource, UISearchResultsUpdating, UISearchControllerDelegate, MFMailComposeViewControllerDelegate
{
    // MARK: Properties
    
    var tableView: UITableView = UITableView()
    
    var tableData = [NFXHTTPModel]()
    var filteredTableData = [NFXHTTPModel]()
    
    var searchController: UISearchController!
    
    // MARK: View Life Cycle
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        self.navigationItem.title = "网络日志"
        
        self.edgesForExtendedLayout = .None
        self.extendedLayoutIncludesOpaqueBars = false
        self.automaticallyAdjustsScrollViewInsets = false
        
        self.tableView.frame = self.view.frame
        self.tableView.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
        self.tableView.translatesAutoresizingMaskIntoConstraints = true
        self.tableView.delegate = self
        self.tableView.dataSource = self
        self.view.addSubview(self.tableView)
        
        self.tableView.registerClass(NFXListCell.self, forCellReuseIdentifier: NSStringFromClass(NFXListCell))
        self.searchController = UISearchController(searchResultsController: nil)
        
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "开始", style: .Plain, target: self, action: Selector("startButtonPressed:"))
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "发送", style: .Plain, target: self, action: Selector("actionButtonPressed:"))

        NSNotificationCenter.defaultCenter().addObserver(
            self,
            selector: "reloadData",
            name: "NFXReloadData",
            object: nil)
        
        NSNotificationCenter.defaultCenter().addObserver(
            self,
            selector: "deactivateSearchController",
            name: "NFXDeactivateSearch",
            object: nil)
    }
    
    override func viewWillAppear(animated: Bool)
    {
        super.viewWillAppear(animated)
        reloadData()
    }
    
    func settingsButtonPressed()
    {
        var settingsController: NFXSettingsController
        settingsController = NFXSettingsController()
        self.navigationController?.pushViewController(settingsController, animated: true)
    }
    
    // MARK: UISearchResultsUpdating
    
    func updateSearchResultsForSearchController(searchController: UISearchController)
    {
        let predicateURL = NSPredicate(format: "requestURL contains[cd] '\(searchController.searchBar.text!)'")
        let predicateMethod = NSPredicate(format: "requestMethod contains[cd] '\(searchController.searchBar.text!)'")
        let predicateType = NSPredicate(format: "responseType contains[cd] '\(searchController.searchBar.text!)'")

        let predicates = [predicateURL, predicateMethod, predicateType]
        
        let searchPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: predicates)
        
        let array = (NFXHTTPModelManager.sharedInstance.getModels() as NSArray).filteredArrayUsingPredicate(searchPredicate)
        self.filteredTableData = array as! [NFXHTTPModel]
        reloadData()
    }
    
    func deactivateSearchController()
    {
        self.searchController.active = false
    }
    
    // MARK: UITableViewDataSource
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        if (self.searchController.active) {
            return self.filteredTableData.count
        } else {
            return NFXHTTPModelManager.sharedInstance.getModels().count
        }
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell
    {
        let cell = self.tableView.dequeueReusableCellWithIdentifier(NSStringFromClass(NFXListCell), forIndexPath: indexPath) as! NFXListCell
        
        if (self.searchController.active) {
            if self.filteredTableData.count > 0 {
                let obj = self.filteredTableData[indexPath.row]
                cell.configForObject(obj)
            }
        } else {
            if NFXHTTPModelManager.sharedInstance.getModels().count > 0 {
                let obj = NFXHTTPModelManager.sharedInstance.getModels()[indexPath.row]
                cell.configForObject(obj)
            }
        }
        
        return cell
    }
    
    func tableView(tableView: UITableView, viewForFooterInSection section: Int) -> UIView?
    {
        return UIView.init(frame: CGRectZero)
    }
    
    override func reloadData()
    {
        dispatch_async(dispatch_get_main_queue()) { () -> Void in
            self.tableView.reloadData()
            self.tableView.setNeedsDisplay()
        }
    }
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int
    {
        return 1
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath)
    {
        var detailsController : NFXDetailsController
        detailsController = NFXDetailsController()
        var model: NFXHTTPModel
        if (self.searchController.active) {
            model = self.filteredTableData[indexPath.row]
        } else {
            model = NFXHTTPModelManager.sharedInstance.getModels()[indexPath.row]
        }
        detailsController.selectedModel(model)
        self.navigationController?.pushViewController(detailsController, animated: true)
        
    }
    
    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat
    {
        return 58
    }
    
    func actionButtonPressed(sender: UIBarButtonItem)
    {
        if (MFMailComposeViewController.canSendMail()) {
            let mailComposer = MFMailComposeViewController()
            mailComposer.mailComposeDelegate = self
            
            let models = NFXHTTPModelManager.sharedInstance.getModels()
            
            var tempString: String
            tempString = String()
            tempString = "共 \(models.count) 个请求"
            let appName = NFXDebugInfo.getNFXAppName()
            
            mailComposer.setSubject("\(appName)网络日志")
            mailComposer.setMessageBody(tempString, isHTML: false)
            var index : Int32
            index = 0;
            for model in models {
                index += 1;
                //最多10个，附件数量限制(具体数字并不清楚)
                if(index > 10){
                    break;
                }
                //请求信息
                var tempString: String
                tempString = String()
                
                tempString += "** INFO **\n"
                tempString += "\(getInfoStringFromObject(model).string)\n\n"
                
                tempString += "** REQUEST **\n"
                tempString += "\(getRequestStringFromObject(model).string)\n\n"
                
                tempString += "** RESPONSE **\n"
                tempString += "\(getResponseStringFromObject(model).string)\n\n"
                
                if let infoData = tempString.dataUsingEncoding(NSUTF8StringEncoding){
                    mailComposer.addAttachmentData(infoData, mimeType: "text/plain", fileName: "info-\(index)")
                }
                
                //请求体
                let requestFilePath = model.getRequestBodyFilepath()
                if let requestFileData = NSData(contentsOfFile: requestFilePath as String) {
                    mailComposer.addAttachmentData(requestFileData, mimeType: "text/plain", fileName: "requestbody-\(index)")
                }
                //相应体
                let responseFilePath = model.getResponseBodyFilepath()
                if let responseFileData = NSData(contentsOfFile: responseFilePath as String) {
                    mailComposer.addAttachmentData(responseFileData, mimeType: "text/plain", fileName: "responsebody-\(index)")
                }
            }
            self.presentViewController(mailComposer, animated: true, completion: nil)
        }
    }
    
    func getInfoStringFromObject(object: NFXHTTPModel) -> NSAttributedString
    {
        var tempString: String
        tempString = String()
        
        tempString += "[URL] \n\(object.requestURL!)\n\n"
        tempString += "[Method] \n\(object.requestMethod!)\n\n"
        if !(object.noResponse) {
            tempString += "[Status] \n\(object.responseStatus!)\n\n"
        }
        tempString += "[Request date] \n\(object.requestDate!)\n\n"
        if !(object.noResponse) {
            tempString += "[Response date] \n\(object.responseDate!)\n\n"
            tempString += "[Time interval] \n\(object.timeInterval!)\n\n"
        }
        tempString += "[Timeout] \n\(object.requestTimeout!)\n\n"
        tempString += "[Cache policy] \n\(object.requestCachePolicy!)\n\n"
        
        return formatNFXString(tempString)
    }
    
    func getRequestStringFromObject(object: NFXHTTPModel) -> NSAttributedString
    {
        var tempString: String
        tempString = String()
        
        tempString += "-- Headers --\n\n"
        
        if object.requestHeaders?.count > 0 {
            for (key, val) in (object.requestHeaders)! {
                tempString += "[\(key)] \n\(val)\n\n"
            }
        } else {
            tempString += "Request headers are empty\n\n"
        }
        
        
        tempString += "\n-- Body --\n\n"
        
        if (object.requestBodyLength == 0) {
            tempString += "Request body is empty\n"
        } else if (object.requestBodyLength > 1024) {
            tempString += "Too long to show. If you want to see it, please tap the following button\n"
        } else {
            tempString += "\(object.getRequestBody())\n"
        }
        
        return formatNFXString(tempString)
    }
    
    func getResponseStringFromObject(object: NFXHTTPModel) -> NSAttributedString
    {
        if (object.noResponse) {
            return NSMutableAttributedString(string: "No response")
        }
        
        var tempString: String
        tempString = String()
        
        tempString += "-- Headers --\n\n"
        
        if object.responseHeaders?.count > 0 {
            for (key, val) in object.responseHeaders! {
                tempString += "[\(key)] \n\(val)\n\n"
            }
        } else {
            tempString += "Response headers are empty\n\n"
        }
        
        
        tempString += "\n-- Body --\n\n"
        
        if (object.responseBodyLength == 0) {
            tempString += "Response body is empty\n"
        } else if (object.responseBodyLength > 1024) {
            tempString += "Too long to show. If you want to see it, please tap the following button\n"
        } else {
            tempString += "\(object.getResponseBody())\n"
        }
        
        return formatNFXString(tempString)
    }
    
    func mailComposeController(controller: MFMailComposeViewController, didFinishWithResult result: MFMailComposeResult, error: NSError?)
    {
        self.dismissViewControllerAnimated(true, completion: nil)
    }
    
    func startButtonPressed(sender: UIBarButtonItem){
        NFX.sharedInstance().clearOldData()
        reloadData()
    }
}


























































