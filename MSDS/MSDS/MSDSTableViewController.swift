//
//  MSDSTableViewController.swift
//  MSDS
//
//  Created by Dylan Buer on 12/25/18.
//  Copyright © 2018 Dylan Buer. All rights reserved.
//

import UIKit
import SQLite

class MSDSTableViewController: UITableViewController, UITextFieldDelegate {

    var database: Connection!
    private var files = [Array<String>]() {
        didSet {
            print(files)
        }
    }
    let msds = Table("msds")
    let fileName = Expression<String?>("name")
    let fileView = Expression<String?>("view")
    let fileDownload = Expression<String?>("download")
    let fileOffline = Expression<Int?>("offline")
    
    var searchText: String? {
        didSet {
            searchTextField?.text = searchText
            searchTextField?.resignFirstResponder()
            files.removeAll()
            tableView.reloadData()
            searchForFiles()
            title = searchText
        }
    }
    
    private func searchForFiles() {
        if let text = searchText, !text.isEmpty {
            let arbText = text.replacingOccurrences(of: " ", with: "%")
            let query = self.msds.filter(fileName.like("%\(arbText)%"))
            displayQuery(query)
        } else {
            displayQuery(msds)
        }
    }
    
    /** Finds and loads database. */
    override func viewDidLoad() {
        super.viewDidLoad()
        do {
            let fileManager = FileManager.default
            let documentsUrl = fileManager.urls(for: .documentDirectory,
                                                in: .userDomainMask)
            let finalDatabaseURL = documentsUrl.first!.appendingPathComponent("msds.db")
            
            if !( (try? finalDatabaseURL.checkResourceIsReachable()) ?? false) {
                print("copying")
                let documentsURL = Bundle.main.resourceURL?.appendingPathComponent("msds.db")
                
                do {
                    try fileManager.copyItem(atPath: (documentsURL?.path)!, toPath: finalDatabaseURL.path)
                } catch {
                    print("Couldn't copy file to final location!")
                }
            }
            
            self.database = try Connection(finalDatabaseURL.path);
            displayQuery(msds)
        } catch {
            print(error)
        }
    }
    
    func displayQuery(_ query: Table) {
        do {
            let seq = try self.database.prepare(query)
            let m = seq.map{ $0[fileName]! }
            DispatchQueue.main.async {
                self.files.insert(m, at: 0)
                self.tableView.insertSections([0], with: .fade)
            }
        } catch {
            print(error)
        }
    }
    
    @IBOutlet weak var searchTextField: UITextField! {
        didSet {
            searchTextField.delegate = self;
        }
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == searchTextField {
            searchText = searchTextField.text
        }
        return true
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return files[section].count
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return files.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "File", for: indexPath)
        //Configure cell
        let file = files[indexPath.section][indexPath.row]
        var offline = false
        let query = msds.filter(fileName == file)
        
        do {
            if let row = try self.database.pluck(query) {
                offline = row[fileOffline]! == 1
            }
        } catch {
            print(error)
        }
        
        if let fileCell = cell as? FileTableViewCell {
            fileCell.downloadSwitch?.tag = indexPath.row
            fileCell.pesticideLabel?.tag = -1
            fileCell.file = file
            fileCell.offline = offline
            fileCell.downloadSwitch.addTarget(self, action: #selector(switchChanged(sender:)), for: UIControlEvents.valueChanged)
        }
        return cell
    }
    
    @objc func switchChanged(sender: UISwitch) {
        print("switched")
        let value = sender.isOn ? 1 : 0
        let row = sender.tag
        let indexpath = IndexPath(row : row, section: 0)
        let cell = tableView.cellForRow(at: indexpath)
        let label = cell!.contentView.viewWithTag(-1) as? UILabel
        let name = label!.text!
        let query = msds.filter(fileName == name)
        do {
            try database.run(query.update(fileOffline <- value))
        } catch {
            print(error)
        }
        print("here")
        
        if (value == 1) {
            var name = "default"
            var urlstring = "https://www.apple.com"
            do {
                if let row = try self.database.pluck(query) {
                    name = row[fileName]!.trimmingCharacters(in: .whitespaces)
                    urlstring = row[fileDownload]!
                }
            } catch {
                print(error)
            }
            
            let documentsUrl:URL =  FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let destinationFileUrl = documentsUrl.appendingPathComponent(name).appendingPathExtension("pdf")
            let fileURL = URL(string: urlstring)
            
            let sessionConfig = URLSessionConfiguration.default
            let session = URLSession(configuration: sessionConfig)
            
            let request = URLRequest(url:fileURL!)
            
            let task = session.downloadTask(with: request) { (tempLocalUrl, response, error) in
                if let tempLocalUrl = tempLocalUrl, error == nil {
                    if let statusCode = (response as? HTTPURLResponse)?.statusCode {
                        print("Successfully downloaded. Status code: \(statusCode)")
                    }
                    
                    do {
                        try FileManager.default.copyItem(at: tempLocalUrl, to: destinationFileUrl)
                        try self.database.run(query.update(self.fileDownload <- name + ".pdf"))
                        print(destinationFileUrl.absoluteString)
                    } catch (let writeError) {
                        print("Error creating a file \(destinationFileUrl) : \(writeError)")
                    }
                    
                } else {
                    print(error!);
                }
            }
            task.resume()
        } else {
            do {
                if let row = try self.database.pluck(query) {
                    let filemanager = FileManager.default
                    let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory,.userDomainMask,true)[0] as NSString
                    let filePath = row[fileDownload]!
                    let fileUrl = "https://greenbook.net/ajax/download/label/pdf?href=" + row[fileView]!
                    try filemanager.removeItem(atPath: documentsPath.appendingPathComponent(filePath))
                    try database.run(query.update(fileDownload <- fileUrl))
                }
            } catch {
                print(error)
            }
            
        }
    }

    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        let controller = segue.destination as? FileWebView
        let send = sender as? FileTableViewCell
        let query = msds.filter(fileName == send!.file)
        do {
            if let row = try self.database.pluck(query) {
                if (row[fileOffline] == 0) {
                    controller!.url = URL(string: row[fileView]!)
                } else {
                    let filePath = row[fileDownload]!
                    let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory,.userDomainMask,true)[0] as NSString
                    controller!.url = URL(fileURLWithPath: documentsPath.appendingPathComponent(filePath))
                }
            }
        } catch {
            print(error)
        }
    }

}
