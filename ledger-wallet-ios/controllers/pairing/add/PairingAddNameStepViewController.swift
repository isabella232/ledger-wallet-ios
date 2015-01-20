//
//  PairingAddNameStepViewController.swift
//  ledger-wallet-ios
//
//  Created by Nicolas Bigot on 16/01/2015.
//  Copyright (c) 2015 Ledger. All rights reserved.
//

import UIKit

class PairingAddNameStepViewController: PairingAddBaseStepViewController {
    
    @IBOutlet private weak var nameTextField: TextField!
    
    override var stepIndication: String {
        return localizedString("give_a_name_to_your_wallet")
    }
    override var stepNumber: Int {
        return 3
    }
    override var finalizesFlow: Bool {
        return true
    }
    
    //MARK: Interface
    
    override func configureView() {
        super.configureView()
        
        nameTextField.becomeFirstResponder()
    }
    
}
