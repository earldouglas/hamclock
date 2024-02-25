# HamClock

This repository is a fork of the archive available from the author at
<https://www.clearskyinstitute.com/ham/HamClock/>.  See the
[`upstream`](https://github.com/earldouglas/hamclock/tree/upstream)
branch for a mirror of the source code.

The `main` branch contains a Nix derivation in *default.nix* for
building HamClock.

## Building

```
$ nix-build
```

## Running

```
$ ./result/bin/hamclock-web-2400x1440 -h
```

```
$ ./result/bin/hamclock-web-2400x1440 -b localhost -f on
```
