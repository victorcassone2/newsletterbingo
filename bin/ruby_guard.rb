# Re-execs the current binstub under the project's Homebrew Ruby (3.3.x) when
# the shell resolved an incompatible Ruby first — e.g. rvm's Ruby 3.0 shadowing
# it on dev machines. No-op in production/Docker, where the path doesn't exist.
homebrew_ruby = "/usr/local/opt/ruby/bin/ruby"

if !RUBY_VERSION.start_with?("3.3.") && File.executable?(homebrew_ruby)
  ENV.delete("GEM_HOME")
  ENV.delete("GEM_PATH")
  ENV["PATH"] = "/usr/local/opt/ruby/bin:/usr/local/lib/ruby/gems/3.3.0/bin:#{ENV["PATH"]}"
  exec(homebrew_ruby, $PROGRAM_NAME, *ARGV)
end
