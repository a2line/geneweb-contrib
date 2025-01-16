#!/bin/bash

./rapport.sh "$1" | sed 's/\\n/\n/g'
