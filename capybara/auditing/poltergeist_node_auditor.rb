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

module Auditing::CapybaraAuditNodeElementMixin
  def command(name, *args)
    result = super

    case name
    when :select_file
      ::Auditing.capybara_session_screenshot(Capybara.current_session, "select file", self)
    when :set
      ::Auditing.capybara_session_screenshot(Capybara.current_session, "set", self)
    end

    result
  end

  def trigger(event)
    ::Auditing.capybara_session_screenshot(Capybara.current_session, event, self)

    super
  end

  [
    :click,
    :right_click,
    :double_click,
    :trigger,
  ].each do |name|
    define_method(name) do |*args, &b|
      ::Auditing.capybara_session_screenshot(Capybara.current_session, name.to_s, self)

      super(*args, &b)
    end
  end

  [
    :select_option,
    :unselect_option,
    :hover,
    :drag_to,
    :drag_by,
    :send_keys,
  ].each do |name|
    define_method(name) do |*args, &b|
      result = super(*args, &b)
      ::Auditing.capybara_session_screenshot(Capybara.current_session, name.to_s, self)

      result
    end
  end
end
::Capybara::Poltergeist::Node.class_eval do
  prepend Auditing::CapybaraAuditNodeElementMixin
end
