import Foundation

enum ReactionFormatter {
    static func summaryText(for reactions: [PostReaction], maxEmojiCount: Int) -> String {
        guard !reactions.isEmpty else { return "" }

        let topReactions = Dictionary(grouping: reactions, by: \.emoji)
            .map { (emoji: $0.key, count: $0.value.count) }
            .sorted {
                if $0.count == $1.count {
                    return $0.emoji < $1.emoji
                }
                return $0.count > $1.count
            }

        let shown = topReactions
            .prefix(maxEmojiCount)
            .map { "\($0.emoji) \($0.count)" }
            .joined(separator: "  ")
        let hiddenCount = max(0, topReactions.count - maxEmojiCount)

        return hiddenCount > 0 ? "\(shown)  +\(hiddenCount)" : shown
    }
}
