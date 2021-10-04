# FuseML workflow extention library


# register_fuseml_app converts a set of kubernetes manifests received at input
# in JSON format into a FuseML Application descriptor, which is then registered
# with FuseML.
#
# This function is meant to be run from inside a workflow step with some parameters
# supplied as command line args, and a list of JSON kubernetes manifests provided
# at stdin, e.g.:
#
#   kubectl apply -f /path/to/manifests --dry-run=client -o json | \
#     register_fuseml_app --name myapp --description "My App" --url https://my.app --type predictor
#
register_fuseml_app() {
    local name description url apptype resources options k8s_resources
    
    options=$(getopt -l "name:,description:,url:,type:" -o "n:d:u:t:" -a -- "$@")
    eval set -- "$options"

    while true
    do
        case $1 in
            -n|--name)
                shift
                name=$1
                ;;
            -d|--description)
                shift
                description=$1
                ;;
            -u|--url)
                shift
                url=$1
                ;;
            -t|--type)
                shift
                apptype=$1
                ;;
            --)
                shift
                break;;
        esac
        shift
    done
    k8s_resources=$(jq -r '[.items[] | {name:.metadata.name, kind:.kind}]' < /dev/stdin) 
    resources=$(cat << EOF
{
    "name": "$name",
    "description": "$description",
    "type": "$apptype",
    "url": "$url",
    "workflow": "$FUSEML_ENV_WORKFLOW_NAME",
    "k8s_namespace": "$FUSEML_ENV_WORKFLOW_NAMESPACE",
    "k8s_resources": "$k8s_resources"
}
EOF
)

    curl -X POST -H "Content-Type: application/json" \
    http://fuseml-core.fuseml-core.svc.cluster.local:80/applications \
    -d "$resources"
}
