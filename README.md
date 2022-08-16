# Lua interface for the Canvas LMS API

This repository contains a set of Lua interfaces to the Canvas LMS using its REST API.

- This is the main repository README.
- API documentation is located here: <https://wspr.io/canvas-lms-lua>.

These Lua interfaces are not an ‘application’ in the sense that on their own they will
not do anything. They are provided for individual users to chain together commands for
controlling their own Canvas courses.

No claim to being comprehensive is made; functions are added as I need them.

Please note that using this code could potentially destroy data that you are using for teaching.
Be very careful to test in a sandbox before deploying such code! No warranties, etc.


## Installation

After cloning/obtaining the files in this repository, run

    luarocks make

This will theoretically install all dependencies automatically (see the `.rockspec` file
for what these are).

However, this package requires OpenSSL to be installed and that might require additionoal steps.

### macOS

Using [HomeBrew](https://brew.sh), this worked for me:

    brew install lua
    brew install openssl
    luarocks install luasec OPENSSL_DIR=/opt/homebrew/opt/openssl


## Getting started

Load the module in Lua as normal:

    canvas = require('canvas-lms')

### Configuration

However, just the `require` line above will produce an error; before doing this you must
create a local file `canvas-config.lua` that contains the following lines:

    canvas_url "<URL>/"
    token      "<TOKEN>"
    course_id  "<CID>"
    first_monday { year=YYYY, month=MM, day=DD } -- first monday of week 1
    break_length (M) -- there is a mid-semester break of M weeks long (optional, default = 2)
    break_week   (N) -- the mid-semester break is *after* week N
    cache_dir  "cache/" -- optional, this is the default

This file will be auto-loaded as the module is loaded.

### Obtaining an access token

From the Canvas developer documenation:

> The simplest option is to generate an access token on your user's profile page.
> Note that asking any other user to manually generate a token and enter it into your
> application is a violation of Canvas' terms of service.
> Applications in use by multiple users MUST use OAuth to obtain tokens.
>
> To manually generate a token for testing:
>
> 1. Click the "profile" link in the top right menu bar, or navigate to /profile
> 2. Under the "Approved Integrations" section, click the button to generate a new access token.
> 3. Once the token is generated, you cannot view it again, and you'll have to generate a new token if you forget it. Remember that access tokens are password equivalent, so keep it secret.

I have quoted the text around OAuth to emphasise that this repository does not provide
an ‘application’ for Canvas. When using the Lua interfaces in this repoository you are
writing your own custom applications for your own sole use.

Currently the Lua interfaces do not provide a means to connect via OAuth but with time permitting
I would like to add somoething. (Doing it cross-platform could be tricky?)

## Developer details

(I.e., notes to myself.)

### Documentation

Uses `ldoc`, automated deployment using a Github Action.

### Code checking

* Automated checking with `luacheck` using Github Action.
* `luacheck lua` in the top directory to run manually.


## Licence and copyright

Distributed under the terms and conditions of the Apache Licence v2.
Copyright 2020 The University of Adelaide and Will Robertson
