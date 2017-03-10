
#
# CBRAIN Project
#
# Copyright (C) 2008-2012
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

to_extend  = [ ViewHelpers ] rescue [] # list of modules to extend into the console; empty on Bourreau console.
to_extend |= ActionView::Base.included_modules
to_extend |= Dir.glob("app/helpers/*").map { |p| p.sub(/^.*\//,"").sub(/.rb$/,"").classify.constantize }
to_extend.select { |m| m != Kernel }.each do |m|
   self.extend m rescue nil
end
include Rails.application.routes.url_helpers # for userfile_path(3) etc

(CbrainConsoleFeatures ||= []) << <<FEATURES
========================================================
Feature: shortcuts to view helpers
========================================================
  Invoke these directly: h("jack&jill"), model_path(),
  pretty_size(1234567), etc.
  Other view helpers: helper.helper_method(args)
FEATURES

