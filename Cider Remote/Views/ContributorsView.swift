// Made by Lumaa
// For current contributors & future contributors

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
                Section(footer: Text("From the official [Cider Remote repository](https://github.com/ciderapp/Cider-Remote), tap on a user's profile to know more about their coding experience and GitHub repository.")) {
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
                if #available(iOS 17.0, *) {
                    ContentUnavailableView(
                        "Couldn't find any contributors",
                        systemImage: "person.crop.circle.badge.xmark",
                        description: Text("Maybe try checking your internet connection or GitHub's status...")
                    )
                } else {
                    VStack {
                        Text("Couldn't find any contributors")
                            .font(.title.bold())

                        Text("Maybe try checking your internet connection or GitHub's status...")
                            .font(.caption)
                            .foregroundStyle(Color.gray)
                    }
                    .padding(.vertical)
                }
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
            }
        }
        .navigationTitle(Text("Contributors"))
        .navigationBarTitleDisplayMode(.large)
    }

    @ViewBuilder
    private func contribView(_ contrib: Self.Contrib) -> some View {
        let imageSize: CGFloat = 35.0

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

                Text("^[\(contrib.commitCount) contribution](inflect: true)") // auto pluralizes
                    .font(.caption)
                    .foregroundStyle(Color.gray)
            }
            .padding(.horizontal)
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

        init(id: String, name: String, ghLink: URL, commits: Int = 0, pfp: URL? = nil) {
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
