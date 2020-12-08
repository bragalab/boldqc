#!/bin/bash

key="$1"

case $key in
    -b|--boldqcimg)
    IMG="$2"
    shift # past argument
    ;;
    *)
        echo "first argument must be -b <boldqc.img>"
    ;;
esac
shift # past argument or value

if [ ! "$IMG" ]; then
  echo "-b <singularity image>.img argument required!"
fi

singularity exec --bind /ncf:/ncf $IMG extqc.py $@
