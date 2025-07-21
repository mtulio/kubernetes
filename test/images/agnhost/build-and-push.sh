#!/bin/bash
set -e

# Configuration
REGISTRY="${REGISTRY:-quay.io/mrbraga}"
TAG="${TAG:-v2.56-proxy-protocol-v2}"
IMAGE_NAME="agnhost"

echo "Building agnhost binary..."
make bin

echo "Building container image..."
cat > Dockerfile.simple << 'EOF'
FROM alpine:3.21

# Install necessary packages used by various e2e tests
RUN apk --update add bind-tools curl netcat-openbsd iproute2 iperf bash && rm -rf /var/cache/apk/* \
  && ln -s /usr/bin/iperf /usr/local/bin/iperf

# Add CoreDNS
ADD https://github.com/coredns/coredns/releases/download/v1.6.2/coredns_1.6.2_linux_amd64.tgz /coredns.tgz
RUN tar -xzvf /coredns.tgz && rm -f /coredns.tgz

# Expose ports used by various tests
EXPOSE 80 8080 8081 9376 5000

# Create uploads directory for netexec
RUN mkdir /uploads

# Add SSL certificates for porter
ADD porter/localhost.crt localhost.crt
ADD porter/localhost.key localhost.key

# Add the agnhost binary (with proxy protocol v2 support)
ADD agnhost agnhost

# Create symlink for entrypoint-tester tests
RUN ln -s agnhost agnhost-2

# Add user and group for supplemental groups tests
RUN adduser -u 1000 -D user-defined-in-image && \
    addgroup -g 50000 group-defined-in-image && \
    addgroup user-defined-in-image group-defined-in-image

ENTRYPOINT ["/agnhost"]
CMD ["pause"]
EOF

docker build -f Dockerfile.simple -t ${REGISTRY}/${IMAGE_NAME}:${TAG} .

echo "Pushing to registry..."
docker push ${REGISTRY}/${IMAGE_NAME}:${TAG}

echo "Cleaning up..."
rm Dockerfile.simple

echo "✅ Successfully built and pushed: ${REGISTRY}/${IMAGE_NAME}:${TAG}"
echo ""
echo "To use in your tests, update your pod spec to use:"
echo "  Image: ${REGISTRY}/${IMAGE_NAME}:${TAG}"
echo "  Args: [..., \"--enable-proxy-protocol-v2\"]"
