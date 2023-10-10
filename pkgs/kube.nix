{ pkgs, ... }:
with pkgs;
{
  home = {
    packages = with pkgs; [
      # all the kubernetes related stuff
      argo argocd kubectx kubectl (google-cloud-sdk.withExtraComponents [google-cloud-sdk.components.gke-gcloud-auth-plugin]) kustomize
      helmfile kubernetes-helm k9s crane minikube kind octant awscli2 vault terraform cosign syft grype ko cmctl 
    ];
  };
}
