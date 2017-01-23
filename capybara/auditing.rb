# MIT License
#
# Copyright (c) 2017 Adam Bouhenguel
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

# Trap visit and click, emitting screenshots of them as files
module Auditing
  module_function

  def format_time(time)
    time.utc.strftime("%FT%H:%M:%S.%3NZ")
  end

  require_relative 'auditing/network_traffic_auditor'
  require_relative 'auditing/session_auditor'
  require_relative 'auditing/test_auditor'
  require_relative 'auditing/suite_auditor'
  require_relative 'auditing/poltergeist_node_auditor'

  @@capybara_test_auditor = nil
  def capybara_test_auditor=(test_auditor)
    @@capybara_test_auditor = test_auditor
  end

  def define_capybara_session_auditor(*args)
    @@capybara_test_auditor.define_session_auditor(*args)
  end

  def capybara_test_auditor
    @@capybara_test_auditor
  end

  def capybara_session_screenshot(session, event, node=nil, more=nil)
    return unless @@capybara_test_auditor

    session_auditor = @@capybara_test_auditor.session_auditor_for(session)
    session_auditor.sample(event: event, node: node, more: more)
  end

  module CapybaraAuditSessionMixin
    def visit(*args)
      result = super

      ::Auditing.capybara_session_screenshot(self, "visit", nil, uri: args[0])

      result
    end
  end
  ::Capybara::Session.class_eval do
    prepend CapybaraAuditSessionMixin
  end
end
