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

class Auditing::NetworkTrafficAuditor
  def initialize(session:)
    @previous_request_count = 0
    @session = session
  end

  def sample
    network_traffic = @session.driver.network_traffic
    recent_traffic = network_traffic[@previous_request_count..-1].map do |req|
      {
        "error" => req.error,
        "headers" => req.headers,
        "method" => req.method,
        "responseParts" => req.response_parts.map do |res|
          {
            "bodySize" => res.body_size,
            "contentType" => res.content_type,
            "headers" => res.headers,
            "redirectUrl" => res.redirect_url,
            "status" => res.status,
            "statusText" => res.status_text,
            "time" => res.time,
            "url" => res.url,
          }
        end,
        "time" => req.time,
        "url" => req.url,
      }
    end

    @previous_request_count = network_traffic.length

    recent_traffic
  end
end
