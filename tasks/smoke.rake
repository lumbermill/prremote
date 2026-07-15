# Semi-automated post-release smoke test for physical boards.
#
# Physical devices can't be fully automated, but anything that produces serial
# output (version banner, eval result, WiFi IP, …) can be asserted from the
# host. Visual checks (LCD, LED, buttons) are printed as a manual checklist.
#
#   rake smoke[picow]                         # run the picow checks
#   PORT=/dev/tty.usbmodem101 rake smoke[esp32]
#   SMOKE_WIFI=wk/wifi.rb rake smoke[picow]   # credentialed WiFi script
#   PRREMOTE=prremote rake smoke[pico]        # test an installed gem, not the tree
#
# Each step is one of:
#   :auto    — run the command, PASS/FAIL by matching `expect` (gates exit code)
#   :eyeball — run the command, print its output for a human to confirm ([ ])
#   :manual  — a physical action with no command ([ ])
#
# Mirrors the board × feature matrix in docs/SUPPORT.md — keep them in sync.

require 'open3'

module Smoke # rubocop:disable Metrics/ModuleLength -- cohesive task helper; splitting hurts readability
  SMOKE_BOARDS = %w[pico picow pico2 esp32 esp32c6].freeze

  # In-repo CLI so the smoke test exercises the working tree. Override with
  # PRREMOTE=... to test an installed gem instead.
  BIN = ENV.fetch('PRREMOTE', 'ruby -Ilib bin/prremote')

  # Board → examples/ subdirectory.
  EXAMPLE_DIR = { 'esp32' => 'm5go', 'esp32c6' => 'xiao_c6' }.freeze

  module_function

  def example_dir(board)
    EXAMPLE_DIR.fetch(board, 'pico')
  end

  # --port / --baud from the environment; empty when relying on auto-detect.
  def global_opts
    %w[port baud].filter_map do |key|
      value = ENV.fetch(key.upcase, '')
      "--#{key} #{value}" unless value.empty?
    end.join(' ')
  end

  # examples/*/wifi.rb ship placeholder credentials; point SMOKE_WIFI / SMOKE_NTP
  # at a credentialed copy (e.g. under wk/) so the auto checks can pass.
  def wifi_script(board)
    ENV.fetch('SMOKE_WIFI', "examples/#{example_dir(board)}/wifi.rb")
  end

  def ntp_script(board)
    ENV.fetch('SMOKE_NTP', "examples/#{example_dir(board)}/ntp_clock.rb")
  end

  # How long to let the (infinite) NTP clock stream before stopping it, long
  # enough to see WiFi connect + first sync + a few ticks. Override with
  # SMOKE_NTP_SECONDS.
  def ntp_seconds
    Integer(ENV.fetch('SMOKE_NTP_SECONDS', '25'))
  end

  def auto(desc, cmd, expect)
    { kind: :auto, desc: desc, cmd: cmd, expect: expect }
  end

  # `timeout` (seconds) is for scripts that stream forever (an NTP clock loop):
  # capture their output for that long, then stop them. Omit for scripts that
  # end on their own.
  def eyeball(desc, cmd, timeout: nil)
    { kind: :eyeball, desc: desc, cmd: cmd, timeout: timeout }
  end

  def manual(desc)
    { kind: :manual, desc: desc }
  end

  def common_steps
    [
      auto('version banner reports a runtime', 'version', /^runtime:\s+\d/),
      auto('eval round-trip (6*7)', 'eval "puts 6*7"', /^42\b/)
    ]
  end

  def wired_steps(board)
    [
      eyeball("i2c scan prints addresses (#{board})", "run examples/#{example_dir(board)}/i2c_scan.rb"),
      manual('GPIO: the LED in gpio.rb blinks'),
      manual('GPIO: pressing the button prints "pressed" (within the 5 s window)')
    ]
  end

  def wifi_steps(board)
    [
      auto("wifi connects and prints an IP (#{board})",
           "run #{wifi_script(board)}",
           /Connected!|IP:\s+\d+\.\d+\.\d+\.\d+/)
    ]
  end

  def steps_for(board)
    case board
    when 'pico', 'pico2' then common_steps + wired_steps(board)
    when 'picow'         then picow_steps(board)
    when 'esp32'         then esp32_steps(board)
    when 'esp32c6'       then esp32c6_steps(board)
    end
  end

  def picow_steps(board)
    common_steps + wired_steps(board) + wifi_steps(board) + [
      eyeball('ntp clock prints a synced time', "run #{ntp_script(board)}", timeout: ntp_seconds),
      manual('LED: examples/pico/led.rb blinks the onboard LED')
    ]
  end

  def esp32_steps(board)
    common_steps + wired_steps(board) + wifi_steps(board) + [
      manual('LCD: examples/m5go/lcd_hello.rb shows fill + rects + text, colors correct'),
      manual('LCD: examples/m5go/ntp_clock.rb shows a ticking clock on the panel'),
      manual('Buttons: examples/m5go/buttons.rb reports A/B/C presses')
    ]
  end

  def esp32c6_steps(board)
    common_steps + wifi_steps(board) + [
      manual('GPIO: onboard yellow LED (GPIO15) blinks; button (GPIO2) prints "pressed"'),
      eyeball('i2c scan finds a device on D4/D5 (GPIO22/23)', 'run examples/xiao_c6/i2c_scan.rb'),
      eyeball('ntp clock prints synced JST over serial', "run #{ntp_script(board)}", timeout: ntp_seconds),
      manual('LCD: examples/xiao_c6/lcd_hello.rb (MSP2807) upright 320x240, invert:false madctl:0xE8')
    ]
  end

  def run_cmd(cmd)
    full = [BIN, global_opts, cmd].reject(&:empty?).join(' ')
    out, = Open3.capture2e(full)
    [full, out]
  end

  # `prremote run` only returns when the device prints DONE. Scripts with an
  # infinite loop (e.g. ntp_clock.rb, which ticks forever) never send it, so a
  # plain capture blocks indefinitely. Capture output for `seconds`, then SIGINT
  # the process group: run.rb catches Interrupt, sends the device \x03 to stop
  # it, and exits. Returns whatever was printed, minus the interrupt backtrace.
  def run_cmd_timed(cmd, seconds)
    full = [BIN, global_opts, cmd].reject(&:empty?).join(' ')
    buf = +''
    Open3.popen2e(full, pgroup: true) do |_stdin, out, wait_thr|
      reader = Thread.new { out.each_line { |line| buf << line } }
      interrupt_group(wait_thr.pid) if reader.join(seconds).nil?
      reader.join
      wait_thr.value
    end
    [full, strip_interrupt_noise(buf)]
  end

  def interrupt_group(pid)
    Process.kill('INT', -Process.getpgid(pid))
  rescue Errno::ESRCH, Errno::EPERM
    nil
  end

  # Drop the trailing Ruby interrupt backtrace left by the SIGINT so the
  # eyeball output shows only the device's own lines.
  def strip_interrupt_noise(out)
    lines = out.lines
    lines.pop while lines.last&.match?(%r{Interrupt\b|^\s+from |:\d+:in |bin/prremote|lib/prremote})
    lines.join
  end

  def run_eyeball(step, manual)
    full, out = step[:timeout] ? run_cmd_timed(step[:cmd], step[:timeout]) : run_cmd(step[:cmd])
    puts "• #{step[:desc]}"
    puts "    $ #{full}"
    out.each_line { |line| puts "    | #{line.chomp}" }
    puts "    (stopped after #{step[:timeout]}s — this script loops forever)" if step[:timeout]
    manual << "confirm the output above — #{step[:desc]}"
  end

  def run_auto(step)
    _full, out = run_cmd(step[:cmd])
    ok = step[:expect].match?(out)
    puts "#{ok ? 'PASS' : 'FAIL'}  #{step[:desc]}"
    return 0 if ok

    puts "      expected /#{step[:expect].source}/, last lines:"
    out.lines.last(4).each { |line| puts "      | #{line.chomp}" }
    1
  end

  # Runs one step; returns the number of auto failures it produced (0 or 1).
  def run_step(step, manual)
    case step[:kind]
    when :manual
      manual << step[:desc]
      0
    when :eyeball
      run_eyeball(step, manual)
      0
    when :auto
      run_auto(step)
    else
      0
    end
  end

  def header(board)
    opts = global_opts
    puts "== prremote smoke: #{board} =="
    puts "   bin: #{[BIN, opts.empty? ? '(auto-detect port)' : opts].join(' ')}"
    puts
  end

  def footer(manual, failures)
    unless manual.empty?
      puts
      puts '-- manual checks (human / 目視) --'
      manual.each { |desc| puts "  [ ] #{desc}" }
    end
    puts
    abort "auto checks: #{failures} FAILED" unless failures.zero?
    puts 'auto checks: all passed'
  end

  def run(board)
    steps = steps_for(board)
    abort "Usage: rake smoke[BOARD]  (one of: #{SMOKE_BOARDS.join(', ')})" unless steps

    header(board)
    manual = []
    failures = steps.sum { |step| run_step(step, manual) }
    footer(manual, failures)
  end
end

desc "Semi-auto smoke test on a connected device (boards: #{Smoke::SMOKE_BOARDS.join(', ')})"
task :smoke, [:board] do |_t, args|
  Smoke.run(args[:board])
end
