FROM golang:1.23-alpine AS build
WORKDIR /src
COPY . .
RUN CGO_ENABLED=0 go build -o /out/validacao ./cmd/server

FROM alpine:3.20.2
RUN apk add --no-cache ca-certificates busybox-extras
COPY --from=build /out/validacao /usr/local/bin/validacao
USER 65532:65532
ENTRYPOINT ["/usr/local/bin/validacao"]
