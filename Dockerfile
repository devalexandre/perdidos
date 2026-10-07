# Build stage
FROM golang:1.26-alpine AS builder

WORKDIR /app/launcher/server
COPY launcher/server/go.mod launcher/server/go.sum ./
RUN go mod download

COPY launcher/server/ ./
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-w -s" -o /app/authgate .

# Final stage
FROM alpine:3.21
RUN apk --no-cache add ca-certificates tzdata
WORKDIR /app
COPY --from=builder /app/authgate /app/authgate
COPY site/ /app/site/
RUN rm -f /app/site/README.md

EXPOSE 8080
ENV PORT=8080
ENV PERDIDOS_GAME_ADDR=""
ENV PERDIDOS_SITE_DIR=/app/site

CMD ["/app/authgate", "-game="]
