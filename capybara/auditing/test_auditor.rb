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

require_relative 'session_auditor'

class Auditing::TestAuditor
  def initialize(emit_session:, emit_outcome:, file_path_proc:)
    @emit_session = emit_session
    @emit_outcome = emit_outcome
    @file_path_proc = file_path_proc

    @session_auditors = {}
  end

  def define_session_auditor(device_label:, session:)
    auditor = create_session_auditor(
        session: session,
        device_label: device_label)
    @session_auditors[session] = auditor

    auditor
  end

  def session_auditor_for(session)
    @session_auditors[session] ||
        define_session_auditor(
            device_label: "Custom",
            session: session)
  end

  def emit_outcome(outcome)
    @emit_outcome.(outcome)
  end

  private

  def create_session_auditor(session:, device_label:)
    width, height = session.current_window.size

    snapshots = []
    session_audit = {
      "deviceLabel" => device_label,
      "width" => width,
      "height" => height,
      "snapshots" => snapshots
    }
    @emit_session.(session_audit)

    Auditing::SessionAuditor.new(
        session: session,
        file_path_proc: @file_path_proc,
        emit_sample: ->(snapshot) do
          snapshots.push(snapshot)
        end)
  end
end
