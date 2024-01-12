data "azuread_client_config" "current" {}

resource "azuread_application" "app" {
  #for_each = local.aad_user
  display_name = local.aad_user
  owners       = [data.azuread_client_config.current.object_id]

  web {
    redirect_uris = [local.redirect_uris]

    implicit_grant {
      access_token_issuance_enabled = false
      id_token_issuance_enabled     = true
    }
  }

  public_client {
    redirect_uris = [
      "https://login.microsoftonline.com/common/oauth2/nativeclient",
    ]
  }

  lifecycle {
    ignore_changes = [display_name]
  }

}

resource "azuread_service_principal" "app" {
  client_id = azuread_application.app.client_id
  app_role_assignment_required = true
  owners                       = [data.azuread_client_config.current.object_id]

  feature_tags {
    enterprise = true
    gallery    = true
  }
}





resource "time_rotating" "time" {
  rotation_days = 365
}

resource "azuread_application_password" "password_confidential" {
  application_object_id = azuread_application.app.object_id
  
  rotate_when_changed = {
    rotation = time_rotating.time.id
  }
}

output "AppPassword" {
  value = azuread_application_password.password_confidential.value
  sensitive = true
}




data "azuread_application_published_app_ids" "well_known" {}

data "azuread_service_principal" "msgraph" {
  client_id = data.azuread_application_published_app_ids.well_known.result["MicrosoftGraph"]
}

resource "azuread_application_registration" "example" {
  display_name = "example"
}

resource "azuread_application_api_access" "example_msgraph" {
  application_id = azuread_application.app.id
  api_client_id  = data.azuread_application_published_app_ids.well_known.result["MicrosoftGraph"]

  scope_ids = [
    data.azuread_service_principal.msgraph.oauth2_permission_scope_ids["Policy.ReadWrite.ConditionalAccess"],
    data.azuread_service_principal.msgraph.oauth2_permission_scope_ids["Policy.Read.All"],
    data.azuread_service_principal.msgraph.oauth2_permission_scope_ids["Directory.Read.All"],
    data.azuread_service_principal.msgraph.oauth2_permission_scope_ids["Agreement.Read.All"],
    data.azuread_service_principal.msgraph.oauth2_permission_scope_ids["Application.Read.All"],
  ]
}






resource "null_resource" "app_consent" {
  provisioner "local-exec" {

    interpreter = ["pwsh", "-Command"]
    command     = <<EOF
      
      start-sleep -Seconds 120
      az ad app permission admin-consent --id ${azuread_application.app.client_id}
EOF
  }
  triggers   = { ID = azuread_application.app.client_id }
  depends_on = [azuread_application.app]
}