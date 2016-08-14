#!/bin/sh

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

# ---------------------------------------------
# CBRAIN Local Documentation Generator
# By Pierre Rioux
# ---------------------------------------------

echo "This script will generate or refresh a local directory"
echo "of HTML pages describing the CBRAIN APIs."
echo ""

if test ! -d BrainPortal ; then
  echo "Please run this script in the CBRAIN root directory, the one containing 'BrainPortal/' and 'Bourreau/'."
  exit 10
fi

echo "Generating BrainPortal HTML documentation..."
cd BrainPortal || exit 20
bundle install >/dev/null 2>/dev/null
rake doc:brainportal 2>&1 | sed -e 's/^/-> /'
cd ..
echo ""

echo "Generating Bourreau HTML documentation..."
cd Bourreau || exit 20
bundle install >/dev/null 2>/dev/null
rake doc:bourreau 2>&1 | sed -e 's/^/-> /'
cd ..

echo ""
echo "You can now access the HTML documentation pages locally"
echo "using your web browser:"
echo ""
echo "BrainPortal APIs:"
echo ""
echo "    file://$PWD/BrainPortal/doc/brainportal/index.html"
echo ""
echo "Bourreau    APIs:"
echo ""
echo "    file://$PWD/Bourreau/doc/bourreau/index.html"
echo ""
