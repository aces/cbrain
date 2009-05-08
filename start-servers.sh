#!/bin/bash

cd BrainPortal || exit 20
script/server -p 3000 &

cd ../Bourreau || exit 20
script/server -p 3050 &

