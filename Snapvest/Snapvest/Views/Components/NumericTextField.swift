//
//  NumericTextField.swift
//  Snapvest
//
//  Created on 2024
//

import SwiftUI
import UIKit

struct NumericTextField: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var keyboardType: UIKeyboardType
    
    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.placeholder = placeholder
        textField.keyboardType = keyboardType
        textField.delegate = context.coordinator
        textField.text = text
        textField.font = UIFont.systemFont(ofSize: 16)
        textField.textColor = UIColor.label
        textField.backgroundColor = UIColor.systemGray6
        textField.layer.cornerRadius = 12
        textField.layer.borderWidth = 1
        textField.layer.borderColor = UIColor.separator.cgColor
        textField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: 0))
        textField.leftViewMode = .always
        textField.rightView = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: 0))
        textField.rightViewMode = .always
        textField.autocorrectionType = .no
        textField.autocapitalizationType = .none
        textField.spellCheckingType = .no
        return textField
    }
    
    func updateUIView(_ uiView: UITextField, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        if uiView.keyboardType != keyboardType {
            uiView.keyboardType = keyboardType
            // 強制重新載入鍵盤
            uiView.reloadInputViews()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UITextFieldDelegate {
        var parent: NumericTextField
        
        init(_ parent: NumericTextField) {
            self.parent = parent
        }
        
        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            // 允許正常的文本輸入，然後在 onChange 中過濾
            return true
        }
        
        func textFieldDidChangeSelection(_ textField: UITextField) {
            parent.text = textField.text ?? ""
        }
        
        func textFieldDidBeginEditing(_ textField: UITextField) {
            // 確保鍵盤類型正確
            textField.keyboardType = parent.keyboardType
            textField.reloadInputViews()
        }
        
        func textFieldDidEndEditing(_ textField: UITextField) {
            // 編輯結束時更新
            parent.text = textField.text ?? ""
        }
    }
}

