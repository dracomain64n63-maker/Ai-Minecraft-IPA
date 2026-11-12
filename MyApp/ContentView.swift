import SwiftUI
import SceneKit

struct ContentView: View {
    @StateObject private var game = Game()

    var body: some View {
        ZStack {
            SceneContainer(game: game)
                .ignoresSafeArea()

            // Right half of the screen: drag to look around.
            GeometryReader { geo in
                LookPad(controls: game.controls)
                    .frame(width: geo.size.width / 2, height: geo.size.height)
                    .position(x: geo.size.width * 0.75, y: geo.size.height / 2)
            }

            Circle()
                .fill(Color.white.opacity(0.75))
                .frame(width: 6, height: 6)
                .allowsHitTesting(false)

            VStack {
                Spacer()
                HStack(alignment: .bottom) {
                    Joystick(controls: game.controls)
                    Spacer()
                    HotbarView(controls: game.controls)
                    Spacer()
                    VStack(spacing: 10) {
                        HoldButton(label: "JUMP") { game.controls.jumpHeld = $0 }
                        HStack(spacing: 10) {
                            HoldButton(label: "BREAK") { game.controls.breakHeld = $0 }
                            HoldButton(label: "PLACE") { if $0 { game.controls.placeTapped = true } }
                        }
                    }
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 16)
            }
        }
        .background(Color.black)
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .onAppear { game.start() }
    }
}

struct SceneContainer: UIViewRepresentable {
    let game: Game

    func makeUIView(context: Context) -> SCNView {
        let v = SCNView()
        v.scene = game.scene
        v.pointOfView = game.cameraNode
        v.antialiasingMode = .none
        v.preferredFramesPerSecond = 60
        v.rendersContinuously = true
        v.isPlaying = true
        v.backgroundColor = .black
        v.isUserInteractionEnabled = false
        return v
    }

    func updateUIView(_ uiView: SCNView, context: Context) {}
}

struct LookPad: View {
    let controls: Controls
    @State private var last: CGPoint? = nil

    var body: some View {
        Color.clear
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        if let l = last {
                            controls.lookDelta.x += Double(v.location.x - l.x)
                            controls.lookDelta.y += Double(v.location.y - l.y)
                        }
                        last = v.location
                    }
                    .onEnded { _ in last = nil }
            )
    }
}

struct Joystick: View {
    let controls: Controls
    @State private var knob = CGSize.zero
    private let radius: CGFloat = 55

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.15))
                .overlay(Circle().stroke(Color.white.opacity(0.4), lineWidth: 2))
            Circle()
                .fill(Color.white.opacity(0.45))
                .frame(width: 50, height: 50)
                .offset(knob)
        }
        .frame(width: radius * 2, height: radius * 2)
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { v in
                    var dx = v.location.x - radius
                    var dy = v.location.y - radius
                    let len = (dx * dx + dy * dy).squareRoot()
                    if len > radius {
                        dx = dx / len * radius
                        dy = dy / len * radius
                    }
                    knob = CGSize(width: dx, height: dy)
                    controls.move = SIMD2<Double>(Double(dx / radius), Double(-dy / radius))
                }
                .onEnded { _ in
                    knob = .zero
                    controls.move = SIMD2<Double>(0, 0)
                }
        )
    }
}

struct HoldButton: View {
    let label: String
    let onChange: (Bool) -> Void
    @State private var pressed = false

    var body: some View {
        Text(label)
            .font(.system(size: 13, weight: .bold))
            .foregroundColor(.white)
            .frame(width: 64, height: 64)
            .background(Circle().fill(Color.black.opacity(pressed ? 0.6 : 0.35)))
            .overlay(Circle().stroke(Color.white.opacity(0.5), lineWidth: 2))
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !pressed {
                            pressed = true
                            onChange(true)
                        }
                    }
                    .onEnded { _ in
                        pressed = false
                        onChange(false)
                    }
            )
    }
}

struct HotbarView: View {
    @ObservedObject var controls: Controls

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<Game.hotbar.count, id: \.self) { i in
                let selected = i == controls.selectedSlot
                Image(uiImage: TextureAtlas.tileImage(Game.hotbar[i].tile(.side)))
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 34, height: 34)
                    .padding(2)
                    .background(Color.black.opacity(0.4))
                    .overlay(
                        Rectangle()
                            .stroke(selected ? Color.white : Color.gray.opacity(0.6),
                                    lineWidth: selected ? 3 : 1)
                    )
                    .onTapGesture { controls.selectedSlot = i }
            }
        }
    }
}
