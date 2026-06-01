class Nfd2nfc < Formula
  desc "Fix macOS NFD Korean filenames by normalizing to NFC"
  homepage "https://github.com/wonjun-lab/nfd2nfc"
  url "https://github.com/wonjun-lab/nfd2nfc/archive/refs/tags/v1.0.1.tar.gz"
  sha256 "0a1507c5db4a272f2f0e7a013ff01bac12e320eec434d65c3ee548fab61c4103"
  license "MIT"

  def install
    bin.install "nfd2nfc"
  end

  test do
    assert_match "nfd2nfc", shell_output("#{bin}/nfd2nfc --version")
  end
end
