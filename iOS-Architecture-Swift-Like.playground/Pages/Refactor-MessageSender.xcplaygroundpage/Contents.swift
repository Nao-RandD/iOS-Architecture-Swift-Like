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

// MARK: 送信タイプを管理するようのenumを定義する
//
// Interface Segregation Principle（インターフェース分離の原則）
enum SendableMessageType {
    case text, image
}
// ↓↓↓
// MARK: 送信タイプを管理するようのenumを定義する
//
// Interface Segregation Principle（インターフェース分離の原則）
enum SendableMessageStrategy {
    case text(api: TextMessageSenderAPI, input: TextMessageInput)
    case image(api: ImageMessageSenderAPI, input: ImageMessageInput)

    mutating func update(input: SendableMessageStrategy) {
        self = input
    }

    var description: String {
        switch self {
        case .text(api: _, input: _):
            return "TextMessageSenderAPIでの送信"
        case .image(api: _, input: _):
            return "ImageMessageSenderAPIでの送信"
        }
    }

    func send(completion: @escaping (Message?) -> Void) {
        // caseごとの送信処理を行う
        print("送信処理：", self.description)
    }
}

//var strategy = SendableMessageStrategy.text(api: TextMessageSenderAPI(), input: TextMessageInput(text: ""))
//strategy.send { _ in }
//strategy.update(input: SendableMessageStrategy.image(api: ImageMessageSenderAPI(), input: ImageMessageInput(text: "", image: UIImage())))
//strategy.send { _ in }

// MARK: API側
//
// Dependency Inversion Principle（依存関係逆転の原則）
protocol CommonMessageAPIProtocol {
    func fetchAll(ofUserId: Int, completion: @escaping ([Message]?) -> Void)
    func fetch(id: Int, completion: @escaping (Message?) -> Void)
    func sendTextMessage(text: String, completion: @escaping (TextMessage?) -> Void)
    func sendImageMessage(image: UIImage, text: String?, completion: @escaping (ImageMessage?) -> Void)
}

struct TextMessageSenderAPI: CommonMessageAPIProtocol {
    func fetchAll(ofUserId: Int, completion: @escaping ([Message]?) -> Void) {}

    func fetch(id: Int, completion: @escaping (Message?) -> Void) {}

    func sendTextMessage(text: String, completion: @escaping (TextMessage?) -> Void) {}

    func sendImageMessage(image: UIImage, text: String?, completion: @escaping (ImageMessage?) -> Void) {}
}

struct ImageMessageSenderAPI: CommonMessageAPIProtocol {
    func fetchAll(ofUserId: Int, completion: @escaping ([Message]?) -> Void) {}

    func fetch(id: Int, completion: @escaping (Message?) -> Void) {}

    func sendTextMessage(text: String, completion: @escaping (TextMessage?) -> Void) {}

    func sendImageMessage(image: UIImage, text: String?, completion: @escaping (ImageMessage?) -> Void) {}
}

// MARK: バリデーションを閉じ込める
//
// Single Responsibility Principle（単一責任原則）
struct ImageMessageInput {
    var text: String?
    var image: UIImage?

    enum InputError: Error {
        case noImage, tooLongText(count: Int)
    }

    func validate() throws -> (image: UIImage, text: String?) {
        guard let image = image else {
            throw InputError.noImage
        }
        if let text = text, text.count >= 80 {
            throw InputError.tooLongText(count: text.count)
        }
        return (image, text)
    }
}

struct TextMessageInput {
    var text: String

    enum InputError: Error {
        case tooLongText(count: Int)
    }

    func validate() throws -> String {
        if text.count >= 300 {
            throw InputError.tooLongText(count: text.count)
        }
        return text
    }
}

protocol MessageSenderDelegate {
    func validではないことを伝える()
    func 通信完了を伝える()
}

protocol Message {}

struct TextMessage: Message {}

struct ImageMessage: Message {}

// MessageSender.swift
final class CommonMessageAPI: CommonMessageAPIProtocol {
    func fetchAll(ofUserId: Int, completion: @escaping ([Message]?) -> Void) {}
    func fetch(id: Int, completion: @escaping (Message?) -> Void) {}
    func sendTextMessage(text: String, completion: @escaping (TextMessage?) -> Void) {}
    func sendImageMessage(image: UIImage, text: String?, completion: @escaping (ImageMessage?) -> Void) {}
}

final class MessageSender {
    private let api: CommonMessageAPIProtocol
    let messageType: MessageType
    var delegate: MessageSenderDelegate?

    // MessageType.officialをセットするのは禁止！！
    init(api: CommonMessageAPIProtocol, messageType: MessageType) {
        self.messageType = messageType
        self.api = api
    }

    // MARK: 送信するメッセージの入力値
    var text: String? { // TextMessage, ImageMessage どちらの場合も使う
        didSet { if !isImageValid { delegate?.validではないことを伝える() }}
    }

    var image: UIImage? { // ImageMessageの場合に使う
        didSet { if !isImageValid { delegate?.validではないことを伝える() }}
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
