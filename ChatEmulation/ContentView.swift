//
//  ContentView.swift
//  ChatEmulation
//
//  Created by Viktor Kushnerov on 22.07.2020.
//  Copyright © 2020 Viktor Kushnerov. All rights reserved.
//
import Dispatch
import ScrollViewProxy
import Speech
import SwiftUI


struct ChatLine: Decodable, Hashable {
    var id: UUID = UUID()
    let line: String
    var opacity: Double = 1.0
    
    enum CodingKeys: String, CodingKey {
        case line
    }
    
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        line = try values.decode(String.self, forKey: .line)
    }
}

typealias ChatLines = [ChatLine]

struct JSON {
    private static func decode<T>(forResource: String) -> T? where T: Decodable {
        var result: T? = nil

        do {
            if
                let path = Bundle.main.path(forResource: forResource, ofType: "json"),
                let jsonData = try String(contentsOfFile: path).data(using: .utf8) {
                result = try JSONDecoder().decode(T.self, from: jsonData)
            }
        } catch {
            assertionFailure("decode \(forResource) \n \(error)")
        }

        return result
    }
}
 
extension JSON {
    static var messages: ChatLines {
        decode(forResource: "messages") ?? .init()
    }
}

// extension ChatLines: Decodable {}

class ViewModel: NSObject, ObservableObject {
    @Published var chat: ChatLines = JSON.messages

    var synthesizerDidFinish: () -> Void = {}
}

extension ViewModel: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_: AVSpeechSynthesizer, didFinish _: AVSpeechUtterance) {
        synthesizerDidFinish()
    }
}

extension Collection {
    func enumeratedArray() -> [(offset: Int, element: Self.Element)] {
        return Array(enumerated())
    }
}

extension View {
    public func border<S>(
        _ content: S,
        width: CGFloat = 1,
        cornerRadius: CGFloat
    ) -> some View where S: ShapeStyle {
        let roundedRect = RoundedRectangle(cornerRadius: cornerRadius)
        let shape = roundedRect.strokeBorder(content, lineWidth: width)

        return overlay(shape)
            .clipShape(roundedRect)
    }
}

extension Color {
    init(hex: Int) {
        let r = (hex & 0xFF0000) >> 16
        let g = (hex & 0xFF00) >> 8
        let b = hex & 0xFF
        self.init(
            red: Double(r) / 0xFF,
            green: Double(g) / 0xFF,
            blue: Double(b) / 0xFF,
            opacity: 1
        )
    }

    static let BACKGROUND_VIEW = Color(hex: 0xF9FAFB)
}

struct ContentView: View {
    @ObservedObject var vm = ViewModel()
    @State var proxy: ScrollViewProxy<Int>? = nil
    private static var speechSynthesizer = AVSpeechSynthesizer()

    var body: some View {
        NavigationView {
            ZStack {
                ScrollView { proxy in
                    ForEach(self.vm.chat.enumeratedArray(), id: \.1) { index, item in
                        HStack {
                            Text("\(item.line)")
                                .padding(10)
                                .background(self.borderView)
                                .id(index, scrollView: proxy)
                            Spacer()
                        }
                        .padding(.top, 30)
                        .padding(.horizontal, 20)
                        .frame(maxWidth: .infinity)
                        .opacity(item.opacity)
                    }.onAppear {
                        self.proxy = proxy
                    }
                }
                .padding(.bottom, 20)
                .background(Color.BACKGROUND_VIEW)
                .edgesIgnoringSafeArea(.bottom)

                HStack {
                    Spacer()
                    VStack {
                        Spacer()

                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title)
                            .foregroundColor(Color.secondary)
                            .onTapGesture {
                                self.proxy?.scrollTo(.top)
                            }
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.title)
                            .foregroundColor(Color.secondary)
                            .padding(.top, 10)
                            .onTapGesture {
                                self.proxy?.scrollTo(.bottom)
                            }
                    }
                    .padding(.trailing, 10)
                }
            }
            .navigationBarTitle("Dialogue", displayMode: .inline)
        }
        .onAppear {
            DispatchQueue.global().async {
                let group = DispatchGroup()

                for index in self.vm.chat.indices {
                    group.enter()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5 * Double(index)) {
                        let speechUtterance: AVSpeechUtterance = AVSpeechUtterance(string: self.vm.chat[index].line)

                        withAnimation(.linear(duration: 5)) {
                            self.vm.chat[index].opacity = 1.0
                        }
                        self.vm.synthesizerDidFinish = {
                            group.leave()
                        }
                        Self.speechSynthesizer.delegate = self.vm
                        Self.speechSynthesizer.speak(speechUtterance)
                    }
                    group.wait()
                }
                self.proxy?.scrollTo(.bottom)
            }
        }
    }

    private var borderView: some View {
        RoundedRectangle(cornerRadius: 5)
            .fill(Color(hex: 0xFDFDFE))
            .border(Color(hex: 0xFDFDFE), width: 1, cornerRadius: 5)
            .shadow(
                color: Color(hex: 0x00000),
                radius: 5, x: 4, y: 4
            )
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
