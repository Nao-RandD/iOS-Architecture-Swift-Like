
import UIKit

protocol MessageInput {
    associatedtype Payload

    func validate() throws -> Payload
}

struct ImageMessageInput: MessageInput {
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

struct TextMessageInput: MessageInput {
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


protocol MessageSenderAPI {
    associatedtype Payload
    associatedtype Response: Message

    func send(payload: Payload, completion: @escaping (Response?) -> Void)
}

protocol MessageSenderDelegate {
    func stateの変化を伝える()
}

final class MessageSender<API: MessageSenderAPI, Input: MessageInput> where API.Payload == Input.Payload {
    enum State {
        case inputting(validateionError: Error?)
        case sending
        case send(API.Response)
        case connectionFailed

        init(evaluating input: Input) {
            if let validationError = try? input.validate() {
                self = .inputting(validateionError: validationError as? Error)
            } else {
                self = .sending
            }
        }
        mutating func accept(response: API.Response?) {
            guard let response = response else {
                self = .connectionFailed
                return
            }
            self = .send(response)
        }
    }

    private(set) var state: State {
        didSet { delegate?.stateの変化を伝える() }
    }
    let api: API
    var input: Input {
        didSet { state = State(evaluating: input)}
    }
    var delegate: MessageSenderDelegate?

    init(api: API, input: Input) {
        self.api = api
        self.input = input
        self.state = State(evaluating: input)
    }

    func send() {
        do {
            let payload = try input.validate()
            state = .sending
            api.send(payload: payload) { [weak self] message in
                self?.state.accept(response: message)
            }
        } catch let e {
            state = .inputting(validateionError: e)
        }
    }
}

protocol Message {}

struct TextSendRepository: MessageSenderDelegate {
    struct TextMessage: Message {
        var text: String
    }

    struct TextMessageSender: MessageSenderAPI {
        typealias Payload = String
        typealias Response = TextMessage

        func send(payload: String, completion: @escaping (TextMessage?) -> Void) {
            let message = TextMessage(text: "\(payload)を受け取りました")
            completion(message)
        }
    }

    private var sender: MessageSender<TextMessageSender, TextMessageInput>

    init(input payload: String) {
        self.sender =  MessageSender(
            api: TextMessageSender(),
            input: TextMessageInput(text: payload))
        sender.delegate = self
    }

    func stateの変化を伝える() {
        switch sender.state {
        case .inputting(validateionError: let validateionError):
            print("バリデーションに失敗", validateionError!)
        case .sending:
            print("送信中")
        case .send(let message):
            print("メッセージの送信に成功：", message.text)
        case .connectionFailed:
            print("通信失敗")
        }
    }

    func send() {
        sender.send()
    }
}


// MARK: 実際のユースケース

print("<<成功するインプット>>")
let successInputRepo = TextSendRepository(input: "テスト")
successInputRepo.send()

print()

print("<<失敗するインプット>>")
let failedInputRepo = TextSendRepository(input: String(repeating: "A", count: 301))
failedInputRepo.send()

