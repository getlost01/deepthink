cask "deepthink" do
  version "1.0.0"
  sha256 "a9cacfa2ca6d43f833f4dde9996a8fb909c3a622894dfd3ccb0a4e1ada6584c5"

  url "https://github.com/getlost01/deepthink/releases/download/v#{version}/DeepThink-#{version}.zip"
  name "DeepThink"
  desc "AI-powered thinking and knowledge workspace"
  homepage "https://github.com/getlost01/deepthink"

  depends_on :macos

  app "DeepThink.app"

  postflight do
    system_command "/usr/bin/xattr",
                   args: ["-rd", "com.apple.quarantine", "#{appdir}/DeepThink.app"]
  end

  zap trash: [
    "~/Library/Application Support/DeepThink",
    "~/Library/Caches/com.deepthink.app",
    "~/Library/Preferences/com.deepthink.app.plist",
    "~/Library/Saved Application State/com.deepthink.app.savedState",
  ]
end
