FROM golang:1.15-alpine as minio-builder

ENV GOPATH /go
ENV CGO_ENABLED 0
ENV GO111MODULE on

RUN apk add --no-cache git && \
  git clone https://github.com/minio/mc && cd mc && \
  go install -v -ldflags "$(go run buildscripts/gen-ldflags.go)"

FROM alpine

COPY --from=minio-builder /go/bin/mc /usr/bin/mc
COPY --from=minio-builder /go/mc/CREDITS /licenses/CREDITS
COPY --from=minio-builder /go/mc/LICENSE /licenses/LICENSE

ENV KUBE_LATEST_VERSION="v1.20.5"

RUN apk add --update gettext \
  && apk add --update ca-certificates \
  && apk add --update curl \
  && export ARCH="$(uname -m)" && if [[ ${ARCH} == "x86_64" ]]; then export ARCH="amd64"; fi && curl -L https://storage.googleapis.com/kubernetes-release/release/${KUBE_LATEST_VERSION}/bin/linux/${ARCH}/kubectl -o /usr/local/bin/kubectl \
  && chmod +x /usr/local/bin/kubectl \
  && rm /var/cache/apk/*

COPY template.sh  /root/template.sh
COPY run.sh /usr/local/bin/run

CMD [ "run" ]
