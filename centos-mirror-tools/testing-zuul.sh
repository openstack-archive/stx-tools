#!/bin/bash

# Creating the docker image

if ! docker build -t stx-mirror -f Dockerfile .; then
    echo "Cannot create image"
    exit 1
fi

echo "Done :)"
