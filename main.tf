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
resource "kubernetes_secret" "cluster-agent-secret" {
  metadata {
    name      = "cluster-agent-secret"
    namespace = var.namespace
  }

  data = {
    "controller-key" = var.controller_key
    "api-user"       = "${var.username}@${var.account_name}:${var.password}"
  }
}


resource "kubernetes_service_account" "appdynamics-operator" {
  metadata {
    name      = "appdynamics-operator"
    namespace = var.namespace
  }
  secret {
    name = "${kubernetes_secret.example.metadata.0.name}"
  }
}


resource "kubernetes_role" "appdynamics-operator" {
  metadata {
    name      = "appdynamics-operator"
    namespace = var.namespace
  }

  rule {
    api_groups     = [""]
    resources      = ["pods", "pods/log", "endpoints", "persistentvolumeclaims", "resourcequotas", "nodes", "events", "namespaces"]
    verbs          = ["get", "list", "watch"]
  }
  
  rule {
    api_groups     = [""]
    resources      = ["pods", "services", "configmaps", "secrets"]
    verbs          = ["*"]
  }
  
  rule {
    api_groups     = ["apps"]
    resources      = ["statefulsets"]
    verbs          = ["get", "list", "watch"]
  }
  
  rule {
    api_groups     = ["apps"]
    resources      = ["deployments", "replicasets", "daemonsets"]
    verbs          = ["*"]
  }
  
  rule {
    api_groups     = ["batch", "extensions"]
    resources      = ["jobs"]
    verbs          = ["get", "list", "watch"]
  }
  
  rule {
    api_groups     = ["metrics.k8s.io"]
    resources      = ["pods", "nodes"]
    verbs          = ["get", "list", "watch"]
  }
  
  rule {
    api_groups     = ["appdynamics.com"]
    resources      = ["*", "clusteragents", "infravizs", "adams", "clustercollectors"]
    verbs          = ["*"]
  }
}


resource "kubernetes_role_binding" "appdynamics-operator" {
  metadata {
    name      = "appdynamics-operator"
    namespace = var.namespace
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = "appdynamics-operator"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "appdynamics-operator"
    api_group = "rbac.authorization.k8s.io"
  }
}


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
resource "kubernetes_service_account" "appdynamics-cluster-agent" {
  metadata {
    name      = "appdynamics-cluster-agent"
    namespace = var.namespace
  }
}
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
resource "kubernetes_service_account" "appdynamics-infraviz" {
  metadata {
    name      = "appdynamics-infraviz"
    namespace = var.namespace
  }
}
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


resource "kubernetes_cluster_role" "appdynamics-infraviz" {
  metadata {
    name = "appdynamics-infraviz"
  }

  rule {
    api_groups = [""]
    resources  = ["pods", "nodes", "events", "namespaces"]
    verbs      = ["get", "list", "watch"]
  }
  
  rule {
    api_groups = ["apps"]
    resources  = ["statefulsets", "deployments", "replicasets", "daemonsets"]
    verbs      = ["get", "list", "watch"]
  }
  
  rule {
    api_groups = ["batch", "extensions"]
    resources  = ["jobs"]
    verbs      = ["get", "list", "watch"]
  }
}

 
resource "kubernetes_cluster_role_binding" "appdynamics-infraviz" {
  metadata {
    name = "appdynamics-infraviz"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "appdynamics-infraviz"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "appdynamics-infraviz"
    api_group = "rbac.authorization.k8s.io"
  }
}

resource "kubernetes_role" "appdynamics-infraviz" {
  metadata {
    name      = "appdynamics-infraviz"
    namespace = var.namespace
  }

  rule {
    api_groups     = ["extensions"]
    resources      = ["podsecuritypolicies"]
    resource_names = ["appdynamics-infraviz"]
    verbs          = ["use"]
  }
}


resource "kubernetes_role_binding" "appdynamics-infraviz" {
  metadata {
    name      = "appdynamics-infraviz"
    namespace = var.namespace
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = "appdynamics-infraviz"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "appdynamics-infraviz"
    namespace = var.namespace
  }
}


############################################################
# DEPLOY CRDS AND CUSTOM ELEMENTS
############################################################
resource "helm_release" "appd-crd" {
  name       = "appd-crd"

  chart      = "${path.module}/helm/"
  
  namespace  = var.namespace
  
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
