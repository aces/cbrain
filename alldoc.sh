#!/bin/sh

echo "This script will generate or refresh a local directory"
echo "of HTML pages containing the CBRAIN APIs."
echo ""

if test ! -d BrainPortal ; then
  echo "Please run this script in the directory above BrainPortal and Bourreau."
  exit 10
fi

echo "Generating BrainPortal HTML documentation..."
cd BrainPortal || exit 20
rake doc:brainportal 2>&1 | sed -e 's/^/-> /'
cd ..
echo ""

echo "Generating Bourreau HTML documentation..."
cd Bourreau || exit 20
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
