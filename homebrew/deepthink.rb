cask "deepthink" do
  version "1.0.0"
  sha256 "REPLACE_WITH_SHA256_FROM_RELEASE"

  url "https://github.com/getlost01/deepthink/releases/download/v#{version}/DeepThink-#{version}.zip"
  name "DeepThink"
  desc "AI-powered thinking and knowledge workspace for macOS"
  homepage "https://github.com/getlost01/deepthink"

  app "DeepThink.app"

  # Required: removes quarantine flag since app is unsigned (no Apple Developer membership)
  disable_quarantine true

  zap trash: [
    "~/Library/Application Support/DeepThink",
    "~/Library/Caches/com.deepthink.app",
    "~/Library/Preferences/com.deepthink.app.plist",
    "~/Library/Saved Application State/com.deepthink.app.savedState",
  ]
end
