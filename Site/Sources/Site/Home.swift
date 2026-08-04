import Ignite

struct Home: StaticPage {
    var path = "/"
    var title = "Prismo — See the shape of a PR before you read it"
    var description = "A macOS app for reviewing pull requests in call order. Swift · Kotlin · Dart."

    var downloadURL = "https://github.com/akidon0000/Prismo/releases/latest/download/Prismo-latest.dmg"
    var sourceURL = "https://github.com/akidon0000/Prismo"
    var authorURL = "https://github.com/akidon0000"

    var body: some HTML {
        Section {
            VStack(spacing: 24) {
                Image("images/app-icon.png", description: "Prismo app icon")
                    .resizable()
                    .frame(width: 128, height: 128)
                    .cornerRadius(28)

                Text("Prismo")
                    .font(.title1)
                    .fontWeight(.bold)

                Text("See the shape of a PR before you read it.")
                    .font(.lead)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 560)

                Link("Download for macOS", target: downloadURL)
                    .linkStyle(.button)
                    .role(.primary)
                    .padding(.horizontal, 8)

                Text("macOS 14 or later · Free and open source")
                    .font(.small)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 96)
            .horizontalAlignment(.center)
        }
        .background(.black)
        .foregroundStyle(.white)
        .horizontalAlignment(.center)

        Section {
            Image("images/screenshot.png", description: "Prismo inbox and call-graph review UI")
                .resizable()
                .cornerRadius(16)
                .frame(maxWidth: 900)
                .class("d-block", "mx-auto")
        }
        .padding(.vertical, 64)
        .horizontalAlignment(.center)

        Section {
            VStack(spacing: 16) {
                Text("How it works")
                    .font(.title3)
                    .fontWeight(.bold)

                Text("""
                Prismo lists pull requests waiting for your review, then lays out \
                changed symbols in call order — not file-name order. Checkout the \
                branch and jump into Xcode or Android Studio when you need to dig in. \
                Swift, Kotlin, and Dart first.
                """)
                .frame(maxWidth: 640)
                .foregroundStyle(.secondary)
                .horizontalAlignment(.center)

                Link("View source on GitHub", target: sourceURL)
                    .linkStyle(.underline(.heavy))
            }
            .padding(.vertical, 64)
            .horizontalAlignment(.center)
        }
        .horizontalAlignment(.center)

        Section {
            Text {
                "MIT License · © "
                Link("akidon0000", target: authorURL)
                    .linkStyle(.underline(.heavy))
            }
            .font(.small)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 32)
        .horizontalAlignment(.center)
    }
}
