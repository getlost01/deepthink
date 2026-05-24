cask "deepthink" do
  version "1.0.1"
  sha256 "f56861adcd8865a3054ad72c859314d352da5093f4d9fc54b4ba1e9fa62d29e9"

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
