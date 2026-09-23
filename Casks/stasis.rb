cask "stasis" do
  version "0.23.1"
  sha256 "fb4f1d758c5f4d8513a9bf9920dd318c9869394050933320cd21e8512e778658"

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