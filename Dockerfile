# stage: builder
FROM golang:alpine AS builder

COPY . /go/src/github.com/concourse/docker-image-resource
ENV CGO_ENABLED 0
COPY assets/ /assets
RUN go build -o /assets/check github.com/concourse/docker-image-resource/cmd/check
RUN go build -o /assets/print-metadata github.com/concourse/docker-image-resource/cmd/print-metadata
RUN go build -o /assets/ecr-login github.com/concourse/docker-image-resource/vendor/github.com/awslabs/amazon-ecr-credential-helper/ecr-login/cmd
RUN set -e; \
    for pkg in $(go list ./...); do \
      go test -o "/tests/$(basename $pkg).test" -c $pkg; \
    done

# stage: resource
# FROM alpine:edge AS resource
FROM frolvlad/alpine-glibc:latest AS resource
RUN apk --no-cache add \
      bash \
      docker \
      jq \
      ca-certificates \
      xz \
    ;
COPY --from=builder /assets /opt/resource
RUN ln -s /opt/resource/ecr-login /usr/local/bin/docker-credential-ecr-login
RUN ln -s /opt/resource/oc /usr/local/bin/oc

# stage: tests
FROM resource AS tests
COPY --from=builder /tests /tests
ADD . /docker-image-resource
RUN set -e; \
    for test in /tests/*.test; do \
      $test -ginkgo.v; \
    done

# final output stage
FROM resource
