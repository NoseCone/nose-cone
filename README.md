# Nose Cone

**Nose Cone** is a web app front end for flare-timing. As well as presenting
comp results it helps making visual checks and comparisons with expected or
official results. It is possible to publish the data alongside this web app
standalone as done at [flaretiming, the web site](https://flaretiming.com).

## Usage

To get the backend server for hosting the comp data running locally:

Start the
[`ft-comp-serve`](https://github.com/GlideAngle/flare-timing/tree/main/lang-haskell/app-serve)
server.  

To host the frontend web app for the comp locally:

1. Open a try-reflex shell with:
    `> reflex-platform/try-reflex`
2. Build the frontend and start its webpack dev server with:
    `> ./stack-shake-build.sh view-start-ghcjs`
3. Open a browser at the hosted URL, usually http://localhost:9000/app.html.

## License

```
Copyright © Phil de Joux 2017-2020
Copyright © Block Scope Limited 2017-2020
```

This software is subject to the terms of the Mozilla Public License, v2.0. If
a copy of the MPL was not distributed with this file, you can obtain one at
http://mozilla.org/MPL/2.0/.
