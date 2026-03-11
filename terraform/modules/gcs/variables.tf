variable "bucket_name" {
    description = "Name of the GCS bucket"
    type        = string
}

variable "location" {
    description = "GCP location name"
    type        = string
}

variable "storage_class" {
    description = "GCS storage class"
    type        = string
    default     = "STANDARD"
}

variable "versioning" {
    description = "Enable versioning for the GCS bucket"
    type        = bool
    default     = true
}

variable "lifecycle_rules" {
  type = list(object({
    action = object({
      type          = string        # Delete, SetStorageClass, AbortIncompleteMultipartUpload
      storage_class = optional(string)  # only if SetStorageClass
    })
    condition = object({
      age                = optional(number)
    })
  }))
  default = []
}