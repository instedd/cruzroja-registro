import { Listings } from "./listings";
import { BranchSelector } from "./branch_selector";
import { RegistrationDateSelector } from "./registration_date_selector";

export var Users = {
  init: function() {
    $("#page-users").each(() => {
      Listings.init({
        selector: "#page-users.listing",
        endpoint: "/usuarios/",
        downloadEndpoint: "/usuarios/descargar",
        pagination: true,
        sorting: true,
        filters: [
          Listings.onEventFilter("role", "#role", "change"),
          Listings.onEventFilter("status", "#status", "change"),
          Listings.onEventFilter("branch", "#branch", "change"),
          Listings.onEventFilter("name", "#user-name", "input")
        ],
        onItemClick: (e) => {
          document.location.href = $(e.target).closest("tr").data("href")
        }
      })

      BranchSelector.init(window.branches)
    })

    $("#page-profile").each(() => {
      RegistrationDateSelector.init(".registration_date_selector")
    })

    $("#page-profile-show").each(() => {
      let eligibilityWarning = $("#eligible-branch-warning");

      BranchSelector.init(window.branches, {
        onSelect: function(branch) {
          let display = branch && !branch.eligible;
          let isVisible = eligibilityWarning.is(":visible");

          if (isVisible != display) {
            eligibilityWarning.fadeToggle('fast');
          }
        }
      })
    })
  }};
