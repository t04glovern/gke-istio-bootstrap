#!/bin/sh

PROJECT_ID="$1"
ISTIO_VERSION="1.1.8"

gcloud container clusters get-credentials $PROJECT_ID-gke \
    --region australia-southeast1 \
    --project $PROJECT_ID

case "$2" in
    "init"      )
        curl -L https://git.io/getLatestIstio | ISTIO_VERSION=$ISTIO_VERSION sh -
        cd istio-$ISTIO_VERSION/

        # Guide: https://istio.io/docs/setup/kubernetes/install/helm/
        kubectl create namespace istio-system
        helm template install/kubernetes/helm/istio-init \
            --name istio-init \
            --namespace istio-system | kubectl apply -f -
        echo "Run 'kubectl get crds | grep 'istio.io\|certmanager.k8s.io' | wc -l' until you get 53"
        kubectl get crds | grep 'istio.io\|certmanager.k8s.io' | wc -l
        KIALI_USERNAME=$(echo -n 'admin' | base64)
        KIALI_PASSPHRASE=$(echo -n 'admin' | base64)
        cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: kiali
  namespace: istio-system
  labels:
    app: kiali
type: Opaque
data:
  username: $KIALI_USERNAME
  passphrase: $KIALI_PASSPHRASE
EOF
        ;;

    "install"   )
        cd istio-$ISTIO_VERSION/
        # Create Services
        helm template install/kubernetes/helm/istio \
            --name istio \
            --set global.mtls.enabled=false \
            --set kiali.enabled=true \
            --namespace istio-system | kubectl apply -f -
        # Enable Istio
        kubectl label namespace default istio-injection=enabled
        ;;

    "remove"    )
        cd istio-$ISTIO_VERSION/
        # Disable Istio
        kubectl label namespace default istio-injection=disabled --overwrite
        # Delete Services
        helm template install/kubernetes/helm/istio \
            --name istio \
            --set global.mtls.enabled=false \
            --set kiali.enabled=true \
            --namespace istio-system | kubectl delete -f -
        # Delete CRDs
        kubectl delete -f install/kubernetes/helm/istio-init/files
        # Delete namespace
        kubectl delete namespace istio-system
        ;;

    *           )
        echo "Script requires an action: init, install, remove"
        exit 1
        ;;
esac
