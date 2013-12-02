#!/bin/sh

/usr/local/bin/pandoc -i -s slides.md -t revealjs --template template.revealjs -o index.html
