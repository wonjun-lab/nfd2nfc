class Nfd2nfc < Formula
  desc "Fix macOS NFD Korean filenames by normalizing to NFC"
  homepage "https://github.com/wonjun-lab/nfd2nfc"
  url "https://github.com/wonjun-lab/nfd2nfc/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "5552d6c4a9e5bedee6573b1ce532ed30989f0ac7d31c73db7ab8ddf1f6f2cec0"
  license "MIT"

  def install
    bin.install "nfd2nfc"
  end

  test do
    assert_match "nfd2nfc", shell_output("#{bin}/nfd2nfc --version")
  end
end
