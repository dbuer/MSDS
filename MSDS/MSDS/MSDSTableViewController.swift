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
    let fieView = Expression<String?>("view")
    let fileDownload = Expression<String?>("download")
    
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
            do {
                let query = self.msds.filter(fileName.like("%\(text)%"))
                let seq = try self.database.prepare(query)
                let m = seq.map{ $0[fileName]! }
                self.files.insert(m, at: 0)
                self.tableView.insertSections([0], with: .fade)
            } catch {
                print(error)
            }
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
                
                let documentsURL = Bundle.main.resourceURL?.appendingPathComponent("msds.db")
                
                do {
                    try fileManager.copyItem(atPath: (documentsURL?.path)!, toPath: finalDatabaseURL.path)
                } catch {
                    print("Couldn't copy file to final location!")
                }
                
            }
            
            self.database = try Connection(finalDatabaseURL.path);
            let seq = try self.database.prepare(msds)
            let m = seq.map{ $0[fileName]! }
            self.files.insert(m, at: 0)
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
        if let fileCell = cell as? FileTableViewCell {
            fileCell.file = file
        }
        return cell
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
