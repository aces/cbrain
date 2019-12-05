
#
# CBRAIN Project
#
# Copyright (C) 2008-2019
# The Royal Institution for the Advancement of Learning
# McGill University
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

# Helper methods for zenodo publishing stuff
module ZenodoHelper

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  ZenodoSandboxDOIPrefix = "10.5072/"
  ZenodoMainDOIPrefix    = "10.5281/"

  # Creates a pretty link to a DOI, usually for Zenodo
  def link_to_zenodo_doi(doi)
    link_to "<img src=\"https://zenodo.org/badge/DOI/#{doi}.svg\" alt=\"DOI\">".html_safe,
            "https://doi.org/#{doi}", :target => '_blank'
  end

  # Creates a pretty link to zenodo deposit, by ID. The
  # +depid+ parameter is like in url_for_deposit().
  def link_to_deposit(depid)
    zsite, id = depid.split("-")
    label  = "Deposit ##{id}"
    label += " (sandbox)" if zsite == 'sandbox'
    link_to label, url_for_deposit(depid), :target => '_blank'
  end

  # Returns the URL for a zenodo deposit, by ID. The
  # +depid+ parameter is expected to be in the format
  # "main-1234" or "sandbox-1234"
  def url_for_deposit(depid)
    if depid.to_s.starts_with?("sandbox-")
      url_for_sandbox_deposit(depid.to_s.sub("sandbox-",""))
    else
      url_for_main_deposit(depid.to_s.sub("main-",   ""))
    end
  end

  def url_for_sandbox_deposit(depid) #:nodoc:
    "https://sandbox.zenodo.org/deposit/#{depid}"
  end

  def url_for_main_deposit(depid) #:nodoc:
    "https://zenodo.org/deposit/#{depid}"
  end

  def green_checkmark_icon #:nodoc:
    "<span class=\"green_checkmark_icon\">&#10004;</span>".html_safe
  end

  def red_x_cross_icon #:nodoc:
    "<span class=\"red_x_cross_icon\">&#10060;</span>".html_safe
  end

  def orange_uparrow_icon #:nodoc:
    "<span class=\"orange_uparrow_icon\">&uarr;</span>".html_safe
  end

end

