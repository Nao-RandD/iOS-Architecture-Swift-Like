///
/// あるアプリ内に「メッセージ」と呼ばれる概念がある
///
/// - TextMessage: textを持つ
/// - ImageMessage: imageを持ち、オプショナルでtextを添えられる
/// - OfficialMessage: 受信専用。ユーザーは送信不可能
///
/// * メッセージ送信の元となる入力値を保持し、その値をサーバに送信する
/// * 通信結果を保持し、delegateに結果を伝える
///

import UIKit

enum MessageType {
    case text, image, official
}

protocol MessageSenderDelegate {
    func validではないことを伝える()
    func 通信完了を伝える()
}

protocol Message {}

struct TextMessage: Message {}

struct ImageMessage: Message {}

// MessageSender.swift
final class CommonMessageAPI {
    func fetchAll(ofUserId: Int, completion: @escaping ([Message]?) -> Void) {}
    func fetch(id: Int, completion: @escaping (Message?) -> Void) {}
    func sendTextMessage(text: String, completion: @escaping (TextMessage?) -> Void) {
        // 送信処理が入
        print("\(#function) ------ message: \(text)を送信完了しました\n\n")
        completion(TextMessage())
    }
    func sendImageMessage(image: UIImage, text: String?, completion: @escaping (ImageMessage?) -> Void) {
        // 送信処理が入る
        print("\(#function) ------ message: \(text ?? "空")\n image: \(image.description)\n を送信完了しました\n\n")
        completion(ImageMessage())
    }
}

final class MessageSender {
    private let api = CommonMessageAPI()
    let messageType: MessageType
    var delegate: MessageSenderDelegate?

    // MessageType.officialをセットするのは禁止！！
    init(messageType: MessageType) {
        self.messageType = messageType
    }

    // MARK: 送信するメッセージの入力値
    var text: String? { // TextMessage, ImageMessage どちらの場合も使う
        didSet {
            if !isTextValid {
                delegate?.validではないことを伝える()
            }
        }
    }

    var image: UIImage? { // ImageMessageの場合に使う
        didSet {
            if !isImageValid {
                delegate?.validではないことを伝える()
            }
        }
    }

    // MARK: 通信結果
    private(set) var isLoading: Bool = false
    private(set) var result: Message? // 送信成功したら値が入る

    // MARK: バリデーション
    private var isTextValid: Bool {
        switch messageType {
        case .text:
            return text != nil && text!.count <= 300
        case .image:
            return text == nil || text!.count <= 80
        case .official:
            return false // OfficialMessageはありえない
        }
    }

    private var isImageValid: Bool {
        return image != nil // imageの場合だけ考慮
    }

    private var isValid: Bool {
        switch messageType {
        case .text:
            return isTextValid
        case .image:
            return isTextValid && isImageValid
        case .official:
            return false // OfficialMessageはありえない
        }
    }

    func send() {
        guard isValid else {
            delegate?.validではないことを伝える()
            return
        }
        isLoading = true
        switch messageType {
        case .text:
            api.sendTextMessage(text: text!) { [weak self] result in
                self?.isLoading = false
                self?.result = result
                self?.delegate?.通信完了を伝える()
            }
        case .image:
            api.sendImageMessage(image: image!, text: text) { [weak self] result in
                self?.isLoading = false
                self?.result = result
                self?.delegate?.通信完了を伝える()
            }
        case .official:
            fatalError("officialMessageは送れません！")
        }
    }
}

class MessageSenderRepository: MessageSenderDelegate {
    func send(messageType: MessageType, message: String?, image: UIImage?) {
        let sender = MessageSender(messageType: messageType)
        sender.delegate = self
        switch messageType {
        case .text:
            sender.text = message
        case .image:
            sender.text = message
            sender.image = image
        case .official:
            fatalError("officialメッセージは送信できません")
        }
        sender.send()
    }

    func validではないことを伝える() {
        print("有効でない情報が含まれるために送信できませんでした")
    }

    func 通信完了を伝える() {
        print("通信完了しました")
    }
}

let senderRepository = MessageSenderRepository()
senderRepository.send(messageType: .text, message: "text送信処理のテスト", image: nil)
print("---------------------")
senderRepository.send(messageType: .image, message: "image送信処理のテスト", image: UIImage(systemName: "pencil"))
