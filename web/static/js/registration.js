import { RegistrationDateSelector } from "./registration_date_selector";

export var Registration = {
  init: function() {
    $("#register").each(() => {
      RegistrationDateSelector.init(".registration_date_selector")
    })
  }};
