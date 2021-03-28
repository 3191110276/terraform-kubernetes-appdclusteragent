############################################################
# REQUIRED PROVIDERS
############################################################
terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0.2"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.0.2"
    }
  }
}


############################################################
# CREATE BASIC ELEMENTS FOR APPDYNAMICS
############################################################
apiVersion: v1
kind: Secret
metadata:
  name: cluster-agent-secret
  namespace: {{ .Release.Namespace }}
stringData:
  controller-key: {{ .Values.appd_controller_key }}
  api-user: "{{ .Values.appd_username }}@{{ .Values.appd_account_name }}:{{ .Values.appd_password }}"
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: appdynamics-operator
  namespace: {{ .Release.Namespace }}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: appdynamics-operator
  namespace: {{ .Release.Namespace }}
rules:
  - apiGroups:
      - ""
    resources:
      - pods
      - pods/log
      - endpoints
      - persistentvolumeclaims
      - resourcequotas
      - nodes
      - events
      - namespaces
    verbs:
      - get
      - watch
      - list
  - apiGroups:
      - ""
    resources:
      - pods
      - services
      - configmaps
      - secrets
    verbs:
      - "*"
  - apiGroups:
      - apps
    resources:
      - statefulsets
    verbs:
      - get
      - watch
      - list
  - apiGroups:
      - apps
    resources:
      - deployments
      - replicasets
      - daemonsets
    verbs:
      - "*"
  - apiGroups:
      - "batch"
      - "extensions"
    resources:
      - "jobs"
    verbs:
      - "get"
      - "list"
      - "watch"
  - apiGroups:
      - metrics.k8s.io
    resources:
      - pods
      - nodes
    verbs:
      - get
      - list
      - watch
  - apiGroups:
      - appdynamics.com
    resources:
      - "*"
      - clusteragents
      - infravizs
      - adams
      - clustercollectors
    verbs:
      - "*"
---
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: appdynamics-operator
  namespace: {{ .Release.Namespace }}
subjects:
  - kind: ServiceAccount
    name: appdynamics-operator
roleRef:
  kind: Role
  name: appdynamics-operator
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: appdynamics-operator
  namespace: {{ .Release.Namespace }}
spec:
  replicas: 1
  selector:
    matchLabels:
      name: appdynamics-operator
  template:
    metadata:
      labels:
        name: appdynamics-operator
    spec:
      serviceAccountName: appdynamics-operator
      containers:
        - name: appdynamics-operator
          image: docker.io/appdynamics/cluster-agent-operator:0.6.3 #0.6.5
          ports:
            - containerPort: 60000
              name: metrics
          command:
            - appdynamics-operator
          imagePullPolicy: Always
          resources:
            limits:
              cpu: 200m
              memory: 128Mi
            requests:
              cpu: 100m
              memory: 64Mi
          env:
            - name: WATCH_NAMESPACE
              valueFrom:
                fieldRef:
                  fieldPath: metadata.namespace
            - name: POD_NAME
              valueFrom:
                fieldRef:
                  fieldPath: metadata.name
            - name: OPERATOR_NAME
              value: "appdynamics-operator"
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: appdynamics-cluster-agent
  namespace: {{ .Release.Namespace }}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: appdynamics-cluster-agent
rules:
  - apiGroups:
      - ""
    resources:
      - pods
      - pods/log
      - endpoints
      - persistentvolumeclaims
      - resourcequotas
      - nodes
      - events
      - namespaces
      - services
      - configmaps
      - secrets
    verbs:
      - get
      - watch
      - list
  - apiGroups:
      - apps
    resources:
      - daemonsets
      - statefulsets
      - deployments
      - replicasets
    verbs:
      - get
      - watch
      - list
  - apiGroups:
      - "batch"
      - "extensions"
    resources:
      - "jobs"
    verbs:
      - "get"
      - "list"
      - "watch"
  - apiGroups:
      - metrics.k8s.io
    resources:
      - pods
      - nodes
    verbs:
      - get
      - list
      - watch
  - apiGroups:
      - appdynamics.com
    resources:
      - "*"
      - clusteragents
      - clustercollectors
    verbs:
      - get
      - list
      - watch
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: appdynamics-cluster-agent-instrumentation
rules:
  - apiGroups:
      - ""
    resources:
      - pods
      - pods/exec
      - secrets
      - configmaps
    verbs:
      - create
      - update
      - delete
  - apiGroups:
      - apps
    resources:
      - daemonsets
      - statefulsets
      - deployments
      - replicasets
    verbs:
      - update
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: appdynamics-cluster-agent
subjects:
  - kind: ServiceAccount
    name: appdynamics-cluster-agent
    namespace: {{ .Release.Namespace }}
roleRef:
  kind: ClusterRole
  name: appdynamics-cluster-agent
  apiGroup: rbac.authorization.k8s.io
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: appdynamics-cluster-agent-instrumentation
subjects:
  - kind: ServiceAccount
    name: appdynamics-cluster-agent
    namespace: {{ .Release.Namespace }}
roleRef:
  kind: ClusterRole
  name: appdynamics-cluster-agent-instrumentation
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: appdynamics-infraviz
  namespace: {{ .Release.Namespace }}
---
apiVersion: policy/v1beta1
kind: PodSecurityPolicy
metadata:
  name: appdynamics-infraviz
  annotations:
    seccomp.security.alpha.kubernetes.io/allowedProfileNames: "*"
spec:
  privileged: true
  allowPrivilegeEscalation: true
  allowedCapabilities:
  - "*"
  volumes:
  - "*"
  hostNetwork: true
  hostIPC: true
  hostPID: true
  hostPorts:
  - min: 0
    max: 65535
  runAsUser:
    rule: "RunAsAny"
  seLinux:
    rule: "RunAsAny"
  supplementalGroups:
    rule: "RunAsAny"
  fsGroup:
    rule: "RunAsAny"
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  creationTimestamp: null
  name: appdynamics-infraviz
rules:
- apiGroups:
  - ""
  resources:
  - pods
  - nodes
  - events
  - namespaces
  verbs:
  - get
  - watch
  - list
- apiGroups:
  - apps
  resources:
  - statefulsets
  - deployments
  - replicasets
  - daemonsets
  verbs:
  - get
  - watch
  - list
- apiGroups: 
  - "batch"
  - "extensions"
  resources: 
  - "jobs"
  verbs: 
  - "get"
  - "list"
  - "watch"
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: appdynamics-infraviz
subjects:
- kind: ServiceAccount
  name: appdynamics-infraviz
  namespace: {{ .Release.Namespace }}
roleRef:
  kind: ClusterRole
  name: appdynamics-infraviz
  apiGroup: rbac.authorization.k8s.io
---
kind: Role
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: appdynamics-infraviz
  namespace: {{ .Release.Namespace }}
rules:
- apiGroups:
  - extensions
  resources:
  - podsecuritypolicies
  resourceNames:
  - appdynamics-infraviz
  verbs:
  - use
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: appdynamics-infraviz
  namespace: {{ .Release.Namespace }}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: appdynamics-infraviz
subjects:
- kind: ServiceAccount
  name: appdynamics-infraviz
  namespace: {{ .Release.Namespace }}




############################################################
# DEPLOY CRDS AND CUSTOM ELEMENTS
############################################################
resource "helm_release" "appd-crd" {
  name       = "appd-crd"

  chart      = "${path.module}/helm/"
  
  namespace  = var.appd_namespace
  
  set {
    name  = "appd_account_name"
    value = var.appd_account_name
  }
  
  set {
    name  = "appd_controller_url"
    value = var.appd_controller_url
  }
  
  set {
    name  = "appname"
    value = var.app_name
  }
  
  set {
    name  = "proxy_url"
    value = var.proxy_url
  }
  
  set {
    name  = "ns_to_monitor"
    value = "{${join(",", var.appd_ns_to_monitor)}}"
  }
  
  set {
    name  = "ns_to_instrument"
    value = var.ns_to_instrument
  }
  
  set {
    name  = "registry"
    value = var.registry
  }
  
  set {
    name  = "appd_global_account"
    value = var.appd_global_account
  }
}
