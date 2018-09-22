# docker-keepalived

This is a dockerized version of keepalived.

Initial files are taken from here:
https://forums.rancher.com/t/what-on-prem-load-balancing-virtual-ip-implementation-did-you-use/11028/19

## Build
```
$ docker build . -t jurgis/keepalived
```

## Run locally for testing purpose
```
$ docker run -it --rm -v $PWD/examples/templates:/etc/keepalived/templates -v $PWD/examples/config:/etc/keepalived/config jurgis/keepalived /bin/bash
```

## TODO
- [ ] Set up build pipeline in hub.docker.com
- [ ] Switch to alpine linux if possible (to reduce container size)

