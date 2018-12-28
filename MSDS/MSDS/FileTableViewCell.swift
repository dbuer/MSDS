//
//  FileTableViewCell.swift
//  SQLite iOS
//
//  Created by Dylan Buer on 12/27/18.
//

import UIKit

class FileTableViewCell: UITableViewCell {

    @IBOutlet weak var pesticideLabel: UILabel!
    @IBOutlet weak var downloadSwitch: UISwitch!
    
    var file: String? {
        didSet {
            pesticideLabel?.text = file
        }
    }
}
