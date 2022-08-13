KUBERNETES-HELM-SETUP
=====
> **NOTE:** `<>` are variables, supposed to be replaced with respective value.
## Automated-Run for creating SA and config
```sh
chmod +x generate-config.sh
./generate-config.sh -u <user-email> or ./generate-config.sh -g <multiple namespace seperated with comma>
```
> **NOTE:** Move to __CI Stage Setup__ section for setting up CI Deploy stage. 

## Manual-Run
- Create namespace and assign it to a environment variable
```sh
kubectl create ns <namespace>
NAMESPACE=<namespace>
```
- Install the gitlab-sa-access-helm chart.
```sh
helm upgrade --install gitlab-sa-access-helm --set namespace=$NAMESPACE ./gitlab-sa-access-helm -f ./gitlab-sa-access-helm/values.yaml
```
> If required, you are **allowed** to **change values** in 
> __gitlab-sa-access-helm/values.yaml__ file 
- Verify the helm deployment by examining following command's output
```sh
kubectl get sa -n $NAMESPACE | grep gitlab-service-account 
kubectl get role -n $NAMESPACE | grep gitlab-service-account-role 
kubectl get rolebinding -n $NAMESPACE | grep gitlab-service-account-role-binding 
```
- Once we verified that SA is created in <namespace>, it's time to create Kubeconfig.

### Kubeconfig 
- Get the API server address
```sh
APISERVER=`kubectl config view --minify | grep server | cut -f 2- -d ":" | tr -d " " `
```
- Get the token name of the service-account.
```sh
SECRET_NAME=`kubectl -n $NAMESPACE get serviceaccount/gitlab-service-account -o jsonpath='{.secrets[0].name}'` 
```
- Print output of the service-account token.
```sh
TOKEN=`kubectl get secret $SECRET_NAME -n $NAMESPACE -o jsonpath='{.data.token}' | base64 --decode`
```
- Create config by variable substituting using below commands:
```sh
sed -i "s/\$TOKEN/${TOKEN}/g" ./src/config
sed -i "s/\$NAMESPACE/${NAMESPACE}/g" ./src/config
sed -i "s/\$APISERVER/${APISERVER}/g" ./src/config
```
- Execute the encode_base64_config.sh after giving permission.
```sh
chmod +x ./src/encode_base64_config.sh
./src/encode_base64_config.sh
```
### CI Stage Setup
- This script outputs base64 encoded config, which we store as an environment variable in the gitlab project (GITLAB_SA_KUBE_CONFIG) as shown below:

|Variable| Value | Protected | Masked |
| ------ | ------ | ------ | ------ |
| GITLAB_SA_KUBE_CONFIG| < output of the the script, i.e. base64 encoded config > | yes | yes

> **Note:** All Variables must be **PROTECTED**, and All tokens/passwords must be **MASKED**.

- We create these **LOCAL VARIABLES** in the beginning of __.gitlab-ci.yaml__ file.

|Variable| Value | 
| ------ | ------ |
| IMAGE_TAG | "$CI_COMMIT_SHORT_SHA" |
| KUBERNETES_CONTEXT| "default" | 
| DEPLOYMENT_NAME | <deploy_name> |
| DEPLOYMENT_NAMESPACE | $NAMESPACE |

- We create these **ENVIRONMENT VARIABLES** in the project specific CI.

| Variable| Value | Protected | Masked |
| ------ | ------ | ------ | ------ |
| HELM_DEPLOY_TOKEN | <helm_token> | yes | yes |
| HELM_USERNAME | <helm_user> | yes | no |
| REPOSITORY_URL | <repo_url> | yes | no |

- Finally, it is up for **DEPLOY** stage in __.gitlab-ci.yaml__ file.
```
.deploy: 
  stage: deploy
  image: 
    name: "vivekpd15/helm-kubectl:3.3.2-1.18.8"  #docker image
    entrypoint: 
      - ""
  script: 
    - "mkdir ~/.kube/"
    - "echo $GITLAB_SA_KUBE_CONFIG | base64 -d > sa-config"
    - "mv sa-config ~/.kube/config"
    - "kubectl config set-context $KUBERNETES_CONTEXT"
    - "kubectl config use-context $KUBERNETES_CONTEXT"
    - "git clone https://$HELM_USERNAME:$HELM_DEPLOY_TOKEN@<url of helm repo excluding https://>
    - "helm upgrade --install $DEPLOYMENT_NAME <path till helm chart> --set image.imageName=${REPOSITORY_URL}:build_${IMAGE_TAG} -n $DEPLOYMENT_NAMESPACE"
  only:
    variables:
      - $IMAGE_TAG != null
```
