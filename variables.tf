############################################################
# INPUT VARIABLES
############################################################
variable "namespace" {
  type        = string
  default     = "appdynamics"
  description = "Namespace used for deploying the AppDynamics objects. This namespace has to exist and is not provisioned by this module"
}

variable "controller_url" {
  type        = string
  default     = ""
  description = "URL of the AppDynamics controller."
}

variable "proxy_url" {
  type        = string
  default     = ""
  description = "URL of the proxy used for establishing connections to the AppDynamics controller. You can ignore this parameter if no proxy is used."
}

variable "username" {
  type        = string
  default     = ""
  description = "Username used for logging into the AppDynamics account. This will either be your username, or the username of the account created for this integration."
}

variable "password" {
  type        = string
  default     = ""
  description = "Password used for logging into the AppDynamics account. This will either be your password, or the password of the account created for this integration."
}

variable "account_name" {
  type        = string
  description = "The name of the AppDynamics account. This value can be found in Settings > License > Account > Name."
}

variable "global_account" {
  type        = string
  description = "The name of the global AppDynamics account. This value can be found in Settings > License > Account > Global Account Name."
}

variable "controller_key" {
  type        = string
  description = "The key used for authorizing with the AppDynamics controller. This value can be found in Settings > License > Account > Access Key."
}

variable "registry" {
  type        = string
  default     = "mimaurer"
  description = "The registry from which the NodeAgent will be pulled."
}

variable "ns_to_monitor" {
  type        = list
  default     = ["default", "kube-system", "appdynamics"]
  description = "The list of namespaces to monitor."
}

variable "ns_to_instrument" {
  type        = list
  default     = []
  description = "The list of namespaces to instrument."
}
