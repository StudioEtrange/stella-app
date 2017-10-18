
# Stella Application and Scripts


Easy one-file scripts that could deploy/run/install/other binaries/service/libraries/other for you

## Generic system

These scripts should be run on any nix like system. They try to not use any root/sudo permissions,
nor polluted the system.


* xgboost-python : install xgboost in your current active python environnement
```
  ./xgboost-python.sh -h
```

* lightgbm-python : install lightgbm in your current active python environnement
```
  ./lightgbm-python.sh -h
```

* netdata-service : install netdata https://my-netdata.io/ -- NEEDS : docker
```
  ./netdata.sh -h
```

* cozy-service : install cozy https://cozy.io -- NEEDS : docker
```
  ./cozy-service.sh -h
```

* cloud9-service : install cloud9 dev env into your current host https://c9.io -- NEEDS : docker
```
  ./cloud9-service.sh -h
```

## Specific for a system

These scripts are tied to specific systems, and may install items inside the system.

* docker-ubuntu : install docker on ubuntu
```
  ./docker-ubuntu.sh -h
```

* docker-rhel : install docker on red hat & centos
```
  ./docker-rhel.sh -h
```
