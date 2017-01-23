# auditing-capybara

This project generates an overview of your application's functionality by auditing your existing tests. It includes a single page JavaScript/HTML viewer to quickly replay your user experience.

NOTE This is a side project that was developed very quickly to satisfy my needs on another project. Initial feedback indicates that others may find it useful, so I've posted it essentially as is. If there's sufficient interest, I'll package this into a Ruby gem and make it easier to use.

## Getting started

Assuming you're using Capybara, Poltergeist, and RSpec, copy the `capybara/` folder to `spec/support/` and add the following to your `spec/support/capybara.rb` file (or equivalent). If you're using anything other than the above, you'll need to adapt the code below and the implementation files in the `capybara/` folder accordingly.

```ruby
# Add more devices here...
DEVICE_CONFIGS = {
  desktop: {
    label: "Desktop",
    width: 1024,
    height: 768,
    extensions: [
      # Files that should be loaded here
    ],
  },
  iphone_5: {
    label: "iPhone 5",
    width: 320,
    height: 568,
    user_agent: 'Mozilla/5.0 (iPhone; U; CPU iPhone OS 5_0 like Mac OS X) AppleWebKit/534.46 (KHTML, like Gecko) Mobile/9A334 Safari/7534.48.3',
    extensions: [
      # Files that should be loaded here
    ],
  },
}

require 'fileutils'
require_relative 'capybara/auditing'

RSpec.configure do |config|
  start_time = Time.now
  generation = start_time.to_i.to_s(36)

  path_proc = ->(*fragments) do
    dir = ENV.fetch('CIRCLE_ARTIFACTS',
        File.expand_path("../../tmp/capybara/gen_#{generation}", __FILE__))

    FileUtils.mkdir_p(dir)
    File.join(dir, *fragments)
  end

  suite_auditor = ::Auditing::SuiteAuditor.new

  config.before(:suite) do
    dst = path_proc.()

    Dir[File.expand_path('../capybara/auditing/assets/*', __FILE__)].each do |asset|
      FileUtils.cp_r(asset, dst)
    end
  end

  config.after(:suite) do
    suite_auditor.flush(path_proc.('index.json'))
  end

  config.before(:example) do |example|
    ::Auditing.capybara_test_auditor = nil
  end

  config.before(:example, js: true) do |example|
    next unless current_session = Capybara.current_session
    next unless device = example.metadata[:device]
    next unless device_config = DEVICE_CONFIGS.fetch(device)

    driver = current_session.driver
    current_session.current_window.resize_to(
        device_config[:width],
        device_config[:height])

    if Capybara.javascript_driver == :poltergeist
      # NOTE(adamb) Not all drivers use this technique to set headers.
      driver.headers = {'User-Agent' => device_config[:user_agent]}

      current_session.driver.browser.extensions = []
      if current_extensions = device_config[:extensions]
        current_session.driver.browser.extensions = current_extensions
      end
    end

    test_file_counter = 0
    example_basename = File.basename(example.metadata[:file_path])
    example_line = example.metadata[:line_number]

    label_fragments = []
    ::RSpec::Core::Metadata.ascending(example.metadata) do |meta|
      label_fragments.unshift(meta[:description])
    end

    ::Auditing.capybara_test_auditor = suite_auditor.create_test_auditor(
        label: label_fragments.join(" \u25b8 "),
        file: example_basename,
        line: example_line,
        time: start_time,
        file_path_proc: ->(suffix:, time:) do
          timestamp = "#{time.strftime('%Y_%m_%d-T%H_%M_%S.')}#{'%03d' % (time.usec/1000).to_i}"
          basename = [
            example_basename,       # So you can figure out which file it came from
            "line_#{example_line}", # and which line to look at
            '%02d' % test_file_counter,       # Different runs can be compared by matching up test_file_counter
            timestamp,              # Correlate these timestamps those in to logs
            suffix,
          ].join("-")

          test_file_counter += 1

          path_proc.(basename)
        end)

    ::Auditing.define_capybara_session_auditor(
        device_label: device_config[:label],
        session: current_session)
  end

  config.prepend_after(:example, js: true) do |example|
    if example.exception
      ::Auditing.capybara_test_auditor.emit_outcome("error") if ::Auditing.capybara_test_auditor
      next unless session = Capybara.current_session

      ::Auditing.capybara_session_screenshot(session, "post-failure")
    else
      ::Auditing.capybara_test_auditor.emit_outcome("pass") if ::Auditing.capybara_test_auditor
    end
  end
end
```

Then run your tests like you normally would.

Start a webserver in `$PROJECT/tmp/capybara` and navigate to the appropriate `overview.html`. If you're using CircleCI, the artifact should automatically be put in the proper place.

NOTE creation of the index.json file doesn't tolerate parallel test execution well. This may or may not be addressed by future work.
