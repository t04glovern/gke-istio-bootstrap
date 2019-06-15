#!/bin/sh

PROJECT_ID="$1"
PROJECT_REGION="australia-southeast1"

# Set Project
gcloud config set project $PROJECT_ID

case "$3" in
    "create"    )
        DEPLOY_ACTION="create"
        ;;
    "delete"    )
        DEPLOY_ACTION="delete"
        ;;
    *           )
        echo "Script requires an action. E.g. create, delete"
        exit 1
        ;;
esac

case "$2" in
    "iam"           )
        PROJECT_NUM=$(gcloud projects list \
            --filter=PROJECT_ID=$PROJECT_ID \
            --format="value(PROJECT_NUMBER)")
        if [ "$DEPLOY_ACTION" = "create" ]; then
            gcloud projects add-iam-policy-binding $PROJECT_ID \
                --member serviceAccount:$PROJECT_NUM@cloudservices.gserviceaccount.com  \
                --role roles/owner
        else
            echo "Deleting $PROJECT_ID-iam"
            gcloud projects remove-iam-policy-binding $PROJECT_ID \
                --member serviceAccount:$PROJECT_NUM@cloudservices.gserviceaccount.com  \
                --role roles/owner
        fi
        ;;
    "network"       )
        if [ "$DEPLOY_ACTION" = "create" ]; then
            gcloud deployment-manager deployments create $PROJECT_ID-network \
                --config resources/network.yaml
        else
            echo "Deleting $PROJECT_ID-network"
            gcloud deployment-manager deployments delete $PROJECT_ID-network -q
        fi
        ;;
    "cloud-router"  )
        if [ "$DEPLOY_ACTION" = "create" ]; then
            gcloud deployment-manager deployments create $PROJECT_ID-cloud-router \
                --config resources/cloud_router.yaml

            gcloud compute routers nats create $PROJECT_ID-nat \
                --router=$PROJECT_ID-cloud-router \
                --router-region=$PROJECT_REGION \
                --auto-allocate-nat-external-ips \
                --nat-all-subnet-ip-ranges
        else
            echo "Deleting $PROJECT_ID-cloud-router"
            gcloud deployment-manager deployments delete $PROJECT_ID-cloud-router -q

            echo "Deleting $PROJECT_ID-nat"
            gcloud compute routers nats delete $PROJECT_ID-nat \
                --router=$PROJECT_ID-cloud-router \
                --router-region=$PROJECT_REGION -q
        fi
        ;;
    "gke"           )
        if [ "$DEPLOY_ACTION" = "create" ]; then
            gcloud deployment-manager deployments create $PROJECT_ID-gke \
                --config resources/gke.yaml
        else
            echo "Deleting $PROJECT_ID-gke"
            gcloud deployment-manager deployments delete $PROJECT_ID-gke -q
        fi
        ;;
    "bastion"       )
        if [ "$DEPLOY_ACTION" = "create" ]; then
            gcloud deployment-manager deployments create $PROJECT_ID-bastion \
                --config resources/bastion.yaml
        else
            echo "Deleting $PROJECT_ID-bastion"
            gcloud deployment-manager deployments delete $PROJECT_ID-bastion -q
        fi
        ;;
    "dns"       )
        if [ "$DEPLOY_ACTION" = "create" ]; then
            aws cloudformation create-stack \
                --stack-name $PROJECT_ID-route53-user \
                --template-body file://cloudformation/route53.yaml \
                --parameters ParameterKey=Password,ParameterValue=$(openssl rand -base64 30) \
                --capabilities CAPABILITY_IAM
            aws cloudformation wait stack-create-complete --stack-name $PROJECT_ID-route53-user
            ACCESS_KEY=$(aws cloudformation describe-stacks --stack-name $PROJECT_ID-route53-user \
                            --query 'Stacks[0].Outputs[?OutputKey==`AccessKey`].OutputValue' \
                            --output text)
            SECRET_KEY=$(aws cloudformation describe-stacks --stack-name $PROJECT_ID-route53-user \
                            --query 'Stacks[0].Outputs[?OutputKey==`SecretKey`].OutputValue' \
                            --output text)
            tee <<EOF >./k8s/external-dns.yaml
provider: aws
aws:
    secretKey: '$SECRET_KEY'
    accessKey: '$ACCESS_KEY'
rbac:
    create: true
sources:
    - service
    - ingress
    - istio-gateway
EOF
        else
            echo "Deleting $PROJECT_ID-route53-user stack"
            aws cloudformation delete-stack --stack-name $PROJECT_ID-route53-user
            rm k8s/external-dns.yaml
        fi
        ;;
    "all"           )
        if [ "$DEPLOY_ACTION" = "create" ]; then
            echo "Creating all in $PROJECT_ID"
            ./deploy.sh $PROJECT_ID iam create
            ./deploy.sh $PROJECT_ID network create
            ./deploy.sh $PROJECT_ID cloud-router create
            ./deploy.sh $PROJECT_ID gke create
            ./deploy.sh $PROJECT_ID bastion create
            ./deploy.sh $PROJECT_ID dns create
        else
            echo "Deleting all in $PROJECT_ID"
            ./deploy.sh $PROJECT_ID iam delete
            ./deploy.sh $PROJECT_ID network delete
            ./deploy.sh $PROJECT_ID cloud-router delete
            ./deploy.sh $PROJECT_ID gke delete
            ./deploy.sh $PROJECT_ID bastion delete
            ./deploy.sh $PROJECT_ID dns delete
        fi
        ;;
    *               )
        echo "Script requires a resource. E.g. iam, network, cloud-router, gke, bastion, dns or all"
        exit 1
        ;;
esac
