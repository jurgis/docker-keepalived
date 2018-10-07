# docker-keepalived

This is a dockerized version of keepalived.

Initial files are taken from here:
https://forums.rancher.com/t/what-on-prem-load-balancing-virtual-ip-implementation-did-you-use/11028/19

## Build
```
$ docker build . -t jurgis/keepalived
$ docker push jurgis/keepalived
```

## Run locally for testing purpose
```
docker run -it --rm -v $PWD/examples/config:/etc/keepalived/config -v $PWD/examples/secrets:etc/keepalived/secrets jurgis/keepalived
```

## TODO
- [ ] Improve examples/scripts/default_unicast_peers_script.sh to retry if error is returned by dig command (happens when node is restarted)
- [ ] Add examples/scripts/hetzner_cloud_notify_script.sh which will switch floating IP in hetzner cloud
- [x] Use kubernetes secret for keepalived password and access token for ip switching
- [ ] Decrease ubuntu based image size
- [ ] Set up build pipeline in hub.docker.com (currently I'm pushing manually to https://hub.docker.com/r/jurgis/keepalived/tags/)
- [ ] Switch to alpine linux if possible (to reduce container size)
