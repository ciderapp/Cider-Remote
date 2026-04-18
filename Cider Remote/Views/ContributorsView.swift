// Made by Lumaa
// For current, past and future contributors

import SwiftUI

struct ContributorsView: View {
    @Environment(\.openURL) private var openURL: OpenURLAction
    @Environment(\.dismiss) private var dismiss: DismissAction

    private static let apiUrl: URL = URL(string: "https://api.github.com/repos/ciderapp/Cider-Remote/contributors")!

    @State private var fetchedContribs: [Self.Contrib] = []
    @State private var fetchingData: Bool = true

    var body: some View {
        List {
            if !fetchingData && fetchedContribs.count > 0 {
                Section(header: Text(String("Cider Remote")),footer: Text("From the official [Cider Remote repository](https://github.com/ciderapp/Cider-Remote), tap on a user's profile to know more about their coding experience and GitHub repository.")) {
                    ForEach(self.fetchedContribs) { contrib in
                        Button {
                            openURL(contrib.ghLink)
                        } label: {
                            contribView(contrib)
                        }
                        .tint(Color(uiColor: UIColor.label))
                    }
                }
            } else if !fetchingData && fetchedContribs.count <= 0 {
                ContentUnavailableView(
                    "Couldn't find any contributors",
                    systemImage: "person.crop.circle.badge.xmark",
                    description: Text("Maybe try checking your internet connection or GitHub's status...")
                )
            } else if fetchingData {
                ProgressView()
                    .progressViewStyle(.circular)
                    .task {
                        defer { self.fetchingData = false }

                        do {
                            self.fetchedContribs = try await self.getContributors() ?? []
                        } catch {
                            print(error)
                        }
                    }
                    .listRowBackground(Color.clear)
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            Section(header: Text(String("Cider Collective"))) {
                LazyVGrid(columns: [.init(.fixed(170)), .init(.fixed(170))]) {
                    ForEach(Contrib.collective) { contrib in
                        Button {
                            openURL(contrib.ghLink)
                        } label: {
                            self.collectiveView(contrib)
                        }
                        .tint(Color(uiColor: UIColor.label))
                        .buttonStyle(.plain)
                    }
                }

                Button {
                    if let url = URL(string: "https://cider.sh/about") {
                        openURL(url)
                    }
                } label: {
                    Text("More about Cider Collective")
                }
            }
        }
        .listSectionSpacing(30)
        .navigationTitle(Text("Contributors"))
        .navigationBarTitleDisplayMode(.large)
    }

    @ViewBuilder
    private func contribView(_ contrib: Self.Contrib) -> some View {
        let imageSize: CGFloat = 45.0

        HStack {
            AsyncImage(url: contrib.pfp) { image in
                image
                    .resizable()
                    .scaledToFit()
                    .frame(width: imageSize, height: imageSize)
                    .clipShape(Circle())
            } placeholder: {
                Circle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: imageSize, height: imageSize)
            }

            VStack(alignment: .leading) {
                Text(contrib.name)
                    .font(.title2.bold())
                    .lineLimit(1)

                if contrib.commitCount > 0 {
                    Text("^[\(contrib.commitCount) contribution](inflect: true)") // auto pluralizes
                        .font(.caption)
                        .foregroundStyle(Color.gray)
                } else {
                    Text("No contributions")
                        .font(.caption)
                        .foregroundStyle(Color.gray)
                }
            }
            .padding(.horizontal)
        }
    }

    @ViewBuilder
    private func collectiveView(_ contrib: Self.Contrib) -> some View {
        let imageSize: CGFloat = 65.0

        VStack(alignment: .center) {
            AsyncImage(url: contrib.pfp) { image in
                image
                    .resizable()
                    .scaledToFit()
                    .frame(width: imageSize, height: imageSize)
                    .clipShape(Circle())
            } placeholder: {
                Circle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: imageSize, height: imageSize)
            }

            Text(contrib.name)
                .font(.title2.bold())
                .lineLimit(1)
        }
    }

    /// Get the ciderapp/Cider-Remote's contributors list
    private func getContributors() async throws -> [Self.Contrib]? {
        // 20s timeout - no cookies cause no tracking
        let req: URLRequest = .init(url: Self.apiUrl, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 20)

        let (data, _) = try await URLSession.shared.data(for: req)
        if let json: [[String : Any]] = try JSONSerialization.jsonObject(with: data) as? [[String : Any]] {
            var contribs: [Self.Contrib] = []

            for contributor in json {
                let newContrib: Self.Contrib = .init(
                    id: contributor["id"] as? String ?? UUID().uuidString,
                    name: contributor["login"] as? String ?? "Unknown Name",
                    ghLink: URL(string: contributor["html_url"] as? String ?? "https://github.com/404") ?? URL(string: "https://github.com/404")!,
                    commits: contributor["contributions"] as? Int ?? 0,
                    pfp: URL(string: contributor["avatar_url"] as? String ?? "")
                )
                contribs.append(newContrib)
            }

            return contribs
        } else {
            print("Couldn't rematch type [String : String] for contributors")
        }
        return nil
    }

    private struct Contrib: Identifiable {
        let id: String
        let name: String
        let ghLink: URL
        let pfp: URL?
        let commitCount: Int

        /// Cider Collective (10/25)
        static let collective: [Contrib] = [
            .init(name: "cryptofyre", ghLink: URL(string: "https://github.com/cryptofyre")!, pfp: URL(string: "https://avatars.githubusercontent.com/u/33162551?v=4")),
            .init(name: "Core", ghLink: URL(string: "https://github.com/coredev-uk")!, pfp: URL(string: "https://avatars.githubusercontent.com/u/64542347?v=4")),
            .init(name: "booploops", ghLink: URL(string: "https://github.com/booploops")!, pfp: URL(string: "https://avatars.githubusercontent.com/u/49113086?v=4")),
            .init(name: "Maikiwi", ghLink: URL(string: "https://github.com/maikirakiwi")!, pfp: URL(string: "https://avatars.githubusercontent.com/u/74925636?v=4")),
            .init(name: "yazninja", ghLink: URL(string: "https://github.com/yazninja")!, pfp: URL(string: "https://avatars.githubusercontent.com/u/71800112?v=4")),
            .init(name: "luckieluke", ghLink: URL(string: "https://github.com/lockieluke")!, pfp: URL(string: "https://avatars.githubusercontent.com/u/25424409?v=4")),
            .init(name: "Monochromish", ghLink: URL(string: "https://github.com/Monochromish")!, pfp: URL(string: "https://avatars.githubusercontent.com/u/79590499?v=4")),
            .init(name: "Quacksire", ghLink: URL(string: "https://github.com/quacksire")!, pfp: URL(string: "https://avatars.githubusercontent.com/u/19170969?v=4")),
            .init(name: "Amaru", ghLink: URL(string: "https://github.com/Amaru8")!, pfp: URL(string: "https://avatars.githubusercontent.com/u/52407090?v=4")),
            .init(name: "Swiftzerr", ghLink: URL(string: "https://github.com/elliotjarnit")!, pfp: URL(string: "https://avatars.githubusercontent.com/u/67812203?v=4")),
            .init(name: "DeadFrost", ghLink: URL(string: "https://github.com/DeadFrostt")!, pfp: URL(string: "https://avatars.githubusercontent.com/u/71704732?v=4")),
            .init(name: "Lumaa", ghLink: URL(string: "https://github.com/lumaa-dev")!, pfp: URL(string: "https://avatars.githubusercontent.com/u/93350976?v=4"))
        ]

        init(id: String = UUID().uuidString, name: String, ghLink: URL, commits: Int = 0, pfp: URL? = nil) {
            self.id = id
            self.name = name
            self.ghLink = ghLink
            self.commitCount = commits
            self.pfp = pfp
        }
    }
}

#Preview {
    ContributorsView()
}
