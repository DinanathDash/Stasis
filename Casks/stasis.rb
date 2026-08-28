cask "stasis" do
  version "0.21.1"
  sha256 "ef7275f5f8fa2661ad8a856aed13899683daa851b3b587a513a5118375de9f91"

  url "https://github.com/DinanathDash/Stasis/releases/download/v#{version}/Stasis.dmg"
  name "Stasis"
  desc "Battery management tool (Dinanath's Fork)"
  homepage "https://github.com/DinanathDash/Stasis"

  auto_updates true

  app "Stasis.app"

  uninstall quit:      "com.dinanathdash.stasis",
            launchctl: [
              "com.dinanathdash.stasis.helper",
              "com.dinanathdash.stasis.charging-helper"
            ],
            delete:    [
              "/Library/PrivilegedHelperTools/com.dinanathdash.stasis.helper",
              "/Library/PrivilegedHelperTools/com.dinanathdash.stasis.charging-helper"
            ]
end