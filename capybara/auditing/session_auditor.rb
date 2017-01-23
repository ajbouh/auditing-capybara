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

require_relative 'network_traffic_auditor'

class Auditing::SessionAuditor
  def initialize(session:, file_path_proc:, emit_sample:)
    @session = session
    @file_path_proc = file_path_proc
    @network_traffic_auditor = Auditing::NetworkTrafficAuditor.new(session: session)
    @emit_sample = emit_sample
  end

  def sample(event:, node:, more:)
    now = Time.now.utc
    suffix = "#{event}.png"
    src = @file_path_proc.(suffix: suffix, time: now)
    @session.save_screenshot(src, full: true)

    driver = @session.driver

    body = body_size(driver)
    snapshot = {
      "event" => event,
      "eventArgs" => more,
      "timestamp" => Auditing.format_time(now),
      "src" => File.basename(src),
      "width" => body["width"],
      "height" => body["height"],
      "node" => node ? node_client_bounds(driver, node) : nil,
      "nodePath" => node ? node_path(driver, node) : nil,
      "networkRequests" => @network_traffic_auditor.sample
    }
    @emit_sample.(snapshot)

    nil
  end

  private

  def body_size(driver)
    driver.evaluate_script(<<-EOF)
(function() {
var body = document.body,
    html = document.documentElement;

var height = Math.max(
    body.scrollHeight, body.offsetHeight,
    html.clientHeight, html.scrollHeight, html.offsetHeight );

var width = Math.max(
    body.scrollWidth, body.offsetWidth,
    html.clientWidth, html.scrollWidth, html.offsetWidth);

return {
  width: width,
  height: height
};
})();
    EOF
  end

  # /*
  #  * Copyright (C) 2016 Adam Bouhenguel
  #  * Copyright (C) 2015 Pavel Savshenko
  #  * Copyright (C) 2011 Google Inc.  All rights reserved.
  #  * Copyright (C) 2007, 2008 Apple Inc.  All rights reserved.
  #  * Copyright (C) 2008 Matt Lilek <webkit@mattlilek.com>
  #  * Copyright (C) 2009 Joseph Pecoraro
  #  *
  #  * Redistribution and use in source and binary forms, with or without
  #  * modification, are permitted provided that the following conditions
  #  * are met:
  #  *
  #  * 1.  Redistributions of source code must retain the above copyright
  #  *     notice, this list of conditions and the following disclaimer.
  #  * 2.  Redistributions in binary form must reproduce the above copyright
  #  *     notice, this list of conditions and the following disclaimer in the
  #  *     documentation and/or other materials provided with the distribution.
  #  * 3.  Neither the name of Apple Computer, Inc. ("Apple") nor the names of
  #  *     its contributors may be used to endorse or promote products derived
  #  *     from this software without specific prior written permission.
  #  *
  #  * THIS SOFTWARE IS PROVIDED BY APPLE AND ITS CONTRIBUTORS "AS IS" AND ANY
  #  * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
  #  * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
  #  * DISCLAIMED. IN NO EVENT SHALL APPLE OR ITS CONTRIBUTORS BE LIABLE FOR ANY
  #  * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
  #  * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
  #  * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
  #  * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
  #  * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
  #  * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
  #  */

  def node_path(driver, node)
    path = node.path
    driver.evaluate_script(<<-EOF)
(function() {
/**
 * @constructor
 * @param {string} value
 * @param {boolean} optimized
 */
var DOMNodePathStep = function(value, optimized) {
  this.value = value;
  this.optimized = optimized || false;
};

DOMNodePathStep.prototype = {
  /**
   * @return {string}
   */
  toString: function()
  {
    return this.value;
  }
};

var _cssPathStep = function(node, optimized, isTargetNode) {
  if (node.nodeType !== Node.ELEMENT_NODE)
    return null;

  var id = node.getAttribute("id");
  if (optimized) {
    if (id)
      return new DOMNodePathStep(idSelector(id), true);
    var nodeNameLower = node.nodeName.toLowerCase();
    if (nodeNameLower === "body" || nodeNameLower === "head" || nodeNameLower === "html")
      return new DOMNodePathStep(node.nodeName.toLowerCase(), true);
  }
  var nodeName = node.nodeName.toLowerCase();

  if (id)
    return new DOMNodePathStep(nodeName.toLowerCase() + idSelector(id), true);
  var parent = node.parentNode;
  if (!parent || parent.nodeType === Node.DOCUMENT_NODE)
    return new DOMNodePathStep(nodeName.toLowerCase(), true);

  /**
   * @param {DOMNode} node
   * @return {Array.<string>}
   */
  function prefixedElementClassNames(node)
  {
    var classAttribute = node.getAttribute("class");
    if (!classAttribute)
      return [];

    return classAttribute.split(/\\s+/g).filter(Boolean).map(function(name) {
      // The prefix is required to store "__proto__" in a object-based map.
      return "$" + name;
    });
   }

  /**
   * @param {string} id
   * @return {string}
   */
  function idSelector(id)
  {
    return "#" + escapeIdentifierIfNeeded(id);
  }

  /**
   * @param {string} ident
   * @return {string}
   */
  function escapeIdentifierIfNeeded(ident)
  {
    if (isCSSIdentifier(ident))
      return ident;
    var shouldEscapeFirst = /^(?:[0-9]|-[0-9-]?)/.test(ident);
    var lastIndex = ident.length - 1;
    return ident.replace(/./g, function(c, i) {
      return ((shouldEscapeFirst && i === 0) || !isCSSIdentChar(c)) ? escapeAsciiChar(c, i === lastIndex) : c;
    });
  }

  /**
   * @param {string} c
   * @param {boolean} isLast
   * @return {string}
   */
  function escapeAsciiChar(c, isLast)
  {
    return "\\\\" + toHexByte(c) + (isLast ? "" : " ");
  }

  /**
   * @param {string} c
   */
  function toHexByte(c)
  {
    var hexByte = c.charCodeAt(0).toString(16);
    if (hexByte.length === 1)
      hexByte = "0" + hexByte;
    return hexByte;
  }

  /**
   * @param {string} c
   * @return {boolean}
   */
  function isCSSIdentChar(c)
  {
    if (/[a-zA-Z0-9_-]/.test(c))
      return true;
    return c.charCodeAt(0) >= 0xA0;
  }

  /**
   * @param {string} value
   * @return {boolean}
   */
  function isCSSIdentifier(value)
  {
    return /^-?[a-zA-Z_][a-zA-Z0-9_-]*$/.test(value);
  }

  var prefixedOwnClassNamesArray = prefixedElementClassNames(node);
  var needsClassNames = false;
  var needsNthChild = false;
  var ownIndex = -1;
  var siblings = parent.children;
  for (var i = 0; (ownIndex === -1 || !needsNthChild) && i < siblings.length; ++i) {
    var sibling = siblings[i];
    if (sibling === node) {
      ownIndex = i;
      continue;
    }
    if (needsNthChild)
      continue;
    if (sibling.nodeName.toLowerCase() !== nodeName.toLowerCase())
      continue;

    needsClassNames = true;
    var ownClassNames = prefixedOwnClassNamesArray;
    var ownClassNameCount = 0;
    for (var name in ownClassNames)
      ++ownClassNameCount;
    if (ownClassNameCount === 0) {
      needsNthChild = true;
      continue;
    }
    var siblingClassNamesArray = prefixedElementClassNames(sibling);
    for (var j = 0; j < siblingClassNamesArray.length; ++j) {
      var siblingClass = siblingClassNamesArray[j];
      if (ownClassNames.indexOf(siblingClass))
        continue;
      delete ownClassNames[siblingClass];
      if (!--ownClassNameCount) {
        needsNthChild = true;
        break;
      }
    }
  }

  var result = nodeName.toLowerCase();
  if (isTargetNode && nodeName.toLowerCase() === "input" && node.getAttribute("type") && !node.getAttribute("id") && !node.getAttribute("class"))
    result += "[type=\\"" + node.getAttribute("type") + "\\"]";
  if (needsNthChild) {
    result += ":nth-child(" + (ownIndex + 1) + ")";
  } else if (needsClassNames) {
    for (var prefixedName in prefixedOwnClassNamesArray)
    // for (var prefixedName in prefixedOwnClassNamesArray.keySet())
      result += "." + escapeIdentifierIfNeeded(prefixedOwnClassNamesArray[prefixedName].substr(1));
  }

  return new DOMNodePathStep(result, false);
};

var cssPath = function(node, optimized) {
  if (node.nodeType !== Node.ELEMENT_NODE)
    return "";
  var steps = [];
  var contextNode = node;
  while (contextNode) {
    var step = _cssPathStep(contextNode, !!optimized, contextNode === node);
    if (!step)
      break; // Error - bail out early.
    steps.push(step);
    if (step.optimized)
      break;
    contextNode = contextNode.parentNode;
  }
  steps.reverse();
  return steps.join(" > ");
};

var path = '#{path}';
var result = document.evaluate(path, document, null, XPathResult.FIRST_ORDERED_NODE_TYPE, null);
var node = result.singleNodeValue;
return cssPath(node);
})();
    EOF
  end

  def node_client_bounds(driver, node)
    path = node.path
    driver.evaluate_script(<<-EOF)
(function() {
var path = '#{path}';
var result = document.evaluate(path, document, null, XPathResult.FIRST_ORDERED_NODE_TYPE, null);
var node = result.singleNodeValue;
var bodyBounds = document.body.getBoundingClientRect();
var bounds = node.getBoundingClientRect();

return {
  top: bounds.top - bodyBounds.top,
  left: bounds.left - bodyBounds.left,
  width: bounds.width,
  height: bounds.height
};
})();
    EOF
  end
end
