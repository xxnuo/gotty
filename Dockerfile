# Frontend build stage
FROM oven/bun:1 as js-build
WORKDIR /app
COPY js/package.json js/bun.lock ./js/
RUN cd js && bun install --frozen-lockfile
COPY js ./js
RUN cd js && bunx webpack --mode=production

# Go build stage
FROM golang:1.24-alpine as go-build
RUN apk add --no-cache make git
WORKDIR /build
COPY . .
# Copy frontend assets to where Go expects them
RUN mkdir -p bindata/static/js bindata/static/css
COPY --from=js-build /app/bindata/static/js/gotty.js bindata/static/js/
COPY --from=js-build /app/bindata/static/js/gotty.js.map bindata/static/js/
# Copy other assets using Makefile logic or manually, leveraging the Makefile for consistency
# We need resources/ to be available
RUN make copy-assets
# Build the binary
RUN make build

# Final image
FROM alpine:latest
RUN apk add --no-cache ca-certificates bash
WORKDIR /root
COPY --from=go-build /build/gotty /usr/bin/
ENTRYPOINT ["/usr/bin/gotty"]
CMD ["-w", "bash"]