FROM golang:1.23 AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o /out/rag-service ./demo/rag-service

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /out/rag-service /rag-service
COPY demo/rag-service/fixtures /demo/rag-service/fixtures
ENTRYPOINT ["/rag-service"]
