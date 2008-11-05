#!/bin/bash

cd BrainPortal 
script/server -p 3000 &

cd ../jiv
script/server -p 2000 &

cd ../Bourreau 
script/server -p 2500 &

cd ../FileShuttle
script/server -p 3500 &
