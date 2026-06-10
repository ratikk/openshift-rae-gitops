#!/usr/bin/env bash
# arch-validate.sh — gather evidence for the OpenShift architecture compliance review.
# Read-only. Run on the control node with KUBECONFIG set. Paste the full output back.
set +e
sep(){ echo; echo "==================== $1 ===================="; }

sep "0. CLUSTER VERSION + NODES + OPERATORS"
oc version
oc get clusterversion
oc get nodes -o wide
echo "--- cluster operators (only non-healthy shown; empty = all healthy) ---"
oc get clusteroperators | grep -vE "True[[:space:]]+False[[:space:]]+False" 
echo "--- node AZ spread (3-AZ check) ---"
oc get nodes -L topology.kubernetes.io/zone -L node-role.kubernetes.io/master -L node-role.kubernetes.io/worker

sep "1. DNS / INGRESS DOMAIN"
oc get dns cluster -o jsonpath='{.spec.baseDomain}{"\n"}'
oc get ingress.config.openshift.io cluster -o jsonpath='domain={.spec.domain}{"\n"}'

sep "2. INGRESS / ROUTER"
oc get ingresscontroller -A
echo "--- router pods ---"
oc get pods -n openshift-ingress -o wide
echo "--- route count by ns (top) ---"
oc get routes -A --no-headers 2>/dev/null | awk '{print $1}' | sort | uniq -c | sort -rn | head

sep "3. EXTERNAL LB (MetalLB / NLB) + SERVICES"
echo "--- LoadBalancer-type services ---"
oc get svc -A | grep -i LoadBalancer
echo "--- metallb ---"
oc get pods -n metallb-system 2>/dev/null
oc get ipaddresspool -A 2>/dev/null
oc get l2advertisement -A 2>/dev/null
oc get bgpadvertisement -A 2>/dev/null
echo "--- F5 CIS (expect none) ---"
oc get deployment -A 2>/dev/null | grep -i cis || echo "no F5 CIS"

sep "4. MONITORING"
oc get pods -n openshift-monitoring | grep -E "prometheus|alertmanager|grafana|thanos" 
oc get servicemonitor -A --no-headers 2>/dev/null | wc -l | sed 's/^/servicemonitor count: /'

sep "5. AUTHENTICATION"
oc get pods -n openshift-authentication
oc get oauth cluster -o jsonpath='identityProviders={.spec.identityProviders}{"\n"}'

sep "6. SECURITY (SCC + etcd encryption)"
oc get scc -o name | sort
echo "--- etcd encryption ---"
oc get apiserver cluster -o jsonpath='encryption.type={.spec.encryption.type}{"\n"}'

sep "7. KEDA / CUSTOM METRICS AUTOSCALER"
oc get csv -A 2>/dev/null | grep -i keda
oc get crd 2>/dev/null | grep -iE "scaledobject|scaledjob|keda"
oc get scaledobject -A 2>/dev/null
oc get pods -n openshift-keda 2>/dev/null

sep "8. EXTERNAL SECRETS OPERATOR + VAULT"
oc get csv -A 2>/dev/null | grep -i secret
oc get pods -n external-secrets 2>/dev/null
oc get clustersecretstore 2>/dev/null
oc get clustersecretstore -o jsonpath='{range .items[*]}{.metadata.name}: {.status.conditions[0].reason} - {.status.conditions[0].message}{"\n"}{end}' 2>/dev/null
oc get externalsecret -A 2>/dev/null
echo "--- vault ---"
oc get pods -A 2>/dev/null | grep -i vault
oc get clustersecretstore -o jsonpath='{range .items[*]}{.metadata.name} provider: {.spec.provider}{"\n"}{end}' 2>/dev/null

sep "9. OPENSHIFT GITOPS / ARGOCD"
oc get argocd -A
oc get applications -n openshift-gitops
echo "--- per-app health detail ---"
oc get applications -n openshift-gitops -o jsonpath='{range .items[*]}{.metadata.name}: sync={.status.sync.status} health={.status.health.status}{"\n"}{end}'

sep "10. EFS CSI / STORAGE (3-AZ storage)"
oc get csv -n openshift-cluster-csi-drivers 2>/dev/null | grep -i efs
oc get pods -n openshift-cluster-csi-drivers 2>/dev/null | grep -i efs
oc get storageclass
oc get clustercsidriver efs.csi.aws.com -o jsonpath='efs driver state={.spec.managementState}{"\n"}' 2>/dev/null
oc get pv 2>/dev/null | head

sep "11. ETCD BACKUP (gitops cronjob)"
oc get cronjob -n openshift-etcd-backup 2>/dev/null
oc get sa -n openshift-etcd-backup etcd-backup -o jsonpath='role-arn={.metadata.annotations.eks\.amazonaws\.com/role-arn}{"\n"}' 2>/dev/null

sep "12. NETWORKPOLICIES (dormant-or-active check)"
oc get networkpolicy -A 2>/dev/null | grep -vE "^NAMESPACE" | grep -E "vault-system|external-secrets|openshift-gitops|openshift-monitoring"
oc get application -n openshift-gitops network-policies -o jsonpath='syncPolicy={.spec.syncPolicy}{"\n"}' 2>/dev/null

sep "13. NAMESPACE INVENTORY (non-system)"
oc get ns --no-headers 2>/dev/null | awk '{print $1}' | grep -vE "^(openshift-|kube-|default$|open-cluster)" 

sep "DONE"
echo "Paste the entire output above back into the chat."
