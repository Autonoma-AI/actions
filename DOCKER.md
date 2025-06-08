## Commands to build and push

```
docker build --platform linux/amd64 -t axlscld/autonoma-runner:1.0.0 .

docker push axlscld/autonoma-runner:1.0.0

docker tag axlscld/autonoma-runner:1.0.0 axlscld/autonoma-runner:latest
docker push axlscld/autonoma-runner:latest
```
