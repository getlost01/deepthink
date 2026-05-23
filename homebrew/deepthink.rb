cask "deepthink" do
  version "1.0.0"
  sha256 "REPLACE_WITH_SHA256_FROM_RELEASE"

  url "https://github.com/getlost01/deepthink/releases/download/v#{version}/DeepThink-#{version}.zip"
  name "DeepThink"
  desc "AI-powered thinking and knowledge workspace"
  homepage "https://github.com/getlost01/deepthink"

  depends_on :macos

  app "DeepThink.app"

  zap trash: [
    "~/Library/Application Support/DeepThink",
    "~/Library/Caches/com.deepthink.app",
    "~/Library/Preferences/com.deepthink.app.plist",
    "~/Library/Saved Application State/com.deepthink.app.savedState",
  ]

  caveats <<~EOS
    DeepThink is ad-hoc signed (no Apple Developer ID). macOS may show an
    "unidentified developer" warning. To open it, right-click and choose Open,
    or remove the quarantine flag:
      xattr -rd com.apple.quarantine /Applications/DeepThink.app
  EOS
end
