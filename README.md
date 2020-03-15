# Lua interface for the Canvas LMS API

This repository contains a set of Lua interfaces to the Canvas LMS using its REST API.

No claim to being comprehensive is made; functions are added as I need them.


## Installation

After cloning/obtaining the files in this repository, run

    luarocks make

This will theoretically install all dependencies automatically (see the `.rockspec` file
for what these are).

However, this requires OpenSSL to be installed and this might require additionoal steps.

### macOS

Assuming `lua` installed via HomeBrew, this worked for me:

    brew install lua
    brew install openssl
    luarocks install luasec OPENSSL_DIR=/usr/local/opt/openssl/


## Getting started

Load the moodule as normal:

    canvas = require('canvas-lms')

However, before doing this you must create a local file `canvas-data.lua` that contains
the following lines:

    canvas:set_url        "<URL>/"
    canvas:set_token      "<TOKEN>"
    canvas:set_course_id  "<CID>"

This file will be auto-loaded as the module is loaded.

### How to get a Canvas token

(TODO)
