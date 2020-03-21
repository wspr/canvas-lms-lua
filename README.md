# Lua interface for the Canvas LMS API

This repository contains a set of Lua interfaces to the Canvas LMS using its REST API.

No claim to being comprehensive is made; functions are added as I need them.


## Installation

After cloning/obtaining the files in this repository, run

    luarocks make

This will theoretically install all dependencies automatically (see the `.rockspec` file
for what these are).

However, this package requires OpenSSL to be installed and that might require additionoal steps.

### macOS

Assuming `lua` installed via HomeBrew, this worked for me:

    brew install lua
    brew install openssl
    luarocks install luasec OPENSSL_DIR=/usr/local/opt/openssl/


## Getting started

Load the module in Lua as normal:

    canvas = require('canvas-lms')

### Configuration

However, just the `require` line above will produce an error; before doing this you must
create a local file `canvas-data.lua` that contains the following lines:

    canvas_url "<URL>/"
    token      "<TOKEN>"
    course_id  "<CID>"
    first_monday { year=YYYY, month=MM, day=DD } -- first monday of week 1
    break_length (M) -- there is a mid-semester break of M weeks long (optional, default = 2)
    break_week   (N) -- the mid-semester break is *after* week N
    cache_dir  "cache/" -- optional, this is the default

This file will be auto-loaded as the module is loaded.

### How to get a Canvas token

(TODO)



## Licence and copyright

Distributed under the terms and conditions of the Apache Licence v2.
Copyright 2020 The University of Adelaide and Will Robertson
