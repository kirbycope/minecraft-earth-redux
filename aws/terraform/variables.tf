variable "aws_region" {
  description = "Region to deploy in. us-west-2 (Oregon) is closest to Washington state."
  type        = string
  default     = "us-west-2"
}

variable "project_name" {
  description = "Tag and name prefix for every resource."
  type        = string
  default     = "minecraft-earth-redux"
}

variable "instance_type" {
  description = "ARM64 (Graviton) instance. t4g.large (8 GB) is comfortable for ~4 players; t4g.medium (4 GB) is the budget option."
  type        = string
  default     = "t4g.large"
}

variable "ssh_key_name" {
  description = "Name of an existing EC2 key pair in the region, used for SSH."
  type        = string
}

variable "admin_cidr" {
  description = "CIDR allowed to SSH (and tunnel to the launcher admin UI). Your home IP as x.x.x.x/32."
  type        = string
}

variable "root_volume_gb" {
  description = "Root EBS volume size. 40 GB fits the OS, Solace, .NET, Java, a metro tile database and buildplates."
  type        = number
  default     = 40
}

variable "api_port" {
  description = "Solace API port the game talks to."
  type        = number
  default     = 8080
}

variable "idle_stop_minutes" {
  description = "Stop the instance after this many minutes with no game traffic on the API port. 0 disables auto-stop."
  type        = number
  default     = 20
}

variable "tiles_enabled" {
  description = "Import OpenStreetMap data and render the real-world map. Set false for a plain green map."
  type        = bool
  default     = true
}

variable "osm_extract_url" {
  description = "Geofabrik (or other) .osm.pbf extract containing your play area."
  type        = string
  default     = "https://download.geofabrik.de/north-america/us/washington-latest.osm.pbf"
}

variable "osm_bbox" {
  description = "minlon,minlat,maxlon,maxlat to import. Keep it to a metro; a whole state in slim mode is many GB."
  type        = string
  default     = "-122.9,47.2,-122.0,47.9"
}

variable "solace_commit" {
  description = "Earth-Restored/Solace commit to build. Pinned to the one this repo was verified against."
  type        = string
  default     = "5b185f6ebe3c522b4541be19deb4106839dc29f5"
}

variable "resourcepack_url" {
  description = "The game resource pack (vanilla.zip containing genoa.mcpack). Community archive of the original."
  type        = string
  default     = "https://github.com/andiricum2/MC-Earth-Resourcepack/releases/download/v1/vanilla.zip"
}

variable "expose_admin_ui" {
  description = "Open the launcher admin UI (port 5000) directly to admin_cidr, so it can be used at http://<public_ip>:5000 without an SSH tunnel. Plain HTTP: the login goes over the internet unencrypted, though only your IP can reach it."
  type        = bool
  default     = false
}
