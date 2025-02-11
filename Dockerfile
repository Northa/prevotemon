# 1st stage, build app
FROM golang:latest as builder
RUN apt-get update && apt-get -y upgrade
COPY . /build/app
WORKDIR /build/app

RUN go get ./... && go build -ldflags "-s -w" -o pvmon cmd/pvmon/main.go

# 2nd stage, create a user to copy, and install libraries needed if connecting to upstream TLS server
FROM debian:10 AS ssl
ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update && apt-get -y upgrade && apt-get install -y ca-certificates && \
    addgroup --gid 26657 --system pvmon && adduser -uid 26657 --ingroup pvmon --system --home /var/lib/pvmon pvmon

# 3rd and final stage, copy the minimum parts into a scratch container, is a smaller and more secure build.
FROM scratch
COPY --from=ssl /etc/ca-certificates /etc/ca-certificates
COPY --from=ssl /etc/ssl /etc/ssl
COPY --from=ssl /usr/share/ca-certificates /usr/share/ca-certificates
COPY --from=ssl /usr/lib /usr/lib
COPY --from=ssl /lib /lib
COPY --from=ssl /lib64 /lib64

COPY --from=ssl /etc/passwd /etc/passwd
COPY --from=ssl /etc/group /etc/group
COPY --from=ssl --chown=pvmon:pvmon /var/lib/pvmon /var/lib/pvmon

COPY --from=builder /build/app/pvmon /pvmon

EXPOSE 8080
USER pvmon
WORKDIR /var/lib/pvmon

ENTRYPOINT ["/pvmon"]
