import Foundation
import Ignite

struct PrismoSite: Site {
    var name = "Prismo"
    var titleSuffix = " – Prismo"
    var description = "See the shape of a PR before you read it."
    var url = URL(static: "https://akidon0000.github.io/Prismo")
    var favicon = URL(string: "images/app-icon.png")
    var useRelativePaths = true

    var homePage = Home()
    var layout = MainLayout()
}
