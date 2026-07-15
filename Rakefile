require 'rake/testtask'
require 'rubygems/package_task'

spec = Gem::Specification.load('prremote.gemspec')
Gem::PackageTask.new(spec) { |_pkg| } # rubocop:disable Lint/EmptyBlock

# Additional tasks (rake smoke[BOARD], …).
Dir.glob('tasks/*.rake').each { |f| load f }

Rake::TestTask.new(:test) do |t|
  t.libs << 'lib' << 'test'
  t.test_files = FileList['test/**/*_test.rb'].exclude('test/integration_test.rb')
  t.verbose = false
end

Rake::TestTask.new(:integration) do |t|
  t.libs << 'lib' << 'test'
  t.test_files = FileList['test/integration_test.rb']
  t.verbose = false
end

task default: :test

task :setup do
  hook = '.git/hooks/pre-push'
  File.write(hook, <<~SH)
    #!/bin/sh
    set -e
    echo '→ bundle install'
    bundle install --quiet
    if ! git diff --exit-code Gemfile.lock > /dev/null 2>&1; then
      echo 'Gemfile.lock was updated. Commit it before pushing:'
      echo '  git add Gemfile.lock && git commit -m "Update Gemfile.lock"'
      exit 1
    fi
    echo '→ rubocop'
    bundle exec rubocop
    echo '→ wifi credential check'
    # Catches SSID/PASSWORD and prefixed forms like WIFI_SSID/WIFI_PASS; only
    # the placeholders My(SSID|Password) are allowed. Use `rake wk:sync` to get
    # credentialed copies under wk/ instead of editing the tracked samples.
    bad=$(git grep -hE '^[A-Z_]*(SSID|PASS(WORD)?) *=' HEAD -- examples | grep -vE 'My(SSID|Password)' || true)
    if [ -n "$bad" ]; then
      echo 'Non-placeholder WiFi credentials committed in examples/:'
      echo "$bad"
      echo 'Replace with the "MySSID" / "MyPassword" placeholders before pushing.'
      exit 1
    fi
  SH
  File.chmod(0o755, hook)
  puts 'Installed .git/hooks/pre-push'
end
