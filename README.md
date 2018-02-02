
# Stella Application and Scripts


* Easy one-file scripts that could deploy/run/install/other binaries/service/libraries/other for you


* These scripts should be run on any nix like system. They try to not use any root/sudo permissions,
nor polluted the system.

## Tools

* **xgboost-python**
  Install xgboost in your current active python environnement. Designed with `virtuelenv` or `conda` in mind.
```
  ./xgboost-python.sh -h
```

* **lightgbm-python**
  Install lightgbm in your current active python environnement
```
  ./lightgbm-python.sh -h
```

* **cloud9-service** *[NEEDS docker]*
  cloud9 is a web IDE
  https://c9.io
```
  ./cloud9-service.sh -h
```

* **docker-ubuntu**
  Install docker on ubuntu
  *This is an OS Specific task which manipulate the system*
```
  ./docker-ubuntu.sh -h
```

* **docker-rhel**
  Install docker on red hat & centos
  *This is an OS Specific task which manipulate the system*
```
  ./docker-rhel.sh -h
```

## Services

* **netdata-service** *[NEEDS docker]*
  netadata is a real-time monitoring webapp
  https://my-netdata.io
```
  ./netdata.sh -h
```

* **portainer-service** *[NEEDS docker]*
  portainer is an online docker management
  https://portainer.io
```
  ./portainer-service.sh -h
```

* **traefik-service** *[NEEDS docker]*
  Traefik is a dynamic reverse proxy which can get configuration from different backend
  https://traefik.io
  `traefik-service` have a optional autoset to use your current host docker as backend
```
  ./traefik-service.sh -h
```

* **consul-service** *[NEEDS docker]*
  Consul is a service discovery, key store and conf store
  https://www.consul.io

  `consul-service` can deploy a consul agent server or a consul agent client

```
  ./consul-service.sh -h
```

* **docker-proxy-service** *[NEEDS docker and consul-service]*

  `docker-proxy-service` act as a dynamic proxy for docker container.

  It is based on consul/registrator for gather container data AND on consul-template/nginx to serve as a dynamic proxy for container

```
  ./docker-proxy-service -h
```
