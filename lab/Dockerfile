# The orders service and the LLM stub. Built inside Docker, so the host needs no Go.
# Go 1.27.0 is the version that made the output shown in the articles.
FROM golang:1.27.0 AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY cmd cmd
RUN CGO_ENABLED=0 go build -o /out/ ./cmd/...

FROM ubuntu:24.04
COPY --from=build /out/ /
