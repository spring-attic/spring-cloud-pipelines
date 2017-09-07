List of things still to be done

## K8S

- I can't find a better way to find the application URL than provide
the URL of Kubernetes cluster and search for the `NodePort`
- Versioning of the manifests is gone due to their templating nature
- A/B testing

## TODOs

- Don't set Eureka / Rabbit on the deployed application by default (analyze the pipeline descriptor)
- Add if / else for minikube

### K8S

- Use `readinessProbe` and `livenessProbe` **I DON'T KNOW HOW TO USE THIS PROPERLY**
- Setup `minikube-helper.sh` to 
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