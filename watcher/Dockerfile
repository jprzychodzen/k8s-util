FROM golang:1.12 AS build-env

ARG gopkg=github.com/mm4tt/k8s-util/watcher

ADD ["cmd", "/go/src/$gopkg/cmd"]
#ADD ["pkg", "/go/src/$gopkg/pkg"]
ADD ["go.mod", "/go/src/$gopkg"]
ADD ["go.sum", "/go/src/$gopkg"]

ENV GO111MODULE on
WORKDIR /go/src/$gopkg
RUN CGO_ENABLED=0 go build -o /workspace/main.bin ./cmd

FROM golang:1.12-alpine
WORKDIR /workspace
COPY --from=build-env /workspace/main.bin .
ENTRYPOINT ["/workspace/main.bin"]

