#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

declare -r DIR="$HOME/Some/Dir"

TransformImage.sh  --crop "600L,500R,600T,1100B"  --xres 1024 -- "$DIR/Picture1.jpg"
TransformImage.sh  --crop "600L,500R,600T,1100B"              -- "$DIR/Picture2.jpg"
TransformImage.sh                                 --xres 1024 -- "$DIR/Picture3.jpg"
