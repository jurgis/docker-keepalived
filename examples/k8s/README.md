# Installation in kubernetes

```
# Mark nodes which will be running ingress and keepalived with label:
# run-ingress: "true"
# check which nodes are already labeled
$ kubectl get nodes -L run-ingress
# label additional nodes
$ kubectl label nodes YOUR-NODE-NAME run-ingress=true

# create or update the configmap
$ kubectl apply -f keepalived-cm.yaml

# update the configuration if needed
# update: password (can't contain pipe '|' symbol!) and virtual_ip
$ kubectl edit cm keepalived-conf

# create or update the headless service
$ kubectl apply -f keepalived-svc.yaml

# create or update the daemon-set
$ kubectl apply -f keepalived-ds.yaml
```
