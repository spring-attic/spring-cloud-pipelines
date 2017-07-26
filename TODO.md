List of things still to be done

## Common

- Extract service declaration to a separate file

## K8S

- I wait for the deployed services to start by `sleep`
- I can't find a better way to find the application URL than provide
the URL of Kubernetes cluster and search for the `NodePort`
- Versioning of the manifests is gone due to their templating nature
- A/B testing

## TODOs

### K8S

- Use namespaces instead of labels
- Use `readinessProbe` and `livenessProbe`
- Add `--context=${context}` to each `kubectl` call
- Instead of doing a `sleep` use `kubectl` to get the pod and analyze
if it's running
- For Kubernetes cluster 
    - Jenkins worker has to be in Kubernetes
    - For minikube we'll reach the apps via API
    - Provide a switch for `minikube` vs Cloud Kubernetes
    - Jenkins worker needs to call the apps by FQN (with namespace)
- Versioning manifests
    - store the filled out manifest yamls in a separate repo / branch
    / as an artifact in Jenkins
- A/B testing
    - label deployments with PIPELINE_VERSION
    - deploy the name to production with PIPELINE_VERSION suffix
    - service remains the same and does load balancing
    - once you want to switch you remove the old instance