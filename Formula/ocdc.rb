class Ocdc < Formula
  desc "OpenCode DevContainers - Run multiple devcontainer instances with auto-assigned ports"
  homepage "https://github.com/athal7/ocdc"
  url "https://github.com/athal7/ocdc/archive/refs/tags/v2.2.0.tar.gz"
  sha256 "" # Will be filled during release
  license "MIT"
  head "https://github.com/athal7/ocdc.git", branch: "main"

  depends_on "jq"
  depends_on "tmux"

  def install
    # Install everything to prefix to maintain relative paths
    prefix.install Dir["bin", "lib", "plugin", "share"]
    
    # Symlink main executable to bin
    bin.install_symlink prefix/"bin/ocdc"
  end

  def caveats
    <<~EOS
      To enable automatic polling of GitHub issues and PRs:
      
      1. Configure your poll settings:
         mkdir -p ~/.config/ocdc/polls
         cp #{prefix}/share/ocdc/examples/github-issues.yaml ~/.config/ocdc/polls/
         # Edit ~/.config/ocdc/polls/github-issues.yaml with your repos
      
      2. Start the polling service:
         brew services start ocdc
      
      The polling service runs every 5 minutes and automatically creates
      devcontainer sessions for new issues/PRs with the configured label.
      
      View logs:
         tail -f #{var}/log/ocdc-poll.log
    EOS
  end

  service do
    run [opt_bin/"ocdc", "poll", "--once"]
    run_type :interval
    interval 300
    keep_alive false
    log_path var/"log/ocdc-poll.log"
    error_log_path var/"log/ocdc-poll.log"
    environment_variables PATH: std_service_path_env
  end

  test do
    assert_match "ocdc v#{version}", shell_output("#{bin}/ocdc version")
  end
end
