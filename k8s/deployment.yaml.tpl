# Deployment manages the demo app Pods.
#
# It tells Kubernetes how many replicas to run, which container image to use,
# what environment variables to pass, and how to check whether the app is alive and ready for traffic.
apiVersion: apps/v1
kind: Deployment

metadata:
  # Deployment name.
  name: demo-app

  # Deploy into the dedicated application namespace.
  namespace: demo-app

  # Labels used for organization and selection.
  labels:
    app: demo-app

spec:
  # Run two app Pods for basic availability.
  #
  # If one Pod is restarting or unavailable, the other Pod can still serve
  # traffic.
  replicas: 2

  # The Deployment uses this selector to know which Pods it owns.
  #
  # This must match the labels under template.metadata.labels.
  selector:
    matchLabels:
      app: demo-app

  # Pod template used by the Deployment when creating replicas.
  template:
    metadata:
      # Labels applied to each Pod.
      #
      # The Deployment selector and Service selector both use this label to find the demo app Pods.
      labels:
        app: demo-app

    spec:
      containers:
        - name: demo-app

          # Container image to deploy.
          #
          # ${IMAGE} is replaced by scripts/deploy.sh using envsubst before this manifest is applied.
          #
          # Example rendered value:
          # us-central1-docker.pkg.dev/project/repo/demo-app:XXXXX
          image: ${IMAGE}

          # Only pull the image if it is not already present on the node.
          #
          # Since we deploy uniquely tagged images, this is fine. If using only mutable tags like "latest", Always may be safer.
          imagePullPolicy: IfNotPresent

          ports:
            # Port exposed by the container.
            #
            # The app listens on this port, and the Service forwards traffic to it.
            - containerPort: 8000

          env:
            # App environment label used by the demo application.
            - name: ENVIRONMENT
              value: "PROD"

            # Bind the app to all network interfaces inside the container.
            #
            # This is required so Kubernetes can reach the app from outside the container network namespace.
            #
            # 0.0.0.0 means the app listens on every interface available inside
            # the container, including the Pod network interface.
            #
            # If the app listened only on 127.0.0.1, it would be reachable only
            # from inside the same container. Kubernetes Services, probes, and
            # load balancer traffic need to reach the app through the Pod's
            # network interface, so the app must listen on 0.0.0.0.
            #
            # This does not expose the app publicly by itself. Public exposure is
            # controlled separately by the Kubernetes Service and Ingress.
            - name: HOST
              value: "0.0.0.0"

            # Port the app listens on inside the container.
            - name: PORT
              value: "8000"

            # Redis host injected from Terraform output by scripts/deploy.sh.
            #
            # This points to the private Memorystore Redis endpoint.
            - name: REDIS_HOST
              value: "${REDIS_HOST}"

            # Redis port injected from Terraform output by scripts/deploy.sh.
            - name: REDIS_PORT
              value: "${REDIS_PORT}"

            # Redis logical database number.
            #
            # For Redis Cluster this value is generally not meaningful in the same way as standalone Redis, but the main branch app expects it.
            #
            # Standalone Redis supports numbered logical databases, such as 0,
            # 1, 2, etc. Database 0 is the default.
            #
            # Redis Cluster generally uses database 0 only; separate numbered
            # logical databases are not meaningful in the same way because Redis
            # Cluster distributes keys across hash slots and shards.
            #
            # The main branch app still expects REDIS_DB to exist and passes it
            # into the Redis client, so we keep it set to 0 for compatibility.
            - name: REDIS_DB
              value: "0"

          # Kubernetes Pod health checks.
          #
          # These are used by Kubernetes, not directly by the external Google Cloud Load Balancer.
          #
          # readinessProbe decides whether the Pod is ready to receive traffic
          # from the Kubernetes Service. If readiness fails, Kubernetes removes
          # the Pod from the Service endpoints.
          #
          # livenessProbe decides whether the container should be restarted. If
          # liveness keeps failing, Kubernetes restarts the container.
          #
          # Main branch note:
          # The app does not have a dedicated /health endpoint, so both probes
          # check the root path.
          readinessProbe:
            httpGet:
              # Main branch note:
              # The app does not have a dedicated /health endpoint, so the
              # readiness probe checks the root path.
              #
              # Readiness controls whether the Pod is allowed to receive traffic
              # from the Kubernetes Service.
              path: /
              port: 8000

            # Wait 10 seconds after container start before the first readiness check.
            initialDelaySeconds: 10

            # Run the readiness check every 10 seconds.
            periodSeconds: 10

          livenessProbe:
            httpGet:
              # Main branch note:
              # The app does not have a dedicated /health endpoint, so the
              # liveness probe checks the root path.
              #
              # Liveness controls whether Kubernetes should restart the container
              # if the app appears stuck or unhealthy.
              path: /
              port: 8000

            # Give the app more time to start before liveness checks begin.
            initialDelaySeconds: 30

            # Run the liveness check every 20 seconds.
            periodSeconds: 20

          resources:
            requests:
              # Minimum CPU Kubernetes reserves/schedules for this container.
              #
              # 100m means 100 millicores, or 0.1 vCPU.
              cpu: "100m"

              # Minimum memory Kubernetes reserves/schedules for this container.
              memory: "128Mi"

            limits:
              # Maximum CPU the container can use before it is throttled.
              cpu: "500m"

              # Maximum memory the container can use before it may be killed and
              # restarted if it exceeds the limit.
              memory: "512Mi"