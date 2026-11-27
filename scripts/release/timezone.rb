# Template for Casks/timezone.rb in vyavahareyash/homebrew-tap; .github/workflows/release.yml fills in @VERSION@ and @SHA256@.
cask "timezone" do
  version "@VERSION@"
  sha256 "@SHA256@"

  url "https://github.com/vyavahareyash/Timezone/releases/download/v#{version}/Timezone.dmg"
  name "Timezone"
  desc "Menu bar app for picking meeting times across time zones"
  homepage "https://github.com/vyavahareyash/Timezone"

  depends_on macos: :tahoe

  app "Timezone.app"

  # Not notarized (no Apple Developer membership): clear quarantine so it opens without the Open Anyway step.
  postflight do
    system_command "/usr/bin/xattr", args: ["-cr", "#{appdir}/Timezone.app"]
  end

  uninstall quit: "com.vyavahareyash.Timezone"

  zap trash: "~/Library/Preferences/com.vyavahareyash.Timezone.plist"
end
