class Nfd2nfc < Formula
  desc "Fix macOS NFD Korean filenames by normalizing to NFC"
  homepage "https://github.com/wonjun-lab/nfd2nfc"
  url "https://github.com/wonjun-lab/nfd2nfc/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "0000000000000000000000000000000000000000000000000000000000000000" # 릴리스 후 실제 sha256으로 교체 (CONTRIBUTING 참고)
  license "MIT"

  def install
    bin.install "nfd2nfc"
  end

  test do
    assert_match "nfd2nfc", shell_output("#{bin}/nfd2nfc --version")
  end
end
