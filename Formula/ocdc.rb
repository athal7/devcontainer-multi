class Ocdc < Formula
  desc "OpenCode DevContainers - Run multiple devcontainer instances with auto-assigned ports"
  homepage "https://github.com/athal7/ocdc"
  url "https://github.com/athal7/ocdc/archive/refs/tags/v2.2.0.tar.gz"
  sha256 "2f3e5fc95cf77d3fc43011cb53a3556779ec332104cb66b347a96dd8a11b47dc"
  license "MIT"
  head "https://github.com/athal7/ocdc.git", branch: "main"

  depends_on "jq"
  depends_on "tmux"

  def install
    # Install everything to prefix to maintain relative paths
    # The ocdc script uses BASH_SOURCE + pwd which resolves symlinks
    prefix.install Dir["bin", "lib", "plugin", "share", "skill"]
    bin.install_symlink prefix/"bin/ocdc"
  end

  def post_install
    # Skip in CI/test environments where HOME may not be writable
    return if ENV["CI"] || ENV["HOMEBREW_GITHUB_API_TOKEN"]
    
    require "json"
    require "fileutils"
    
    opencode_config_dir = Pathname.new(Dir.home)/".config/opencode"
    plugin_dest = opencode_config_dir/"plugins/ocdc"
    plugin_src = prefix/"plugin"
    plugin_path = plugin_dest.to_s
    
    # Install plugin files
    plugin_dest.mkpath
    (plugin_dest/"command").mkpath
    
    # Copy plugin files (remove first to handle permission issues)
    %w[index.js helpers.js].each do |file|
      dest_file = plugin_dest/file
      dest_file.unlink if dest_file.exist?
      FileUtils.cp plugin_src/file, dest_file
    end
    
    cmd_dest = plugin_dest/"command/ocdc.md"
    cmd_dest.unlink if cmd_dest.exist?
    FileUtils.cp plugin_src/"command/ocdc.md", cmd_dest
    
    # Symlink skill
    skill_dest = opencode_config_dir/"skill/ocdc"
    skill_dest.dirname.mkpath
    skill_src = prefix/"skill/ocdc"
    FileUtils.rm_rf skill_dest
    FileUtils.ln_s skill_src, skill_dest
    
    # Auto-configure opencode.json
    config_file = opencode_config_dir/"opencode.json"
    if config_file.exist?
      begin
        config = JSON.parse(config_file.read)
        plugins = config["plugin"] || []
        
        # Add plugin if not already present
        unless plugins.any? { |p| p.include?("plugins/ocdc") }
          plugins << plugin_path
          config["plugin"] = plugins
          config_file.write(JSON.pretty_generate(config))
        end
      rescue JSON::ParserError
        # If JSON is invalid, don't modify it
        opoo "Could not parse opencode.json, skipping plugin configuration"
      end
    else
      # Create minimal config with plugin
      opencode_config_dir.mkpath
      config = { "plugin" => [plugin_path] }
      config_file.write(JSON.pretty_generate(config))
    end
  end

  def caveats
    <<~EOS
            ⚡
        ___  ___ ___  ___ 
       / _ \\/ __/ _ \\/ __|
      | (_) | (_| (_) | (__ 
       \\___/ \\___\\___/ \\___|
            ⚡

      Requires: npm install -g @devcontainers/cli

      Plugin installed to: ~/.config/opencode/plugins/ocdc/
      Skill linked to: ~/.config/opencode/skill/ocdc/

      Usage:
        ocdc up [branch]   Start devcontainer
        ocdc down          Stop devcontainer  
        ocdc list          List instances
        ocdc exec <cmd>    Execute in container
        ocdc poll          Poll sources for new items
        ocdc               Interactive TUI

      Automatic Polling (optional):
        1. Configure: cp "$(brew --prefix ocdc)/share/ocdc/examples/github-issues.yaml" ~/.config/ocdc/polls/
        2. Start:     brew services start ocdc
        3. Logs:      tail -f "$(brew --prefix)/var/log/ocdc-poll.log"
    EOS
  end

  service do
    run [opt_bin/"ocdc", "poll", "--once"]
    run_type :interval
    interval 300
    keep_alive false
    log_path var/"log/ocdc-poll.log"
    error_log_path var/"log/ocdc-poll.log"
    environment_variables PATH: std_service_path_env,
                          HOME: ENV["HOME"]
  end

  test do
    # Test CLI responds (verifies symlink + relative paths work)
    assert_match "ocdc", shell_output("#{bin}/ocdc --help")
    assert_match version.to_s, shell_output("#{bin}/ocdc version")
    
    # Test subcommands are accessible (verifies lib files found)
    assert_match "Start", shell_output("#{bin}/ocdc up --help")
    assert_match "Stop", shell_output("#{bin}/ocdc down --help")
    assert_match "List", shell_output("#{bin}/ocdc list --help")
    assert_match "Execute", shell_output("#{bin}/ocdc exec --help")
    assert_match "Navigate", shell_output("#{bin}/ocdc go --help")
    assert_match "Poll", shell_output("#{bin}/ocdc poll --help")
    
    # Test plugin command
    assert_match "plugin", shell_output("#{bin}/ocdc plugin --help")
    
    # Test lib files exist
    assert_predicate prefix/"lib/ocdc-up", :exist?
    assert_predicate prefix/"lib/ocdc-down", :exist?
    assert_predicate prefix/"lib/ocdc-list", :exist?
    assert_predicate prefix/"lib/ocdc-exec", :exist?
    assert_predicate prefix/"lib/ocdc-go", :exist?
    assert_predicate prefix/"lib/ocdc-poll", :exist?
    assert_predicate prefix/"lib/ocdc-paths.bash", :exist?
    
    # Test plugin files exist
    assert_predicate prefix/"plugin/index.js", :exist?
    assert_predicate prefix/"plugin/helpers.js", :exist?
    assert_predicate prefix/"plugin/command/ocdc.md", :exist?
    
    # Test skill exists
    assert_predicate prefix/"skill/ocdc/SKILL.md", :exist?
    
    # Test example poll config exists
    assert_predicate prefix/"share/ocdc/examples/github-issues.yaml", :exist?
    
    # Validate JavaScript syntax
    system "node", "--check", prefix/"plugin/index.js"
    system "node", "--check", prefix/"plugin/helpers.js"
  end
end
