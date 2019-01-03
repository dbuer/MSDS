//
//  FileWebView.swift
//  MSDS
//
//  Created by Dylan Buer on 12/28/18.
//  Copyright © 2018 Dylan Buer. All rights reserved.
//

import UIKit
import WebKit

class FileWebView: UIViewController {

    @IBOutlet weak var fileView: WKWebView!
    
    var url: URL?
    override func viewDidLoad() {
        super.viewDidLoad()
        fileView.load(URLRequest(url: url!))
    }
}
